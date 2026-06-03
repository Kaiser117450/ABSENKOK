// grooming_rules_test.ts
import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  matchAnyLabel,
  extractFaceCleanShave,
  extractHeadCovering,
  extractUniformCompliant,
  extractHairNeat,
  extractHairLength,
  extractPhotoQuality,
  computeScore,
  computeScoreBreakdown,
  buildReasoning,
  parseGroomingAnalysis,
  normalizeGroomingConfig,
  DEFAULT_GROOMING_CONFIG,
} from "./grooming_rules.ts";
import type { VisionLabel, GroomingConfig } from "./grooming_rules.ts";

// --- test fixtures ---
const beardLabels: VisionLabel[] = [
  { description: "Beard", score: 0.92 },
  { description: "Person", score: 0.95 },
];
const hijabLabels: VisionLabel[] = [
  { description: "Hijab", score: 0.88 },
  { description: "Person", score: 0.95 },
];
const capLabels: VisionLabel[] = [
  { description: "Hat", score: 0.91 },
  { description: "Cap", score: 0.85 },
];
const apronLabels: VisionLabel[] = [
  { description: "Apron", score: 0.81 },
  { description: "Person", score: 0.94 },
];
const lowConfBeardLabels: VisionLabel[] = [
  { description: "Beard", score: 0.40 },
];

// matchAnyLabel
Deno.test("matchAnyLabel respects MIN_LABEL_SCORE", () => {
  assertEquals(matchAnyLabel(beardLabels, ["beard"]), true);
  assertEquals(matchAnyLabel(lowConfBeardLabels, ["beard"]), false);
});

// extractFaceCleanShave
Deno.test("extractFaceCleanShave detects beard precedence", () => {
  assertEquals(extractFaceCleanShave(beardLabels, true), "beard");
});

Deno.test("extractFaceCleanShave returns ok when face detected and no facial hair", () => {
  assertEquals(extractFaceCleanShave(apronLabels, true), "ok");
});

Deno.test("extractFaceCleanShave returns unclear when face not detected", () => {
  assertEquals(extractFaceCleanShave(apronLabels, false), "unclear");
});

// extractHeadCovering
Deno.test("extractHeadCovering tags hijab", () => {
  assertEquals(extractHeadCovering(hijabLabels), "hijab");
});

Deno.test("extractHeadCovering tags cap for Hat label", () => {
  assertEquals(extractHeadCovering(capLabels), "cap");
});

Deno.test("extractHeadCovering tags cap for Cap label", () => {
  assertEquals(extractHeadCovering([{ description: "Cap", score: 0.85 }]), "cap");
});

Deno.test("extractHeadCovering returns none when no head label", () => {
  assertEquals(extractHeadCovering(apronLabels), "none");
});

Deno.test("extractHeadCovering hijab takes priority over cap", () => {
  assertEquals(
    extractHeadCovering([
      { description: "Hijab", score: 0.88 },
      { description: "Hat", score: 0.91 },
    ]),
    "hijab",
  );
});

// extractUniformCompliant
Deno.test("extractUniformCompliant ok when apron present", () => {
  assertEquals(extractUniformCompliant(apronLabels, true), "ok");
});

Deno.test("extractUniformCompliant no_uniform when no match and face detected", () => {
  assertEquals(
    extractUniformCompliant([{ description: "Person", score: 0.94 }], true),
    "no_uniform",
  );
});

Deno.test("extractUniformCompliant wrong_attire on tank top", () => {
  assertEquals(
    extractUniformCompliant([{ description: "Tank top", score: 0.81 }], true),
    "wrong_attire",
  );
});

// extractHairNeat
Deno.test("extractHairNeat returns not_visible when head covered with hijab", () => {
  assertEquals(extractHairNeat(hijabLabels, "hijab"), "not_visible");
});

Deno.test("extractHairNeat returns not_visible when head covered with cap", () => {
  assertEquals(extractHairNeat(capLabels, "cap"), "not_visible");
});

Deno.test("extractHairNeat returns messy on disheveled label", () => {
  assertEquals(
    extractHairNeat([{ description: "Messy hair", score: 0.7 }], "none"),
    "messy",
  );
});

Deno.test("extractHairNeat returns ok by default", () => {
  assertEquals(extractHairNeat(apronLabels, "none"), "ok");
});

