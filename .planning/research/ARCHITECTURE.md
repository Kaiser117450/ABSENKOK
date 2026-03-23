# Architecture Research

**Domain:** Flutter Android release hardening
**Researched:** 2026-03-23
**Confidence:** HIGH

## Standard Architecture

### System Overview

```text
┌──────────────────────────────────────────────────────────────┐
│                     Source & Validation                      │
├──────────────────────────────────────────────────────────────┤
│  pubspec version  │  flutter analyze  │  flutter test       │
├──────────────────────────────────────────────────────────────┤
│                  Flutter Release Commands                    │
├──────────────────────────────────────────────────────────────┤
│  build appbundle  │  build apk  │  symbolize/debug info     │
├──────────────────────────────────────────────────────────────┤
│                 Android Build Configuration                  │
├──────────────────────────────────────────────────────────────┤
│  settings.gradle  │  build.gradle  │  gradle.properties      │
├──────────────────────────────────────────────────────────────┤
│              Toolchain & Secret Configuration                │
├──────────────────────────────────────────────────────────────┤
│ daemon JVM / JBR  │  key.properties  │  upload-keystore.jks  │
├──────────────────────────────────────────────────────────────┤
│                     Release Artifacts                        │
│  signed .aab  │  operator .apk  │  split-debug-info bundle  │
└──────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Source validation layer | Prove the repo can still compile and pass core checks before packaging | `flutter analyze`, `flutter test`, and any focused release-only compile check |
| Flutter release layer | Produce the release artifact set | `flutter build appbundle`, optional `flutter build apk`, `flutter symbolize` |
| Android config layer | Define signing, shrinking, version, and packaging behavior | `android/app/build.gradle.kts`, `android/settings.gradle.kts`, wrapper, Gradle properties |
| Toolchain/secret layer | Freeze the supported JVM and private signing inputs | Android Studio JBR / daemon JVM criteria, `android/key.properties`, private keystore |
| Release operations layer | Turn the above into a repeatable operator flow | Local runbook or script, then optional CI automation |

## Recommended Project Structure

```text
absensi_enakko_flutter/
├── pubspec.yaml                         # versionName + build number source of truth
├── android/
│   ├── settings.gradle.kts             # AGP + Kotlin plugin versions
│   ├── build.gradle.kts                # root Gradle behavior
│   ├── gradle.properties               # Gradle memory/build defaults
│   ├── gradle/
│   │   ├── wrapper/gradle-wrapper.properties
│   │   └── gradle-daemon-jvm.properties   # recommended to check in during v7.0
│   ├── app/build.gradle.kts            # signing, shrink, artifact contract
│   ├── key.properties                  # private, gitignored
│   └── local.properties                # local SDK paths, not the long-term contract
├── build/
│   ├── app/outputs/...                 # generated release artifacts
│   └── debug-info/<version>/           # retained symbol/debug output
└── .planning/
    ├── PROJECT.md
    ├── REQUIREMENTS.md
    ├── ROADMAP.md
    └── research/                       # release hardening rationale and pitfalls
```

### Structure Rationale

- **`pubspec.yaml` remains the version source of truth:** Flutter propagates versionName/versionCode from here, so release hardening should fix drift at the source rather than in ad hoc scripts.
- **`local.properties` is not enough for the toolchain contract:** it can point to a good local Java path, but it is not the versioned multi-machine answer. Use checked-in daemon JVM criteria or an explicit release script.
- **The release lane should own symbol retention:** obfuscation or shrink steps are only supportable if debug artifacts are stored by milestone version.

## Architectural Patterns

### Pattern 1: Fail-fast release preflight

**What:** Run lightweight validation before expensive packaging and signing.
**When to use:** Every time a release artifact is cut.
**Trade-offs:** Slightly longer scripted flow, but much faster diagnosis than discovering basic compile issues after packaging starts.

### Pattern 2: Checked-in daemon JVM contract

**What:** Version the supported JVM for running Gradle rather than relying on ambient shell state.
**When to use:** As soon as more than one machine can cut releases or shell Java differs from the proven-good JBR.
**Trade-offs:** One more file in VCS, but dramatically less guesswork on Windows workstations and future CI runners.

### Pattern 3: Private signing indirection

**What:** Reference the upload keystore via `android/key.properties` instead of baking secrets into Gradle files.
**When to use:** All release builds that leave local development.
**Trade-offs:** Requires one-time secret setup, but protects credentials and matches Flutter's documented Android signing flow.

### Pattern 4: One release contract, multiple artifacts

**What:** One validated release lane produces the AAB, optional operator APK, and retained debug artifacts.
**When to use:** When the project needs both store-grade and side-loadable distribution.
**Trade-offs:** Slightly more artifact management, but avoids divergent and untested packaging paths.

## Data Flow

### Release Flow

```text
pubspec version update
    ↓
