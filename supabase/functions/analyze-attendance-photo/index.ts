import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type AnalyzeRequest = {
  attendance_log_id?: string;
  photo_path?: string;
  photo_url?: string;
};

type ServiceAccountKey = {
  client_email: string;
  private_key: string;
  token_uri?: string;
};

type GoogleVisionAuth =
  | { kind: "api_key"; apiKey: string }
  | { kind: "bearer"; accessToken: string };

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const body = await req.json() as AnalyzeRequest;
    const attendanceLogId = body.attendance_log_id?.trim();
    const photoPath = body.photo_path?.trim();
    const photoUrl = body.photo_url?.trim();

    if (!attendanceLogId || !photoPath || !photoUrl) {
      return json(
        { error: "attendance_log_id, photo_path, and photo_url are required" },
        400,
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Phase 66: photos live on Cloudflare R2. The public_url returned from
    // sign-r2-upload is readable without auth, so a plain fetch is enough.
    const photoResponse = await fetch(photoUrl);
    if (!photoResponse.ok) {
      return json(
        { error: `Failed to download photo: HTTP ${photoResponse.status}` },
        500,
      );
    }

    const imageBytes = new Uint8Array(await photoResponse.arrayBuffer());
    const googleAuth = await getGoogleVisionAuth();
    const visionResponse = await callVisionApi(imageBytes, googleAuth);
    const analysis = parseGroomingAnalysis(visionResponse);

    const { error: upsertError } = await supabaseAdmin
      .from("attendance_photo_analysis")
      .upsert(
        {
          attendance_log_id: attendanceLogId,
          photo_url: photoUrl,
          face_detected: analysis.faceDetected,
          face_confidence: analysis.faceConfidence,
          face_count: analysis.faceCount,
          photo_quality: analysis.photoQuality,
          grooming_labels: analysis.groomingLabels,
          grooming_score: analysis.groomingScore,
          safe_search_passed: analysis.safeSearchPassed,
          raw_vision_response: visionResponse,
          analyzed_at: new Date().toISOString(),
        },
        { onConflict: "attendance_log_id" },
      );

    if (upsertError) {
      return json(
        { error: `Failed to store analysis: ${upsertError.message}` },
        500,
      );
    }

    return json({
      success: true,
      attendance_log_id: attendanceLogId,
      grooming_score: analysis.groomingScore,
      face_detected: analysis.faceDetected,
      safe_search_passed: analysis.safeSearchPassed,
    });
  } catch (error) {
    return json({ error: `Server error: ${errorMessage(error)}` }, 500);
  }
});

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getGoogleVisionAuth(): Promise<GoogleVisionAuth> {
  const rawKey = Deno.env.get("GOOGLE_CLOUD_VISION_KEY");
  if (!rawKey) {
    throw new Error("GOOGLE_CLOUD_VISION_KEY secret is missing");
  }

  const trimmedKey = rawKey.trim();
  if (!trimmedKey.startsWith("{")) {
    return { kind: "api_key", apiKey: trimmedKey };
  }

  const serviceAccount = JSON.parse(trimmedKey) as ServiceAccountKey;
  const now = Math.floor(Date.now() / 1000);
  const tokenUri = serviceAccount.token_uri ??
    "https://oauth2.googleapis.com/token";

  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/cloud-vision",
    aud: tokenUri,
    exp: now + 3600,
    iat: now,
  };

  const signingInput = `${base64UrlJson(header)}.${base64UrlJson(claims)}`;
  const signature = await signJwt(signingInput, serviceAccount.private_key);
  const assertion = `${signingInput}.${signature}`;

  const tokenResponse = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!tokenResponse.ok) {
    throw new Error(
      `Google token request failed: ${await tokenResponse.text()}`,
    );
  }

  const tokenJson = await tokenResponse.json();
  if (!tokenJson.access_token) {
    throw new Error("Google token response missing access_token");
  }

  return { kind: "bearer", accessToken: tokenJson.access_token };
}

