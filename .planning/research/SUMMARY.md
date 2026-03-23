# Project Research Summary

**Project:** Absensi Enakko
**Domain:** Flutter Android release hardening
**Researched:** 2026-03-23
**Confidence:** HIGH

## Executive Summary

The next milestone should not chase new product features yet. The current Android release path is materially unreliable: release builds are blocked by concrete Dart compile failures, `pubspec.yaml` version metadata has drifted behind the planning docs, and the Android `release` build still points at the debug signing configuration. On top of that, the repo's known-good Java path lives in local configuration while the shell currently resolves to Java 25, which means release success still depends on tribal machine setup.

Research points to a straightforward hardening path. Keep the current Flutter 3.41.1 / AGP 8.11.1 / Gradle 8.14 baseline, codify the supported Java runtime, fail fast on analysis/tests/compile before packaging, replace debug signing with an upload-keystore flow, and make one release contract that produces the expected artifact set plus retained debug symbols. Only after that local flow is deterministic should automation or new feature work resume.

## Key Findings

### Recommended Stack

The repo already has enough modern tooling to support a solid release baseline; the issue is configuration drift, not lack of capability. The most important stack decision is to treat Java 21 (Android Studio JBR) as the supported Gradle runtime while keeping the app's compile/jvm targets at 17, then check that contract into version control or into an explicit release script.

**Core technologies:**
- **Flutter 3.41.1 / Dart 3.11.0:** current stable build baseline and the correct place to keep release behavior stable through v7.0.
- **AGP 8.11.1 + Gradle 8.14:** already paired in repo config; preserve this known-good combination during hardening.
- **Java 21 for Gradle runtime:** the repo's proven-good JBR path; must stop being implicit.

### Expected Features

This milestone's "features" are release guarantees rather than end-user UI changes.

**Must have (table stakes):**
- Clean release build from a clean checkout on the supported toolchain
- Secure upload-key signing instead of debug signing
- Version/build metadata and artifact names aligned with the active milestone
- One deterministic local release runbook

**Should have (competitive):**
- Preflight validation that fails before packaging
- Dual artifact discipline (canonical AAB plus operator APK when needed)
- Retained debug/symbol output per version

**Defer (v2+):**
- CI/CD or GitHub Release automation
- Build-speed optimization
- APK size/runtime tuning
- Return to deferred portal request/approval work

### Architecture Approach

Treat the release path as a small system with five layers: source validation, Flutter packaging commands, Android/Gradle configuration, toolchain plus secret inputs, and operator release steps. The roadmap should move in dependency order: fix compile/version drift first, codify the toolchain second, secure signing and artifact outputs third, then close with a runbook and acceptance verification.

**Major components:**
1. **Build baseline layer** — analyze/test/compile gates plus version alignment
2. **Toolchain contract layer** — Flutter, Gradle, and Java runtime agreement
3. **Signing/artifact layer** — upload keystore, AAB/APK outputs, retained debug artifacts
4. **Operations layer** — deterministic local release runbook and verification evidence

### Critical Pitfalls

1. **Fixing warnings before code failures** — close the real compile blockers before touching larger toolchain migrations.
2. **Leaving debug signing in release** — treat this as a release blocker, not a TODO.
3. **Ambient Java drift** — codify the supported Gradle JVM because shell Java is already different from the proven-good JBR.
4. **Version drift** — align `pubspec.yaml`, milestone docs, and artifact names in one release contract.
5. **Automation too early** — do not add CI secrets and runners until the local release lane is deterministic.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 46: Release Baseline Recovery
**Rationale:** The release path is currently blocked by code and metadata drift; no signing or automation work matters until the app can package cleanly again.
**Delivers:** Closed release compile blockers, aligned version metadata, and a clean baseline release command.
**Addresses:** Build baseline, version alignment
**Avoids:** Toolchain churn before code failures are closed

### Phase 47: Toolchain Contract & Preflight Gates
**Rationale:** Once the app can package again, the next risk is hidden machine-specific behavior.
**Delivers:** Explicit Java/Flutter/Gradle contract and a fail-fast preflight lane.
**Uses:** Gradle daemon JVM criteria or explicit JBR release script, analyze/test gates
**Implements:** Toolchain contract layer

### Phase 48: Secure Signing & Artifact Discipline
**Rationale:** Only a stable baseline should receive secure signing and final artifact rules.
**Delivers:** Upload-key signing, canonical artifact outputs, retained symbol/debug artifacts.
**Uses:** `key.properties`, upload keystore, Flutter Android release flow
**Implements:** Signing/artifact layer

### Phase 49: Release Runbook & Acceptance
**Rationale:** The last step should prove that another operator can reproduce the release without tribal knowledge.
**Delivers:** Local release runbook, verification evidence, and a decision-ready automation handoff.

### Phase Ordering Rationale

- Fixing source and metadata drift first keeps later failures attributable to release infrastructure, not app regressions.
- Toolchain codification must precede signing because the signed release should come from the final supported environment.
- Signing and artifact discipline must precede runbook/automation work so the documented process reflects the real release contract.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 47:** Kotlin warning versus `nfc_manager` compatibility should be tracked explicitly so the team knows whether the current baseline is acceptable for v7.0.
- **Phase 48:** Secret bootstrap and storage pattern for the upload keystore must fit the team's actual operator setup.

Phases with standard patterns (skip research-phase):
- **Phase 46:** Fixing compile drift and version alignment is standard repo repair work.
- **Phase 49:** Runbook and acceptance verification follow common release-operations patterns.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against checked-in repo config and official Flutter/Android/Gradle docs |
| Features | HIGH | The required release guarantees are clear from the repo's current failure modes |
| Architecture | HIGH | Release pipeline layering is standard and directly matches the repo's file layout |
| Pitfalls | HIGH | The main risks are already visible in local config and logs |

**Overall confidence:** HIGH

### Gaps to Address

- **Kotlin warning path:** determine whether v7.0 will temporarily pin the current Kotlin baseline or include a narrowly scoped compatibility experiment
- **Distribution target:** confirm whether the canonical artifact after v7.0 should remain an outlet-side APK, a Play/Internal App Sharing AAB, or both

## Sources

### Primary (HIGH confidence)
- Local repo: `android/app/build.gradle.kts`, `android/settings.gradle.kts`, `android/local.properties`, `pubspec.yaml`, `build.log`, `flutter_build.log`
- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Flutter: Continuous delivery with Flutter](https://docs.flutter.dev/deployment/cd)
- [Android Developers: Configure your build](https://developer.android.com/build)
- [Gradle: Gradle Daemon](https://docs.gradle.org/current/userguide/gradle_daemon.html)

### Secondary (MEDIUM confidence)
- Historical repo planning: `.planning/phases/22-production-release/22-01-PLAN.md` — evidence of previous release conventions and prior Java/JBR usage

---
*Research completed: 2026-03-23*
*Ready for roadmap: yes*