analyze / test / focused release compile checks
    ↓
toolchain verification (Flutter + Java baseline)
    ↓
Gradle loads signing + shrink config
    ↓
Flutter builds AAB/APK
    ↓
artifacts + debug-info retained by version
```

### Key Data Flows

1. **Version flow:** `.planning` milestone -> `pubspec.yaml` -> `flutter.versionName` / `flutter.versionCode` -> artifact file names.
2. **Toolchain flow:** repo contract -> Gradle daemon JVM -> AGP/Kotlin execution -> Flutter packaging.
3. **Secret flow:** local secret file -> Gradle signing config -> signed release artifact.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Single operator, local-only releases | Local runbook plus checked-in toolchain contract is enough |
| Multiple operators or multiple Windows machines | Add daemon JVM criteria and a shared release checklist immediately |
| CI-driven release automation | Add encrypted secrets and scripted release lanes only after the local flow is stable |

### Scaling Priorities

1. **First bottleneck:** release compile drift in app code. Fix this before touching automation.
2. **Second bottleneck:** machine-specific Java and signing behavior. Codify both in files or scripts.
3. **Third bottleneck:** publication/distribution automation. Only automate a release path that is already deterministic.

## Anti-Patterns

### Anti-Pattern 1: Treat packaging as the first validation step

**What people do:** Go straight to `flutter build apk --release` and hope packaging tells the whole story.
**Why it's wrong:** You waste time reaching the packaging stage only to find basic Dart compile or analysis failures.
**Do this instead:** Put preflight gates before packaging and keep the failure surface small.

### Anti-Pattern 2: Use debug signing because it "works for now"

**What people do:** Leave `release` pointing at the debug signing config indefinitely.
**Why it's wrong:** It produces an unsafe and operationally ambiguous release contract.
**Do this instead:** Move to a private upload-keystore flow and document the secret bootstrap.

### Anti-Pattern 3: Rely on ambient Java from the shell

**What people do:** Assume whichever `java` is first on PATH is the supported build runtime.
**Why it's wrong:** This repo already proves the mismatch risk: shell Java is 25 while local project config points to Android Studio JBR.
**Do this instead:** Version the Gradle daemon JVM criteria or make the release script set the known-good Java path.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Android toolchain / JDK | Known-good local path or daemon JVM criteria | Must be explicit for reproducibility |
| Optional GitHub Release / CI tooling | Scripted after artifact generation | Not required for the MVP hardening milestone |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Planning docs -> release metadata | Milestone version and artifact naming | Prevent v6.3/v6.2-style drift |
| Gradle config -> secrets | `key.properties` indirection | Never commit keystore or passwords |
| Packaging -> operations | Release runbook or script | Operators need a deterministic path |

## Sources

- Local repo: `pubspec.yaml`
- Local repo: `android/app/build.gradle.kts`
- Local repo: `android/settings.gradle.kts`
- Local repo: `android/local.properties`
- Local repo: `build.log`
- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Flutter: Continuous delivery with Flutter](https://docs.flutter.dev/deployment/cd)
- [Android Developers: Configure your build](https://developer.android.com/build)
- [Gradle: Gradle Daemon](https://docs.gradle.org/current/userguide/gradle_daemon.html)

---
*Architecture research for: Flutter Android release hardening*
*Researched: 2026-03-23*
