// grooming_rules.ts
// Pure grooming analysis logic for Cloud Vision API responses.
// No Deno/HTTP/Supabase dependencies — just types and functions.

// ---------------------------------------------------------------------------
// Types matching the columns in attendance_photo_analysis (phase 67)
// ---------------------------------------------------------------------------

export type FaceCleanShave = "ok" | "stubble" | "mustache" | "beard" | "unclear";
export type HeadCovering = "none" | "hijab" | "cap" | "other";
export type UniformCompliant = "ok" | "no_uniform" | "wrong_attire" | "unclear";
export type HairNeat = "ok" | "messy" | "not_visible";

export interface GroomingResult {
  grooming_score: number;          // 0–10
  face_clean_shave: FaceCleanShave;
  head_covering: HeadCovering;
  uniform_compliant: UniformCompliant;
  hair_neat: HairNeat;
  reasoning: string;               // Indonesian, ≤200 chars
  model_name: string;              // e.g. "cloud-vision-rubric-v1"
}

export interface GroomingAnalysis {
  faceDetected: boolean;
  faceConfidence: number;
  faceCount: number;
  photoQuality: PhotoQuality;
  faceCleanShave: FaceCleanShave;
  uniformCompliant: UniformCompliant;
  hairNeat: HairNeat;
  headCovering: HeadCovering;
  groomingLabels: VisionLabel[];
  groomingScore: number;
  reasoning: string;
  safeSearchPassed: boolean;
  modelName: string;
}

// ---------------------------------------------------------------------------
// Cloud Vision API response types (subset we actually use)
// ---------------------------------------------------------------------------

export interface VisionLabel {
  description: string;
  score: number;        // 0.0–1.0 confidence
  topicality?: number;
}

export type Label = VisionLabel;

export interface VisionFaceAnnotation {
  rollAngle?: number;
  panAngle?: number;
  tiltAngle?: number;
  detectionConfidence?: number;
  blurredLikelihood?: "UNKNOWN" | "VERY_UNLIKELY" | "UNLIKELY" | "POSSIBLE" | "LIKELY" | "VERY_LIKELY";
  underExposedLikelihood?: "UNKNOWN" | "VERY_UNLIKELY" | "UNLIKELY" | "POSSIBLE" | "LIKELY" | "VERY_LIKELY";
}

export interface VisionSafeSearch {
  adult?: string;
  violence?: string;
}

export interface VisionResponse {
  labelAnnotations?: VisionLabel[];
  faceAnnotations?: VisionFaceAnnotation[];
  safeSearchAnnotation?: VisionSafeSearch;
  error?: { code: number; message: string };
}

// ---------------------------------------------------------------------------
// Label matching constants (Cloud Vision descriptions, lowercase substring)
// ---------------------------------------------------------------------------

const MIN_LABEL_SCORE = 0.65;
// Slightly lenient threshold for uniform detection because Cloud Vision
// often returns clothing labels in the 0.55-0.70 range.
const MIN_UNIFORM_LABEL_SCORE = 0.55;
export const MIN_FACE_CONFIDENCE = 0.5;

const HIJAB_LABELS = ["hijab", "headscarf", "veil", "niqab", "khimar"];

const CAP_LABELS = [
  "cap", "hat", "baseball cap", "chef hat", "chef's hat", "beanie", "bandana",
];

const OTHER_HEAD_COVERING_LABELS = [
  "turban", "head covering", "head wrap", "headcloth",
];

const FACIAL_HAIR_LABELS = {
  beard: ["beard", "goatee"],
  mustache: ["moustache", "mustache"],
  stubble: ["stubble", "sideburns", "facial hair"],
};

const UNIFORM_LABELS = [
  // Restaurant/work uniform pieces
  "apron", "uniform", "workwear", "work wear", "work clothing",
  // Shirt variants (Cloud Vision commonly returns these for crew tops)
  "shirt", "t-shirt", "tshirt", "t shirt",
  "polo shirt", "polo", "polo neck",
  "dress shirt", "button-up", "button up", "buttoned",
  "blouse", "tunic", "top",
  // Detail labels (high-confidence indicators that someone is wearing a top)
  "collar", "sleeve", "neckline", "crew neck", "v-neck",
  // Categories Cloud Vision uses for tops
  "active shirt", "sportswear", "athletic wear", "jersey",
  "outerwear", "knitwear",
  // Restaurant-specific
  "vest", "waistcoat", "chef", "restaurant",
];

