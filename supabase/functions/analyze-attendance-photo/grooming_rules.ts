// grooming_rules.ts
// Pure grooming analysis logic for Cloud Vision API responses.
// No Deno/HTTP/Supabase dependencies — just types and functions.
//
// Phase 72: the rule set (label vocab, thresholds, weights, custom flagged
// labels) is now data-driven via GroomingConfig. The edge function loads the
// active config row from `grooming_rules_config`; if absent/unreadable it falls
// back to DEFAULT_GROOMING_CONFIG (== the historical hardcoded behaviour), so
// every function keeps a no-arg/legacy-arg call shape for the test-suite.

// ---------------------------------------------------------------------------
// Types matching the columns in attendance_photo_analysis
// ---------------------------------------------------------------------------

export type FaceCleanShave = "ok" | "stubble" | "mustache" | "beard" | "unclear";
export type HeadCovering = "none" | "hijab" | "cap" | "other";
export type UniformCompliant = "ok" | "no_uniform" | "wrong_attire" | "unclear";
export type HairNeat = "ok" | "messy" | "not_visible";
export type HairLength = "ok" | "long" | "not_visible" | "unclear";
export type PhotoQuality = "clear" | "blurry" | "dark" | "overexposed";

export interface ScoreBreakdown {
  face: number;
  uniform: number;
  hair: number;
  photo: number;
  total: number;
  max: number;
}

