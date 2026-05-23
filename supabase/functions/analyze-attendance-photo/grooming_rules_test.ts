// grooming_rules_test.ts
// Type-shape tests for grooming_rules.ts — verifies the module compiles and
// exports the right types. Logic tests are added in A5–A7.

import { assertEquals, assertExists } from "https://deno.land/std@0.208.0/assert/mod.ts";
import type {
  GroomingResult,
  FaceCleanShave,
  HeadCovering,
  UniformCompliant,
  HairNeat,
  VisionResponse,
} from "./grooming_rules.ts";
import { parseGroomingAnalysis } from "./grooming_rules.ts";

Deno.test("parseGroomingAnalysis returns a GroomingResult with all required fields", () => {
  const vision: VisionResponse = {
    labelAnnotations: [],
    faceAnnotations: [],
  };
  const result = parseGroomingAnalysis(vision);

  assertExists(result.grooming_score, "grooming_score must be present");
  assertExists(result.face_clean_shave, "face_clean_shave must be present");
  assertExists(result.head_covering !== undefined, "head_covering must be present");
  assertExists(result.uniform_compliant, "uniform_compliant must be present");
  assertExists(result.hair_neat, "hair_neat must be present");
  assertExists(result.reasoning, "reasoning must be present");
  assertExists(result.model_name, "model_name must be present");
});

Deno.test("grooming_score is a number between 0 and 10", () => {
  const result = parseGroomingAnalysis({ labelAnnotations: [] });
  assertEquals(typeof result.grooming_score, "number");
  assertEquals(result.grooming_score >= 0 && result.grooming_score <= 10, true);
});

Deno.test("face_clean_shave is a valid enum value", () => {
  const valid: FaceCleanShave[] = ["ok", "stubble", "mustache", "beard", "unclear"];
  const result = parseGroomingAnalysis({});
  assertEquals(valid.includes(result.face_clean_shave), true);
});

Deno.test("head_covering is a valid enum value", () => {
  const valid: HeadCovering[] = ["none", "hijab", "cap", "other"];
  const result = parseGroomingAnalysis({});
  assertEquals(valid.includes(result.head_covering), true);
});

Deno.test("uniform_compliant is a valid enum value", () => {
  const valid: UniformCompliant[] = ["ok", "no_uniform", "wrong_attire", "unclear"];
  const result = parseGroomingAnalysis({});
  assertEquals(valid.includes(result.uniform_compliant), true);
});

Deno.test("hair_neat is a valid enum value", () => {
  const valid: HairNeat[] = ["ok", "messy", "not_visible"];
  const result = parseGroomingAnalysis({});
  assertEquals(valid.includes(result.hair_neat), true);
});

Deno.test("reasoning is a non-empty string no longer than 200 chars", () => {
  const result = parseGroomingAnalysis({});
  assertEquals(typeof result.reasoning, "string");
  assertEquals(result.reasoning.length <= 200, true);
  assertEquals(result.reasoning.length > 0, true);
});

Deno.test("model_name is cloud-vision-rubric-v1", () => {
  const result = parseGroomingAnalysis({});
  assertEquals(result.model_name, "cloud-vision-rubric-v1");
});