// extractPhotoQuality
Deno.test("extractPhotoQuality detects blurry first", () => {
  assertEquals(
    extractPhotoQuality([
      { description: "Blur", score: 0.81 },
      { description: "Darkness", score: 0.88 },
    ]),
    "blurry",
  );
});

Deno.test("extractPhotoQuality defaults clear", () => {
  assertEquals(extractPhotoQuality(apronLabels), "clear");
});

// --- A6: score formula + reasoning tests ---

Deno.test("computeScore max when all OK", () => {
  assertEquals(
    computeScore({
      faceCleanShave: "ok",
      uniformCompliant: "ok",
      hairNeat: "ok",
      photoQuality: "clear",
    }),
    10,
  );
});

Deno.test("computeScore hijab + apron + clean shave = 10", () => {
  assertEquals(
    computeScore({
      faceCleanShave: "ok",
      uniformCompliant: "ok",
      hairNeat: "not_visible",
      photoQuality: "clear",
    }),
    10,
  );
});

Deno.test("computeScore beard penalty (beard = 0 for face)", () => {
  assertEquals(
    computeScore({
      faceCleanShave: "beard",
      uniformCompliant: "ok",
      hairNeat: "ok",
      photoQuality: "clear",
    }),
    7,
  );
});

Deno.test("computeScore unclear gives partial credit", () => {
  assertEquals(
    computeScore({
      faceCleanShave: "unclear",
      uniformCompliant: "unclear",
      hairNeat: "ok",
      photoQuality: "clear",
    }),
    6,
  );
});

Deno.test("computeScore caps at 10", () => {
  const score = computeScore({
    faceCleanShave: "ok",
    uniformCompliant: "ok",
    hairNeat: "ok",
    photoQuality: "clear",
  });
  assertEquals(score <= 10, true);
});

Deno.test("buildReasoning lists issues then OKs in Indonesian", () => {
  const r = buildReasoning({
    faceCleanShave: "beard",
    uniformCompliant: "ok",
    hairNeat: "ok",
    headCovering: "none",
    photoQuality: "clear",
    faceDetected: true,
  });
  assertEquals(r.startsWith("Terdeteksi jenggot"), true);
  assertEquals(r.includes("Seragam OK"), true);
  assertEquals(r.length <= 200, true);
});

Deno.test("buildReasoning highlights hijab as positive", () => {
  const r = buildReasoning({
    faceCleanShave: "ok",
    uniformCompliant: "ok",
    hairNeat: "not_visible",
    headCovering: "hijab",
    photoQuality: "clear",
    faceDetected: true,
  });
  assertEquals(r.includes("Berhijab"), true);
  assertEquals(r.includes("rambut OK"), true);
});

Deno.test("buildReasoning highlights cap (topi)", () => {
  const r = buildReasoning({
    faceCleanShave: "ok",
    uniformCompliant: "ok",
    hairNeat: "not_visible",
    headCovering: "cap",
    photoQuality: "clear",
    faceDetected: true,
  });
  assertEquals(r.includes("topi"), true);
});

Deno.test("buildReasoning notes blurry photo", () => {
  const r = buildReasoning({
    faceCleanShave: "ok",
    uniformCompliant: "ok",
    hairNeat: "ok",
    headCovering: "none",
    photoQuality: "blurry",
    faceDetected: true,
  });
  assertEquals(r.includes("buram"), true);
});

Deno.test("buildReasoning when face not detected leads", () => {
  const r = buildReasoning({
    faceCleanShave: "unclear",
    uniformCompliant: "unclear",
    hairNeat: "ok",
    headCovering: "none",
    photoQuality: "blurry",
    faceDetected: false,
  });
  assertEquals(r.startsWith("Wajah tidak terdeteksi"), true);
});

// --- A7: parseGroomingAnalysis integration tests ---

const cannedBeardResponse = {
  responses: [{
    labelAnnotations: [
      { description: "Beard", score: 0.92 },
      { description: "Person", score: 0.96 },
      { description: "Shirt", score: 0.84 },
    ],
    faceAnnotations: [{ detectionConfidence: 0.93 }],
    safeSearchAnnotation: { adult: "VERY_UNLIKELY", violence: "UNLIKELY", racy: "UNLIKELY" },
  }],
};

