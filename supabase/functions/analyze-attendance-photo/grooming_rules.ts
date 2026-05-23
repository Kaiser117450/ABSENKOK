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
// Main export — stub implementation (will be filled in A5–A7)
// ---------------------------------------------------------------------------

export function parseGroomingAnalysis(_vision: VisionResponse): GroomingResult {
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
