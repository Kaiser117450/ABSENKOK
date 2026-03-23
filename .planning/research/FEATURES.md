# Feature Research

**Domain:** Android release reliability for a Flutter kiosk app
**Researched:** 2026-03-23
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Clean release build from a clean checkout | Operators cannot ship or verify anything if release packaging fails on fresh state | HIGH | Current release logs already fail before Android packaging completes. |
| Secure release signing | A distributed Android app must not ship with debug credentials | MEDIUM | This is the most obvious configuration gap in the current repo. |
| Version and artifact alignment | Operators need to know which APK/AAB matches which milestone | MEDIUM | `pubspec.yaml`, planning docs, and file names must stop drifting. |
| Documented release steps | Release work is operationally fragile without a repeatable checklist or script | MEDIUM | Especially important because this repo has both Flutter and Astro toolchains in one tree. |

### Differentiators (High-Leverage Hardening)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Checked-in Java daemon contract | Turns "works on my machine" into a versioned toolchain baseline | MEDIUM | Particularly valuable because shell Java is 25 while known-good Java is Android Studio JBR. |
| Fast-fail validation lane | Catches analyze/test/compile drift before expensive signing/packaging work | MEDIUM | Release reliability improves most when packaging is not the first signal of breakage. |
| Dual artifact discipline (AAB + operator APK + symbols) | Supports both store-grade packaging and outlet side-loading without divergent flows | MEDIUM | Keep one canonical release contract, then derive the needed artifacts from it. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Build-speed-only tuning first | "Optimasi build" often gets interpreted as shorter build times | Fast builds do not matter if the release still fails, signs incorrectly, or drifts in versioning | Establish the reliable release baseline first, then optimize time/caching later. |
| New product features inside the same milestone | Teams want to "just ship one small thing too" once they touch release code | It mixes acceptance criteria and makes it impossible to tell whether release failures come from product scope or release hardening | Freeze feature work during v7.0 and resume after the pipeline is reproducible. |
| Blind Kotlin or AGP upgrade | Flutter warns that Kotlin 1.9.25 will be unsupported soon | The repo explicitly depends on staying off Kotlin 2.x because of `nfc_manager` compatibility concerns | Capture the warning as risk, pin the current baseline, then research the plugin compatibility separately. |
| CI/CD before a stable local release lane exists | Automation sounds like the final answer | Broken local assumptions just become broken CI with harder debugging and secret handling | First prove one local clean-checkout release flow, then automate it. |

## Feature Dependencies

```text
Release artifact generation
    └──requires──> compile/analyze/test baseline
    └──requires──> supported Flutter/Java/Gradle contract
    └──requires──> secure signing config

Secure signing
    └──requires──> private key material outside VCS

CI / automated release
    └──requires──> stable local release lane
```

### Dependency Notes

- **Packaging depends on build health first:** toolchain cleanup will not help if the repo still has compile blockers in release mode.
- **Secure signing depends on secret handling:** the keystore path and passwords must exist outside git before `release` can safely stop using debug signing.
- **Automation depends on a proven local lane:** until local release is deterministic, CI only adds noise and secret-management complexity.

## MVP Definition

### Launch With (v7.0)

- [ ] Release build succeeds from a clean checkout on the supported toolchain
- [ ] Release signing no longer uses the debug keystore
- [ ] Version/build metadata and output artifact names match the milestone version
- [ ] Release workflow includes analyze/test/build gates plus symbol retention
- [ ] One local operator runbook can produce the expected artifact set consistently

### Add After Validation (v7.0.x)

- [ ] Optional GitHub Release or internal distribution automation once the local lane is stable
- [ ] More polished operator UX around release notes and artifact publishing

### Future Consideration (v7.1+)

- [ ] Build-speed optimization and cache tuning
- [ ] APK size investigation and runtime startup profiling
- [ ] Kotlin / plugin upgrade program once `nfc_manager` compatibility is proven
- [ ] Resume the deferred employee portal request/approval milestone

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Clean release build | HIGH | HIGH | P1 |
| Secure upload signing | HIGH | MEDIUM | P1 |
| Version/artifact alignment | HIGH | MEDIUM | P1 |
| Local release runbook | HIGH | MEDIUM | P1 |
| CI automation | MEDIUM | MEDIUM | P2 |
| Build-speed optimization | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for the milestone to be credible
- P2: Valuable once the baseline is stable
- P3: Future optimization work

## Competitor Feature Analysis

| Concern | Mature Android release pipelines typically do | Current repo state | Our Approach |
|---------|-----------------------------------------------|--------------------|--------------|
| Signing | Use a private upload key, never debug signing | `release` still points at the debug signing config | Move to upload-key signing through `key.properties` and secret handling |
| Toolchain | Lock wrapper/tool versions and document the supported JDK | Wrapper is pinned, but the runtime Java contract is still implicit | Check in the supported Java contract and document it in the release lane |
| Packaging | Build a signed AAB and retain diagnostics for post-release failures | APK flow exists, but artifact strategy and symbol retention are inconsistent | Make AAB canonical, keep operator APK optional, and retain symbol output by version |

## Sources

- Local repo: `android/app/build.gradle.kts`
- Local repo: `android/settings.gradle.kts`
- Local repo: `android/local.properties`
- Local repo: `build.log`
- Local repo: `flutter_build.log`
- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Flutter: Continuous delivery with Flutter](https://docs.flutter.dev/deployment/cd)
- [Android Developers: Configure your build](https://developer.android.com/build)

---
*Feature research for: Android release reliability*
*Researched: 2026-03-23*