const WRONG_ATTIRE_LABELS = [
  "tank top", "sleeveless", "singlet", "swimwear", "bikini",
  "swimsuit", "underwear", "lingerie", "bare chest", "shirtless",
];

const MESSY_HAIR_LABELS = [
  "messy hair", "disheveled", "unkempt", "tousled",
];

export type PhotoQuality = "clear" | "blurry" | "dark" | "overexposed";

const POOR_QUALITY_LABELS = {
  blurry: ["blur", "blurry", "out of focus", "motion blur"],
  dark: ["darkness", "dark", "underexposed", "low light"],
  overexposed: ["overexposed", "overexposure", "glare", "blown out"],
};

// ---------------------------------------------------------------------------
// Core helpers
// ---------------------------------------------------------------------------

export function matchAnyLabel(
  labels: VisionLabel[],
  needles: string[],
  minScore: number = MIN_LABEL_SCORE,
): boolean {
  return labels.some(
    (l) =>
      l.score >= minScore &&
      needles.some((n) => l.description.toLowerCase().includes(n)),
  );
}

export function extractFaceCleanShave(
  labels: VisionLabel[],
  faceDetected: boolean,
): FaceCleanShave {
  if (!faceDetected) return "unclear";
  if (matchAnyLabel(labels, FACIAL_HAIR_LABELS.beard)) return "beard";
  if (matchAnyLabel(labels, FACIAL_HAIR_LABELS.mustache)) return "mustache";
  if (matchAnyLabel(labels, FACIAL_HAIR_LABELS.stubble)) return "stubble";
  return "ok";
}

export function extractHeadCovering(labels: VisionLabel[]): HeadCovering {
  if (matchAnyLabel(labels, HIJAB_LABELS)) return "hijab";
  if (matchAnyLabel(labels, CAP_LABELS)) return "cap";
  if (matchAnyLabel(labels, OTHER_HEAD_COVERING_LABELS)) return "other";
  return "none";
}

export function extractUniformCompliant(
  labels: VisionLabel[],
  faceDetected: boolean,
): UniformCompliant {
  // Wrong attire is checked first at the strict threshold so a strong
  // "tank top" label isn't masked by a softer "shirt" hit.
  if (matchAnyLabel(labels, WRONG_ATTIRE_LABELS)) return "wrong_attire";
  if (matchAnyLabel(labels, UNIFORM_LABELS, MIN_UNIFORM_LABEL_SCORE)) {
    return "ok";
  }
  if (faceDetected) return "no_uniform";
  return "unclear";
}

export function extractHairNeat(
  labels: VisionLabel[],
  headCovering: HeadCovering,
): HairNeat {
  if (headCovering !== "none") return "not_visible";
  if (matchAnyLabel(labels, MESSY_HAIR_LABELS)) return "messy";
  return "ok";
}

export function extractPhotoQuality(labels: VisionLabel[]): PhotoQuality {
  if (matchAnyLabel(labels, POOR_QUALITY_LABELS.blurry)) return "blurry";
  if (matchAnyLabel(labels, POOR_QUALITY_LABELS.dark)) return "dark";
  if (matchAnyLabel(labels, POOR_QUALITY_LABELS.overexposed)) return "overexposed";
  return "clear";
}

// ---------------------------------------------------------------------------
// Main export — real implementation (A7)
// ---------------------------------------------------------------------------

