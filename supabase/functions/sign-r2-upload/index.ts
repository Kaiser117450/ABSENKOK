// Phase 66: Sign Cloudflare R2 PUT URL for attendance photo upload.
//
// Replaces the Phase 64/65 Supabase Storage upload path. Kiosk clients call
// this function with attendance metadata and receive a short-lived presigned
// PUT URL that they upload the JPEG bytes to directly, plus the public URL
// that should be attached to `attendance_logs.selfie_url`.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type SignRequest = {
  outlet_id?: string;
  employee_id?: string;
  log_date?: string;
  log_id?: string;
};

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const EXPIRES_SECONDS = 300;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const accountId = mustEnv("R2_ACCOUNT_ID");
    const accessKeyId = mustEnv("R2_ACCESS_KEY_ID");
    const secretAccessKey = mustEnv("R2_SECRET_ACCESS_KEY");
    const bucket = (Deno.env.get("R2_BUCKET") ?? "attendance-photos").trim();
    const publicBase = mustEnv("R2_PUBLIC_BASE_URL").replace(/\/+$/, "");

    const body = (await req.json()) as SignRequest;
    const outletId = sanitizeSegment(body.outlet_id);
    const employeeId = sanitizeSegment(body.employee_id);
    const logDate = (body.log_date ?? "").trim();
    const logId = sanitizeSegment(body.log_id);

    if (!outletId || !employeeId || !logId) {
      return json(
        { error: "outlet_id, employee_id, and log_id are required" },
        400,
      );
    }
    if (!DATE_RE.test(logDate)) {
      return json({ error: "log_date must be YYYY-MM-DD" }, 400);
    }

    const objectKey = `${outletId}/${employeeId}/${logDate}/${logId}.jpg`;
    const uploadUrl = await signR2Put({
      accountId,
      accessKeyId,
      secretAccessKey,
      bucket,
      objectKey,
      expiresInSeconds: EXPIRES_SECONDS,
    });
    const publicUrl = `${publicBase}/${encodeR2Key(objectKey)}`;
    const expiresAt = new Date(Date.now() + EXPIRES_SECONDS * 1000)
      .toISOString();

    return json({
      upload_url: uploadUrl,
      public_url: publicUrl,
      storage_path: objectKey,
      bucket,
      expires_at: expiresAt,
      expires_in: EXPIRES_SECONDS,
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

function mustEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing ${name} secret`);
  return value;
}

function sanitizeSegment(value: string | undefined): string {
  const trimmed = (value ?? "").trim();
  if (!trimmed) return "";
  return trimmed.replace(/[^A-Za-z0-9._-]/g, "_");
}

function encodeR2Key(key: string): string {
  return key.split("/").map(encodeRfc3986).join("/");
}

function encodeRfc3986(value: string): string {
  return encodeURIComponent(value).replace(
    /[!*'()]/g,
    (c) => "%" + c.charCodeAt(0).toString(16).toUpperCase(),
  );
}

async function signR2Put(opts: {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
  objectKey: string;
  expiresInSeconds: number;
}): Promise<string> {
  const host = `${opts.accountId}.r2.cloudflarestorage.com`;
  const region = "auto";
  const service = "s3";
  const method = "PUT";
  const amzDate = formatAmzDate(new Date());
  const dateStamp = amzDate.slice(0, 8);
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const signedHeaders = "host";

  const queryPairs: Array<[string, string]> = [
    ["X-Amz-Algorithm", "AWS4-HMAC-SHA256"],
    ["X-Amz-Credential", `${opts.accessKeyId}/${credentialScope}`],
    ["X-Amz-Date", amzDate],
    ["X-Amz-Expires", String(opts.expiresInSeconds)],
    ["X-Amz-SignedHeaders", signedHeaders],
  ];

  const canonicalUri = `/${encodeRfc3986(opts.bucket)}/${
    encodeR2Key(opts.objectKey)
  }`;
  const canonicalQuery = queryPairs
    .map(([k, v]) => `${encodeRfc3986(k)}=${encodeRfc3986(v)}`)
    .sort()
    .join("&");
  const canonicalHeaders = `host:${host}\n`;
  const payloadHash = "UNSIGNED-PAYLOAD";

  const canonicalRequest = [
    method,
    canonicalUri,
    canonicalQuery,
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join("\n");

  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    credentialScope,
    await sha256Hex(canonicalRequest),
  ].join("\n");

  const signingKey = await deriveSigningKey(
    opts.secretAccessKey,
    dateStamp,
    region,
    service,
  );
  const signature = await hmacHex(signingKey, stringToSign);

  const finalQuery = [
    ...queryPairs.map(
      ([k, v]) => `${encodeRfc3986(k)}=${encodeRfc3986(v)}`,
    ),
    `X-Amz-Signature=${signature}`,
  ].join("&");

  return `https://${host}${canonicalUri}?${finalQuery}`;
}

async function sha256Hex(data: string): Promise<string> {
  const buffer = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(data),
  );
  return toHex(new Uint8Array(buffer));
}

async function hmac(
  key: ArrayBuffer | Uint8Array,
  data: string,
): Promise<ArrayBuffer> {
  const source = key instanceof Uint8Array ? key : new Uint8Array(key);
  const rawKey = new ArrayBuffer(source.byteLength);
  new Uint8Array(rawKey).set(source);
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    rawKey,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    new TextEncoder().encode(data),
  );
}

async function hmacHex(key: ArrayBuffer, data: string): Promise<string> {
  return toHex(new Uint8Array(await hmac(key, data)));
}

async function deriveSigningKey(
  secret: string,
  dateStamp: string,
  region: string,
  service: string,
): Promise<ArrayBuffer> {
  const kSecret = new TextEncoder().encode(`AWS4${secret}`);
  const kDate = await hmac(kSecret, dateStamp);
  const kRegion = await hmac(kDate, region);
  const kService = await hmac(kRegion, service);
  return await hmac(kService, "aws4_request");
}

function toHex(bytes: Uint8Array): string {
  let out = "";
  for (const byte of bytes) {
    out += byte.toString(16).padStart(2, "0");
  }
  return out;
}

function formatAmzDate(date: Date): string {
  return date
    .toISOString()
    .replace(/[-:]/g, "")
    .replace(/\.\d{3}Z$/, "Z");
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
