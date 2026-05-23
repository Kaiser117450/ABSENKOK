// grooming_rules_test.ts
import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  matchAnyLabel,
  extractFaceCleanShave,
  extractHeadCovering,
  extractUniformCompliant,
  extractHairNeat,
  extractPhotoQuality,
} from "./grooming_rules.ts";
import type { VisionLabel } from "./grooming_rules.ts";

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