Deno.test("parseGroomingAnalysis penalises beard", () => {
  const r = parseGroomingAnalysis(cannedBeardResponse);
  assertEquals(r.faceDetected, true);
  assertEquals(r.faceCleanShave, "beard");
  assertEquals(r.groomingScore < 8, true);
  assertEquals(r.modelName, "cloud-vision-rubric-v1");
  assertEquals(r.safeSearchPassed, true);
});

const cannedHijabResponse = {
  responses: [{
    labelAnnotations: [
      { description: "Hijab", score: 0.89 },
      { description: "Apron", score: 0.82 },
      { description: "Person", score: 0.95 },
    ],
    faceAnnotations: [{ detectionConfidence: 0.86 }],
    safeSearchAnnotation: { adult: "VERY_UNLIKELY", violence: "VERY_UNLIKELY", racy: "VERY_UNLIKELY" },
  }],
};

Deno.test("parseGroomingAnalysis is hijab-neutral and rewards apron", () => {
  const r = parseGroomingAnalysis(cannedHijabResponse);
  assertEquals(r.headCovering, "hijab");
  assertEquals(r.hairNeat, "not_visible");
  assertEquals(r.uniformCompliant, "ok");
  assertEquals(r.groomingScore, 10);
});

Deno.test("parseGroomingAnalysis handles empty responses", () => {
  const r = parseGroomingAnalysis({ responses: [{}] });
  assertEquals(r.faceDetected, false);
  assertEquals(r.faceCount, 0);
  assertEquals(r.faceCleanShave, "unclear");
});

// --- A9: fixture-driven regression tests ---

async function loadFixture(name: string): Promise<Record<string, unknown>> {
  const url = new URL(`./fixtures/${name}.json`, import.meta.url);
  const text = await Deno.readTextFile(url);
  return JSON.parse(text);
}

Deno.test("fixture: beard photo → face_clean_shave=beard, score<8", async () => {
  const r = parseGroomingAnalysis(await loadFixture("vision_beard"));
  assertEquals(r.faceCleanShave, "beard");
  assertEquals(r.groomingScore < 8, true);
});

Deno.test("fixture: hijab photo → head_covering=hijab, hair=not_visible, score=10", async () => {
  const r = parseGroomingAnalysis(await loadFixture("vision_hijab"));
  assertEquals(r.headCovering, "hijab");
  assertEquals(r.hairNeat, "not_visible");
  assertEquals(r.groomingScore, 10);
});

Deno.test("fixture: clean photo → faceCleanShave=ok, uniform=ok, score>=9", async () => {
  const r = parseGroomingAnalysis(await loadFixture("vision_clean"));
  assertEquals(r.faceCleanShave, "ok");
  assertEquals(r.uniformCompliant, "ok");
  assertEquals(r.groomingScore >= 9, true);
});

Deno.test("fixture: tank top → uniform_compliant=wrong_attire", async () => {
  const r = parseGroomingAnalysis(await loadFixture("vision_no_uniform"));
  assertEquals(r.uniformCompliant, "wrong_attire");
});

Deno.test("fixture: blurry photo → photoQuality=blurry, faceDetected=false", async () => {
  const r = parseGroomingAnalysis(await loadFixture("vision_blurry"));
  assertEquals(r.photoQuality, "blurry");
  assertEquals(r.faceDetected, false);
});

// --- Phase 72: hair length, score breakdown, config override, flagged labels ---

const longHairLabels: VisionLabel[] = [
  { description: "Long hair", score: 0.82 },
  { description: "Person", score: 0.95 },
];
const crewCutLabels: VisionLabel[] = [
  { description: "Crew cut", score: 0.71 },
  { description: "Long hair", score: 0.80 },
];

Deno.test("extractHairLength flags long hair when uncovered", () => {
  assertEquals(extractHairLength(longHairLabels, "none", true), "long");
});

Deno.test("extractHairLength: short-hair label vetoes long-hair guess", () => {
  assertEquals(extractHairLength(crewCutLabels, "none", true), "ok");
});

Deno.test("extractHairLength not_visible when head covered", () => {
  assertEquals(extractHairLength(longHairLabels, "hijab", true), "not_visible");
});

