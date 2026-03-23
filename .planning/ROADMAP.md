# Milestone v7.0: Android Release Hardening

**Status:** IN PROGRESS 2026-03-23
**Phases:** 46-49
**Total Plans:** 10

## Overview

Restore a deterministic Android release path for the Flutter kiosk app before resuming new product work. The milestone closes the current release packaging blockers, codifies the supported toolchain, replaces debug signing with a private upload-key flow, and turns release work into a repeatable operator process with clear artifacts.

## Phases

### Phase 46: Release Baseline Recovery

**Goal:** Re-establish a clean Android release packaging baseline and align version metadata with the active milestone.
**Depends on:** Phase 45 closeout and current repo state
**Plans:** 2/2 plans complete

Plans:

- [x] 46-01: Restore the canonical Android release build path by removing the current release-only packaging blocker
- [x] 46-02: Align `pubspec.yaml`, milestone versioning, and generated artifact naming for v7.0

**Details:**
- Requirements: `BUILD-01`, `BUILD-03`
- Keep Flutter 3.41.1, AGP 8.11.1, and Gradle 8.14 fixed while closing concrete repo drift first
- Do not mix new product features into the baseline recovery phase

**Success criteria:**
1. The canonical release command reaches Android packaging without the known Dart errors
2. Release metadata and output names clearly identify the v7.0 milestone
3. No new product-scope changes are introduced while restoring the baseline

### Phase 47: Toolchain Contract & Preflight Gates

**Goal:** Turn the current machine-specific release setup into an explicit, fail-fast build contract.
**Depends on:** Phase 46
**Plans:** 3/3 plans complete

Plans:

- [x] 47-01: Codify the supported Java runtime for Gradle and document the Flutter/Gradle baseline
- [x] 47-02: Add a release preflight lane for analyze, test, and release-compile checks
- [x] 47-03: Record the v7.0 Kotlin compatibility decision so operators do not rely on bypass flags or surprise upgrades

**Details:**
- Requirements: `BUILD-02`, `TOOL-01`, `TOOL-02`
- Shell Java drift is a known risk because `java -version` resolves to Temurin 25 while local project config points to Android Studio JBR
- Preflight must fail before signing or expensive packaging begins

**Success criteria:**
1. Another machine can identify the supported Java runtime without tribal knowledge
2. Release preflight fails before packaging when analysis, tests, or release-only compile steps are red
3. The team has one explicit v7.0 compatibility position for Flutter/Kotlin/Gradle

### Phase 48: Secure Signing & Artifact Discipline

**Goal:** Replace debug signing with a secure upload-key flow and formalize the release artifact set.
**Depends on:** Phase 47
**Plans:** 1/3 plans executed

Plans:

- [x] 48-01: Wire release signing through a private upload-keystore and `android/key.properties`
- [ ] 48-02: Produce the agreed artifact set from one validated lane: canonical `.aab` plus release `.apk` only if outlet side-loading still needs it
- [ ] 48-03: Retain split debug info or symbol artifacts and smoke-verify the shrunken release output before distribution

**Details:**
- Requirements: `REL-01`, `REL-02`, `REL-03`
- Flutter docs explicitly treat upload-key signing and `key.properties` as the Android release pattern; the current debug signing config must be removed from the final release lane
- Artifact discipline must include naming, retention, and verification rules, not just file generation

**Success criteria:**
1. `release` no longer depends on the debug signing config
2. The milestone can cut the agreed artifact set from one validated release flow
3. Matching debug or symbol artifacts are retained and linked to the signed release version

### Phase 49: Release Runbook & Acceptance

**Goal:** Prove that the release baseline is reproducible by an operator who did not invent it.
**Depends on:** Phase 48
**Plans:** 2 plans

Plans:

- [ ] 49-01: Write the local release runbook with secret/bootstrap placeholders and exact commands
- [ ] 49-02: Reproduce the artifact set from the runbook and capture acceptance evidence for v7.0

**Details:**
- Requirements: `OPS-01`
- This phase closes the milestone by turning the release flow into explicit operational knowledge
- CI/CD automation stays out of scope until this local acceptance passes

**Success criteria:**
1. A second operator can follow the documented runbook without guessing hidden prerequisites
2. Acceptance evidence confirms the runbook reproduces the expected artifact set
3. The milestone ends with a decision-ready baseline for future automation or product work

---

## Milestone Summary

**Decimal Phases:**

- None

**Key Decisions:**

- v7.0 is a release-hardening milestone, not a new product-feature milestone
- Java 21 via Android Studio JBR is the supported Gradle runtime until a later compatibility spike proves a different baseline
- A signed `.aab` is the canonical release artifact; a release `.apk` remains optional for outlet side-loading only if operations still require it
- CI/CD automation is deferred until the local release lane is reproducible by another operator

**Issues Targeted:**

- Release build currently fails on concrete Dart compile errors before Android packaging completes
- `release` still signs with the debug configuration
- Version metadata has drifted behind the planning state
- Supported Java runtime is implicit instead of versioned

**Issues Deferred:**

- Employee portal correction/time-off/approval flows
- Reminder or notification workflows
- Build-speed optimization
- APK/AAB size or runtime tuning
- CI/CD or GitHub Release automation

**Technical Debt Monitored During v7.0:**

- Flutter 3.41.1 warns that Kotlin 1.9.25 will lose support in a future cycle
- The repo still contains a separate Astro toolchain, but website deployment remains outside this milestone

---

_For the active milestone context, see `.planning/PROJECT.md` and `.planning/REQUIREMENTS.md`_