export function parseGroomingAnalysis(
  raw: Record<string, unknown>,
): GroomingAnalysis {
  const responses = Array.isArray(raw.responses) ? raw.responses : [];
  const first = (responses[0] ?? {}) as Record<string, unknown>;

  const rawLabels = Array.isArray(first.labelAnnotations)
    ? first.labelAnnotations as Array<Record<string, unknown>>
    : [];
  const faces = Array.isArray(first.faceAnnotations)
    ? first.faceAnnotations as Array<Record<string, unknown>>
    : [];
  const safe = (first.safeSearchAnnotation ?? {}) as Record<string, string>;

  const labels: VisionLabel[] = rawLabels
    .map((l) => ({
      description: String(l.description ?? ""),
      score: Number(l.score ?? 0),
    }))
    .filter((l) => l.description.length > 0);

  const faceConfidence = faces.length > 0
    ? Number(faces[0].detectionConfidence ?? 0)
    : 0;
  const faceDetected = faces.length > 0 && faceConfidence >= MIN_FACE_CONFIDENCE;

  const headCovering = extractHeadCovering(labels);
  const faceCleanShave = extractFaceCleanShave(labels, faceDetected);
  const uniformCompliant = extractUniformCompliant(labels, faceDetected);
  const hairNeat = extractHairNeat(labels, headCovering);
  const photoQuality = extractPhotoQuality(labels);

  const groomingScore = computeScore({
    faceCleanShave,
    uniformCompliant,
    hairNeat,
    photoQuality,
  });
  const reasoning = buildReasoning({
    faceCleanShave,
    uniformCompliant,
    hairNeat,
    headCovering,
    photoQuality,
    faceDetected,
  });

  const safeSearchPassed = (["adult", "violence", "racy"] as const).every(
    (k) => !["LIKELY", "VERY_LIKELY"].includes(String(safe[k] ?? "UNKNOWN")),
  );

  return {
    faceDetected,
    faceConfidence: Number(faceConfidence.toFixed(2)),
    faceCount: faces.length,
    photoQuality,
    faceCleanShave,
    uniformCompliant,
    hairNeat,
    headCovering,
    groomingLabels: labels,
    groomingScore: Number(groomingScore.toFixed(1)),
    reasoning,
    safeSearchPassed,
    modelName: "cloud-vision-rubric-v1",
  };
}

// ---------------------------------------------------------------------------
// Scoring and reasoning
// ---------------------------------------------------------------------------

interface ScoreInput {
  faceCleanShave: FaceCleanShave;
  uniformCompliant: UniformCompliant;
  hairNeat: HairNeat;
  photoQuality: PhotoQuality;
}

export function computeScore(input: ScoreInput): number {
  let score = 0;

  if (input.faceCleanShave === "ok") score += 3;
  else if (input.faceCleanShave === "unclear") score += 1;
  // 'stubble' | 'mustache' | 'beard' → +0

  if (input.uniformCompliant === "ok") score += 3;
  else if (input.uniformCompliant === "unclear") score += 1;

  if (input.hairNeat === "ok" || input.hairNeat === "not_visible") score += 3;
  // 'messy' → +0

  if (input.photoQuality === "clear") score += 1;

  return Math.min(score, 10);
}

interface ReasoningInput extends ScoreInput {
  headCovering: HeadCovering;
  faceDetected: boolean;
}

export function buildReasoning(input: ReasoningInput): string {
  const parts: string[] = [];

  if (!input.faceDetected) {
    parts.push("Wajah tidak terdeteksi jelas");
  } else if (input.faceCleanShave === "beard") {
    parts.push("Terdeteksi jenggot");
  } else if (input.faceCleanShave === "mustache") {
    parts.push("Terdeteksi kumis");
  } else if (input.faceCleanShave === "stubble") {
    parts.push("Terdeteksi bulu wajah");
  } else if (input.faceCleanShave === "ok") {
    parts.push("Wajah bersih");
  }

  if (input.uniformCompliant === "ok") parts.push("Seragam OK");
  else if (input.uniformCompliant === "no_uniform") parts.push("Tidak pakai seragam");
  else if (input.uniformCompliant === "wrong_attire") parts.push("Pakaian tidak pantas");

  if (input.headCovering === "hijab") parts.push("Berhijab — rambut OK");
  else if (input.headCovering === "cap") parts.push("Pakai topi — rambut OK");
  else if (input.headCovering === "other") parts.push("Penutup kepala — rambut OK");
  else if (input.hairNeat === "messy") parts.push("Rambut acak");
  else if (input.hairNeat === "ok" && input.faceDetected) parts.push("Rambut OK");

  if (input.photoQuality === "blurry") parts.push("Foto buram");
  else if (input.photoQuality === "dark") parts.push("Foto gelap");
  else if (input.photoQuality === "overexposed") parts.push("Foto terlalu terang");
  else if (input.photoQuality === "clear") parts.push("Foto jelas");

  const text = parts.join(". ") + ".";
  return text.length > 200 ? text.slice(0, 197) + "..." : text;
}