Deno.test("extractHairLength unclear when face not detected", () => {
  assertEquals(extractHairLength(longHairLabels, "none", false), "unclear");
});

Deno.test("computeScore: long hair forfeits hair points", () => {
  assertEquals(
    computeScore({
      faceCleanShave: "ok",
      uniformCompliant: "ok",
      hairNeat: "ok",
      hairLength: "long",
      photoQuality: "clear",
    }),
    7,
  );
});

Deno.test("computeScoreBreakdown reports per-criterion points", () => {
  const b = computeScoreBreakdown({
    faceCleanShave: "beard",
    uniformCompliant: "ok",
    hairNeat: "ok",
    hairLength: "ok",
    photoQuality: "clear",
  });
  assertEquals(b.face, 0);
  assertEquals(b.uniform, 3);
  assertEquals(b.hair, 3);
  assertEquals(b.photo, 1);
  assertEquals(b.total, 7);
  assertEquals(b.max, 10);
});

Deno.test("buildReasoning mentions rambut panjang", () => {
  const r = buildReasoning({
    faceCleanShave: "ok",
    uniformCompliant: "ok",
    hairNeat: "ok",
    hairLength: "long",
    headCovering: "none",
    photoQuality: "clear",
    faceDetected: true,
  });
  assertEquals(r.includes("Rambut panjang"), true);
});

Deno.test("parseGroomingAnalysis emits scoreBreakdown + hairLength", () => {
  const r = parseGroomingAnalysis(cannedBeardResponse);
  assertEquals(typeof r.scoreBreakdown.total, "number");
  assertEquals(r.scoreBreakdown.face, 0); // beard
  assertEquals(r.scoreBreakdown.total, r.groomingScore);
  assertEquals(typeof r.hairLength, "string");
});

// --- config override ---

Deno.test("normalizeGroomingConfig merges partial config with defaults", () => {
  const cfg = normalizeGroomingConfig({
    weights: { uniform: 5 },
    label_sets: { long_hair: ["mohawk"] },
    thresholds: { min_label_score: 0.4 },
  });
  assertEquals(cfg.weights.uniform, 5);
  assertEquals(cfg.weights.face, DEFAULT_GROOMING_CONFIG.weights.face); // default kept
  assertEquals(cfg.labelSets.longHair, ["mohawk"]);
  assertEquals(cfg.thresholds.minLabelScore, 0.4);
  // untouched label sets fall back to defaults
  assertEquals(cfg.labelSets.beard, DEFAULT_GROOMING_CONFIG.labelSets.beard);
});

Deno.test("config override: custom uniform weight changes score", () => {
  const cfg: GroomingConfig = normalizeGroomingConfig({ weights: { uniform: 5 } });
  const score = computeScore({
    faceCleanShave: "ok",
    uniformCompliant: "ok",
    hairNeat: "ok",
    photoQuality: "clear",
  }, cfg);
  // 3 + 5 + 3 + 1 = 12, capped at new max (12)
  assertEquals(score, 12);
});

Deno.test("config override: custom long-hair label is detected", () => {
  const cfg = normalizeGroomingConfig({ label_sets: { long_hair: ["mohawk"] } });
  const labels: VisionLabel[] = [{ description: "Mohawk", score: 0.8 }];
  assertEquals(extractHairLength(labels, "none", true, cfg), "long");
});

Deno.test("flagged label overlay forces criterion in parseGroomingAnalysis", () => {
  const cfg = normalizeGroomingConfig({
    flagged_labels: [
      { label: "sunglasses", criterion: "uniform_compliant", verdict: "wrong_attire", message: "Pakai kacamata hitam" },
    ],
  });
  const raw = {
    responses: [{
      labelAnnotations: [
        { description: "Sunglasses", score: 0.9 },
        { description: "Apron", score: 0.85 },
        { description: "Person", score: 0.95 },
      ],
      faceAnnotations: [{ detectionConfidence: 0.9 }],
      safeSearchAnnotation: { adult: "VERY_UNLIKELY", violence: "VERY_UNLIKELY", racy: "VERY_UNLIKELY" },
    }],
  };
  const r = parseGroomingAnalysis(raw, cfg);
  assertEquals(r.uniformCompliant, "wrong_attire"); // overridden despite apron
  assertEquals(r.reasoning.includes("kacamata hitam"), true);
});