async function callVisionApi(
  imageBytes: Uint8Array,
  auth: GoogleVisionAuth,
): Promise<Record<string, unknown>> {
  const url = auth.kind === "api_key"
    ? `https://vision.googleapis.com/v1/images:annotate?key=${
      encodeURIComponent(auth.apiKey)
    }`
    : "https://vision.googleapis.com/v1/images:annotate";
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (auth.kind === "bearer") {
    headers.Authorization = `Bearer ${auth.accessToken}`;
  }

  const response = await fetch(
    url,
    {
      method: "POST",
      headers,
      body: JSON.stringify({
        requests: [
          {
            image: { content: base64(imageBytes) },
            features: [
              { type: "LABEL_DETECTION", maxResults: 15 },
              { type: "FACE_DETECTION", maxResults: 5 },
              { type: "SAFE_SEARCH_DETECTION", maxResults: 1 },
            ],
          },
        ],
      }),
    },
  );

  if (!response.ok) {
    throw new Error(`Vision API failed: ${await response.text()}`);
  }

  return await response.json() as Record<string, unknown>;
}

function parseGroomingAnalysis(raw: Record<string, unknown>) {
  const responses = Array.isArray(raw.responses) ? raw.responses : [];
  const first = (responses[0] ?? {}) as Record<string, unknown>;
  const labels = Array.isArray(first.labelAnnotations)
    ? first.labelAnnotations as Array<Record<string, unknown>>
    : [];
  const faces = Array.isArray(first.faceAnnotations)
    ? first.faceAnnotations as Array<Record<string, unknown>>
    : [];
  const safeSearch = (first.safeSearchAnnotation ?? {}) as Record<
    string,
    string
  >;

  const labelItems = labels.map((label) => ({
    description: String(label.description ?? ""),
    score: Number(label.score ?? 0),
  })).filter((label) => label.description.length > 0);
  const lowerLabels = labelItems.map((label) =>
    label.description.toLowerCase()
  );
  const faceConfidence = faces.length > 0
    ? Number(faces[0].detectionConfidence ?? 0)
    : 0;
  const faceDetected = faces.length > 0 && faceConfidence >= 0.8;
  const uniformDetected = lowerLabels.some((label) =>
    label.includes("uniform") ||
    label.includes("shirt") ||
    label.includes("clothing") ||
    label.includes("apron")
  );
  const cleanDetected = lowerLabels.some((label) =>
    label.includes("clean") ||
    label.includes("neat") ||
    label.includes("professional") ||
    label.includes("person")
  );
  const photoQuality = inferPhotoQuality(lowerLabels);
  const safeSearchPassed = ["adult", "violence", "racy"].every((key) =>
    !["LIKELY", "VERY_LIKELY"].includes(String(safeSearch[key] ?? "UNKNOWN"))
  );

  let score = 0;
  if (faceDetected) score += 3;
  if (photoQuality === "clear") score += 2;
  if (uniformDetected) score += 2;
  if (cleanDetected) score += 2;
  if (safeSearchPassed) score += 1;

  return {
    faceDetected,
    faceConfidence: Number(faceConfidence.toFixed(2)),
    faceCount: faces.length,
    photoQuality,
    groomingLabels: labelItems,
    groomingScore: Number(Math.min(score, 10).toFixed(1)),
    safeSearchPassed,
  };
}

function inferPhotoQuality(
  labels: string[],
): "clear" | "blurry" | "dark" | "overexposed" {
  if (labels.some((label) => label.includes("blur"))) return "blurry";
  if (
    labels.some((label) => label.includes("dark") || label.includes("night"))
  ) {
    return "dark";
  }
  if (
    labels.some((label) =>
      label.includes("overexposed") || label.includes("glare")
    )
  ) {
    return "overexposed";
  }
  return "clear";
}

async function signJwt(input: string, privateKeyPem: string): Promise<string> {
  const binaryKey = pemToArrayBuffer(privateKeyPem);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(input),
  );
  return base64Url(new Uint8Array(signature));
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const normalized = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = atob(normalized);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function base64UrlJson(value: unknown): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}

function base64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

function base64Url(bytes: Uint8Array): string {
  return base64(bytes)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