export interface GroomingResult {
  grooming_score: number;          // 0–10
  face_clean_shave: FaceCleanShave;
  head_covering: HeadCovering;
  uniform_compliant: UniformCompliant;
  hair_neat: HairNeat;
  hair_length: HairLength;
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
  hairLength: HairLength;
  headCovering: HeadCovering;
  groomingLabels: VisionLabel[];
  groomingScore: number;
  scoreBreakdown: ScoreBreakdown;
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
// Config — the admin-editable rule set
// ---------------------------------------------------------------------------

export type FlaggedCriterion =
  | "face_clean_shave"
  | "uniform_compliant"
  | "hair_neat"
  | "hair_length"
  | "head_covering";

export interface FlaggedLabel {
  label: string;            // Cloud Vision description substring (lowercase)
  criterion: FlaggedCriterion;
  verdict: string;          // value to force on that criterion when matched
  message?: string;         // optional reasoning text fragment
  min_score?: number;       // optional per-rule threshold
}

export interface GroomingConfig {
  thresholds: {
    minLabelScore: number;
    minUniformLabelScore: number;
    minFaceConfidence: number;
  };
  weights: { face: number; uniform: number; hair: number; photo: number };
  labelSets: {
    hijab: string[];
    cap: string[];
    otherHeadCovering: string[];
    beard: string[];
    mustache: string[];
    stubble: string[];
    uniform: string[];
    wrongAttire: string[];
    messyHair: string[];
    longHair: string[];
    shortHairOk: string[];
    blurry: string[];
    dark: string[];
    overexposed: string[];
  };
  flaggedLabels: FlaggedLabel[];
}

export const DEFAULT_GROOMING_CONFIG: GroomingConfig = {
  thresholds: {
    minLabelScore: 0.65,
    // Lenient threshold for uniform — Cloud Vision often returns clothing
    // labels in the 0.55-0.70 range.
    minUniformLabelScore: 0.55,
    minFaceConfidence: 0.5,
  },
  weights: { face: 3, uniform: 3, hair: 3, photo: 1 },
  labelSets: {
    hijab: ["hijab", "headscarf", "veil", "niqab", "khimar", "shawl", "abaya"],
    cap: [
      "cap", "hat", "baseball cap", "cricket cap", "chef hat", "chef's hat",
      "beanie", "bandana", "headgear",
    ],
    otherHeadCovering: ["turban", "head covering", "head wrap", "headcloth"],
    beard: ["beard", "goatee"],
    mustache: ["moustache", "mustache"],
    stubble: ["stubble", "sideburns", "facial hair"],
    uniform: [
      "apron", "uniform", "workwear", "work wear", "work clothing",
      "shirt", "t-shirt", "tshirt", "t shirt",
      "polo shirt", "polo", "polo neck",
      "dress shirt", "button-up", "button up", "buttoned",
      "blouse", "tunic", "top",
      "collar", "sleeve", "neckline", "crew neck", "v-neck",
      "active shirt", "sportswear", "athletic wear", "jersey",
      "outerwear", "knitwear",
      "vest", "waistcoat", "chef", "restaurant",
    ],
    wrongAttire: [
      "tank top", "sleeveless", "singlet", "swimwear", "bikini",
      "swimsuit", "underwear", "lingerie", "bare chest", "shirtless",
    ],
    messyHair: ["messy hair", "disheveled", "unkempt", "tousled"],
    // Best-effort long-hair signals (admin-tunable). Kept conservative to
    // limit false positives; admin overrides handle mistakes.
    longHair: ["long hair", "ponytail", "bun", "pigtail", "dreadlocks", "hair bun"],
    // Negative signal — if present, hair is clearly short, never "long".
    shortHairOk: [
      "crew cut", "buzz cut", "short hair", "fade", "undercut",
      "high and tight", "caesar cut", "comb over",
    ],
    blurry: ["blur", "blurry", "out of focus", "motion blur"],
    dark: ["darkness", "dark", "underexposed", "low light"],
    overexposed: ["overexposed", "overexposure", "glare", "blown out"],
  },
  flaggedLabels: [],
};

export const MIN_FACE_CONFIDENCE = DEFAULT_GROOMING_CONFIG.thresholds.minFaceConfidence;

/**
 * Merge a raw (snake_case JSONB) config object from the DB with the defaults so
 * partial / out-of-date configs never break the analyzer. Unknown keys ignored.
 */
export function normalizeGroomingConfig(raw: unknown): GroomingConfig {
  const d = DEFAULT_GROOMING_CONFIG;
  if (!raw || typeof raw !== "object") return d;
  const o = raw as Record<string, any>;
  const t = (o.thresholds ?? {}) as Record<string, any>;
  const w = (o.weights ?? {}) as Record<string, any>;
  const ls = (o.label_sets ?? o.labelSets ?? {}) as Record<string, any>;

  const arr = (v: unknown, fallback: string[]): string[] =>
    Array.isArray(v)
      ? v.map((x) => String(x).toLowerCase().trim()).filter((x) => x.length > 0)
      : fallback;
  const num = (v: unknown, fallback: number): number =>
    typeof v === "number" && Number.isFinite(v) ? v : fallback;

  const flagged = Array.isArray(o.flagged_labels ?? o.flaggedLabels)
    ? (o.flagged_labels ?? o.flaggedLabels)
      .map((f: any) => ({
        label: String(f?.label ?? "").toLowerCase().trim(),
        criterion: String(f?.criterion ?? "") as FlaggedCriterion,
        verdict: String(f?.verdict ?? ""),
        message: f?.message ? String(f.message) : undefined,
        min_score: typeof f?.min_score === "number" ? f.min_score : undefined,
      }))
      .filter((f: FlaggedLabel) => f.label.length > 0 && f.criterion && f.verdict)
    : [];

  return {
    thresholds: {
      minLabelScore: num(t.min_label_score ?? t.minLabelScore, d.thresholds.minLabelScore),
      minUniformLabelScore: num(
        t.min_uniform_label_score ?? t.minUniformLabelScore,
        d.thresholds.minUniformLabelScore,
      ),
      minFaceConfidence: num(
        t.min_face_confidence ?? t.minFaceConfidence,
        d.thresholds.minFaceConfidence,
      ),
    },
    weights: {
      face: num(w.face, d.weights.face),
      uniform: num(w.uniform, d.weights.uniform),
      hair: num(w.hair, d.weights.hair),
      photo: num(w.photo, d.weights.photo),
    },
    labelSets: {
      hijab: arr(ls.hijab, d.labelSets.hijab),
      cap: arr(ls.cap, d.labelSets.cap),
      otherHeadCovering: arr(ls.other_head_covering ?? ls.otherHeadCovering, d.labelSets.otherHeadCovering),
      beard: arr(ls.beard, d.labelSets.beard),
      mustache: arr(ls.mustache, d.labelSets.mustache),
      stubble: arr(ls.stubble, d.labelSets.stubble),
      uniform: arr(ls.uniform, d.labelSets.uniform),
      wrongAttire: arr(ls.wrong_attire ?? ls.wrongAttire, d.labelSets.wrongAttire),
      messyHair: arr(ls.messy_hair ?? ls.messyHair, d.labelSets.messyHair),
      longHair: arr(ls.long_hair ?? ls.longHair, d.labelSets.longHair),
      shortHairOk: arr(ls.short_hair_ok ?? ls.shortHairOk, d.labelSets.shortHairOk),
      blurry: arr(ls.blurry, d.labelSets.blurry),
      dark: arr(ls.dark, d.labelSets.dark),
      overexposed: arr(ls.overexposed, d.labelSets.overexposed),
    },
    flaggedLabels: flagged,
  };
}

// ---------------------------------------------------------------------------
// Core helpers
// ---------------------------------------------------------------------------

export function matchAnyLabel(
  labels: VisionLabel[],
  needles: string[],
  minScore: number = DEFAULT_GROOMING_CONFIG.thresholds.minLabelScore,
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
  config: GroomingConfig = DEFAULT_GROOMING_CONFIG,
): FaceCleanShave {
  const min = config.thresholds.minLabelScore;
  if (!faceDetected) return "unclear";
  if (matchAnyLabel(labels, config.labelSets.beard, min)) return "beard";
  if (matchAnyLabel(labels, config.labelSets.mustache, min)) return "mustache";
  if (matchAnyLabel(labels, config.labelSets.stubble, min)) return "stubble";
  return "ok";
}

export function extractHeadCovering(
  labels: VisionLabel[],
  config: GroomingConfig = DEFAULT_GROOMING_CONFIG,
): HeadCovering {
  const min = config.thresholds.minLabelScore;
  if (matchAnyLabel(labels, config.labelSets.hijab, min)) return "hijab";
  if (matchAnyLabel(labels, config.labelSets.cap, min)) return "cap";
  if (matchAnyLabel(labels, config.labelSets.otherHeadCovering, min)) return "other";
  return "none";
}

export function extractUniformCompliant(
  labels: VisionLabel[],
  faceDetected: boolean,
  config: GroomingConfig = DEFAULT_GROOMING_CONFIG,
): UniformCompliant {
  // Wrong attire is checked first at the strict threshold so a strong
  // "tank top" label isn't masked by a softer "shirt" hit.
  if (matchAnyLabel(labels, config.labelSets.wrongAttire, config.thresholds.minLabelScore)) {
    return "wrong_attire";
  }
  if (matchAnyLabel(labels, config.labelSets.uniform, config.thresholds.minUniformLabelScore)) {
    return "ok";
  }
  if (faceDetected) return "no_uniform";
  return "unclear";
}

export function extractHairNeat(
  labels: VisionLabel[],
  headCovering: HeadCovering,
  config: GroomingConfig = DEFAULT_GROOMING_CONFIG,
): HairNeat {
  if (headCovering !== "none") return "not_visible";
  if (matchAnyLabel(labels, config.labelSets.messyHair, config.thresholds.minLabelScore)) {
    return "messy";
  }
  return "ok";
}

export function extractHairLength(
  labels: VisionLabel[],
  headCovering: HeadCovering,
  faceDetected: boolean,
  config: GroomingConfig = DEFAULT_GROOMING_CONFIG,
): HairLength {
  if (headCovering !== "none") return "not_visible";
  if (!faceDetected) return "unclear";
  const min = config.thresholds.minLabelScore;
  // A clear "short hair" signal vetoes any long-hair guess.
  if (matchAnyLabel(labels, config.labelSets.shortHairOk, min)) return "ok";
  if (matchAnyLabel(labels, config.labelSets.longHair, min)) return "long";
  return "ok";
}

export function extractPhotoQuality(
  labels: VisionLabel[],
  config: GroomingConfig = DEFAULT_GROOMING_CONFIG,
): PhotoQuality {
  const min = config.thresholds.minLabelScore;
  if (matchAnyLabel(labels, config.labelSets.blurry, min)) return "blurry";
  if (matchAnyLabel(labels, config.labelSets.dark, min)) return "dark";
  if (matchAnyLabel(labels, config.labelSets.overexposed, min)) return "overexposed";
  return "clear";
}

// ---------------------------------------------------------------------------
// Main export — real implementation
// ---------------------------------------------------------------------------

export function parseGroomingAnalysis(
  raw: Record<string, unknown>,
  config: GroomingConfig = DEFAULT_GROOMING_CONFIG,
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
  const faceDetected = faces.length > 0 &&
    faceConfidence >= config.thresholds.minFaceConfidence;

  let headCovering = extractHeadCovering(labels, config);
  let faceCleanShave = extractFaceCleanShave(labels, faceDetected, config);
  let uniformCompliant = extractUniformCompliant(labels, faceDetected, config);
  let hairNeat = extractHairNeat(labels, headCovering, config);
  let hairLength = extractHairLength(labels, headCovering, faceDetected, config);
  const photoQuality = extractPhotoQuality(labels, config);

  // Admin "flagged labels" overlay — custom rules that force a criterion when a
  // given Cloud Vision label is present (the improvement loop surface).
  const flaggedMessages: string[] = [];
  for (const f of config.flaggedLabels) {
    const threshold = f.min_score ?? config.thresholds.minLabelScore;
    if (!matchAnyLabel(labels, [f.label], threshold)) continue;
    switch (f.criterion) {
      case "face_clean_shave": faceCleanShave = f.verdict as FaceCleanShave; break;
      case "uniform_compliant": uniformCompliant = f.verdict as UniformCompliant; break;
      case "hair_neat": hairNeat = f.verdict as HairNeat; break;
      case "hair_length": hairLength = f.verdict as HairLength; break;
      case "head_covering": headCovering = f.verdict as HeadCovering; break;
    }
    if (f.message) flaggedMessages.push(f.message);
  }

  const breakdown = computeScoreBreakdown(
    { faceCleanShave, uniformCompliant, hairNeat, hairLength, photoQuality },
    config,
  );
  const reasoning = buildReasoning({
    faceCleanShave,
    uniformCompliant,
    hairNeat,
    hairLength,
    headCovering,
    photoQuality,
    faceDetected,
    extraNotes: flaggedMessages,
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
    hairLength,
    headCovering,
    groomingLabels: labels,
    groomingScore: Number(breakdown.total.toFixed(1)),
    scoreBreakdown: breakdown,
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
  hairLength?: HairLength;
  photoQuality: PhotoQuality;
}

export function computeScoreBreakdown(
  input: ScoreInput,
  config: GroomingConfig = DEFAULT_GROOMING_CONFIG,
): ScoreBreakdown {
  const w = config.weights;
  const partial = (weight: number) => Math.min(1, weight);

  let face = 0;
  if (input.faceCleanShave === "ok") face = w.face;
  else if (input.faceCleanShave === "unclear") face = partial(w.face);

  let uniform = 0;
  if (input.uniformCompliant === "ok") uniform = w.uniform;
  else if (input.uniformCompliant === "unclear") uniform = partial(w.uniform);

  // Hair: covered hair is fine; messy or long hair forfeits the hair points.
  let hair = w.hair;
  if (input.hairNeat === "not_visible") hair = w.hair;
  else if (input.hairNeat === "messy") hair = 0;
  else if (input.hairLength === "long") hair = 0;

  const photo = input.photoQuality === "clear" ? w.photo : 0;

  const max = w.face + w.uniform + w.hair + w.photo;
  const total = Math.min(face + uniform + hair + photo, max);
  return { face, uniform, hair, photo, total, max };
}

export function computeScore(
  input: ScoreInput,
  config: GroomingConfig = DEFAULT_GROOMING_CONFIG,
): number {
  return computeScoreBreakdown(input, config).total;
}

interface ReasoningInput {
  faceCleanShave: FaceCleanShave;
  uniformCompliant: UniformCompliant;
  hairNeat: HairNeat;
  hairLength?: HairLength;
  headCovering: HeadCovering;
  photoQuality: PhotoQuality;
  faceDetected: boolean;
  extraNotes?: string[];
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
  else if (input.hairLength === "long") parts.push("Rambut panjang");
  else if (input.hairNeat === "ok" && input.faceDetected) parts.push("Rambut OK");

  if (input.photoQuality === "blurry") parts.push("Foto buram");
  else if (input.photoQuality === "dark") parts.push("Foto gelap");
  else if (input.photoQuality === "overexposed") parts.push("Foto terlalu terang");
  else if (input.photoQuality === "clear") parts.push("Foto jelas");

  for (const note of input.extraNotes ?? []) {
    if (note && note.trim().length > 0) parts.push(note.trim());
  }

  const text = parts.join(". ") + ".";
  return text.length > 200 ? text.slice(0, 197) + "..." : text;
}
