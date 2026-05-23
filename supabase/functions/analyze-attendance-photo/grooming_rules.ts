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

// ---------------------------------------------------------------------------
// Cloud Vision API response types (subset we actually use)
// ---------------------------------------------------------------------------

export interface VisionLabel {
  description: string;
  score: number;        // 0.0–1.0 confidence
  topicality?: number;
}

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
  "apron", "uniform", "shirt", "polo shirt", "polo", "vest",
  "chef", "restaurant", "workwear", "work wear",
];

const WRONG_ATTIRE_LABELS = [
  "tank top", "sleeveless", "singlet", "swimwear", "bikini",
  "swimsuit", "underwear", "lingerie",
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

export function matchAnyLabel(labels: VisionLabel[], needles: string[]): boolean {
  return labels.some(
    (l) =>
      l.score >= MIN_LABEL_SCORE &&
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
  if (matchAnyLabel(labels, UNIFORM_LABELS)) return "ok";
  if (matchAnyLabel(labels, WRONG_ATTIRE_LABELS)) return "wrong_attire";
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
// Main export — stub implementation (will be filled in A5–A7)
// ---------------------------------------------------------------------------

export function parseGroomingAnalysis(vision: VisionResponse): GroomingResult {
  // TODO: implement in A5–A7
  return {
    grooming_score: 5,
    face_clean_shave: "unclear",
    head_covering: "none",
    uniform_compliant: "unclear",
    hair_neat: "ok",
    reasoning: "belum diimplementasi",
    model_name: "cloud-vision-rubric-v1",
  };
}
