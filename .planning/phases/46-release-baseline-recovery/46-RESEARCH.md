# Phase 46: Release Baseline Recovery - Research

**Researched:** 2026-03-23
**Domain:** Android release baseline recovery, Windows-hosted Flutter build reliability, and v7.0 version metadata alignment
**Confidence:** HIGH for the current blocker and version-source-of-truth findings; MEDIUM for the exact lowest-risk remediation path because the failure sits at the Flutter/native-assets/toolchain boundary on Windows

## Summary

Phase 46 is a narrow release-recovery phase, not a toolchain-upgrade phase. The current repo already pins the milestone to Flutter 3.41.1, AGP 8.11.1, Gradle 8.14, and Kotlin 1.9.25. The release baseline is blocked before APK packaging completes, and the verified blocker is not a new product bug in app code. A direct `flutter build apk --release` run from this repo on 2026-03-23 failed in the native-assets step for transitive package `objective_c`, with Windows truncating the command at `C:\Users\HYPE` because both the Flutter SDK path and workspace path contain spaces.

The phase therefore needs to do two things in order:

1. restore one canonical release path that reaches Android packaging again without changing the pinned milestone toolchain unexpectedly
2. make `pubspec.yaml` the visible v7.0 source of truth so the generated Android version metadata and release artifact names match the active milestone

The existing Android build config already follows one useful pattern: `versionCode` and `versionName` flow from Flutter's generated values, and the APK name is changed through the simple `applicationVariants.all { outputs.all { outputFileName = ... } }` path that Android's docs still describe as acceptable for filename changes. The repo drift is in the values, not the high-level mechanism. `pubspec.yaml` is still `6.2.0+8012`, `android/local.properties` mirrors `6.2.0 / 8012`, and the custom APK filename would therefore continue to emit a v6.2 artifact even after the v7.0 milestone was opened.

**Primary recommendation:** split Phase 46 into two sequential plans: first recover the release build path to packaging with the current pinned toolchain and a space-safe native-assets strategy, then update version metadata and derived APK naming so the restored baseline produces unmistakable v7.0 outputs.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BUILD-01 | Operator can run the canonical Android release command from a clean checkout and reach release packaging without the current Dart compile failures. | Verified current blocker comes from release-only build execution, so the first plan must reproduce, remove, and re-verify that packaging path with `flutter build apk --release`. |
| BUILD-03 | Operator can identify the active milestone version from `pubspec.yaml` and generated release artifact names without cross-checking planning docs manually. | Flutter's Android docs state `versionCode` and `versionName` are driven from `pubspec.yaml`, and the repo already customizes `outputFileName`; the second plan should realign those values for v7.0. |
</phase_requirements>

## Current State Analysis

### 1. The verified release blocker is a Windows path/native-assets failure

On 2026-03-23, a direct `flutter build apk --release` run in this repo failed with:

- `Building native assets for package:objective_c failed`
- `'C:\Users\HYPE' is not recognized as an internal or external command`
- failure inside `hook/build.dart` execution for transitive package `objective_c`

This is important because the build got far enough to resolve dependencies and start Gradle, then died when Flutter invoked native-assets tooling. The failure points to command/path handling on Windows, not to a user-facing product regression.

`objective_c` itself is not an Android runtime dependency. Its local package source shows the hook only supports iOS and macOS targets, but Flutter still has to compile the hook entrypoint before that guard can return early. That explains why an iOS/macOS-only transitive package can still break an Android release build on Windows when hook compilation or invocation is path-sensitive.

### 2. The current environment contains space-sensitive paths in two critical places

`android/local.properties` currently points to:

- `flutter.sdk=C:\\Users\\HYPE R Series\\Desktop\\projekan\\absensi apk\\flutter`
- `java.home=C:\\Program Files\\Android\\Android Studio\\jbr`

The Flutter issue tracker already documents that Windows Android builds remain sensitive to path handling when toolchains or projects live under special-character paths, and the observed release log shows the same class of failure with a space-truncated command. For Phase 46 planning purposes, this strongly suggests that the recovery path must either:

- execute Flutter from a space-safe location or alias/junction, or
- remove/avoid the native-assets path that triggers the broken command composition,

while keeping the milestone's pinned toolchain versions intact.

There is also a strong repo-local precedent for this diagnosis: Phase 22's production release summary recorded a successful release build through a space-safe Flutter SDK path (`C:\flutter\bin\flutter.bat`). The current repo-local SDK path moved under `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\flutter`, which reintroduces spaces into the exact toolchain path that native-assets hook compilation now touches.

### 3. The Kotlin warning is advisory, not the active blocker for this phase

The same verified release run emits:

- warning that Flutter support for Kotlin `1.9.25` will soon be dropped

But the build does not stop there. It continues into native-assets execution and fails on the path/truncation issue first. Because the roadmap explicitly says to keep Flutter 3.41.1, AGP 8.11.1, and Gradle 8.14 fixed while closing concrete repo drift first, Kotlin/AGP upgrades belong to the next phase's contract work, not this baseline-recovery phase.

### 4. Version metadata is still on the previous milestone

The repo currently advertises the old milestone in multiple generated places:

- `pubspec.yaml` -> `version: 6.2.0+8012`
- `android/local.properties` -> `flutter.versionName=6.2.0`, `flutter.versionCode=8012`
- `android/app/build.gradle.kts` -> `output.outputFileName = "ABSENKOK-v${variant.versionName}.apk"`

Because Flutter maps Android `versionName` and `versionCode` from `pubspec.yaml`, Phase 46 should treat `pubspec.yaml` as the authoritative v7.0 value and verify that all derived release outputs now reflect it. This is exactly the kind of operator-visible metadata alignment required by `BUILD-03`.

### 5. The repo already has the right output-naming hook, but it should stay simple

Android's known-issues page says modifying variant outputs is still supported for simple tasks like APK filename changes via `applicationVariants.all` and `outputs.all { outputFileName = ... }`, while more complex `outputFile` manipulation is brittle. The current build script already uses the simple filename-only path, which means Phase 46-02 should preserve that simplicity and change values, not introduce more invasive AGP output hacks.

## Standard Stack

### Core

| Library / Tool | Version / State | Purpose | Why Standard |
|----------------|-----------------|---------|--------------|
| Flutter CLI release build | local Flutter 3.41.1 toolchain | Canonical release gate for Android packaging | Directly exercises the real path used by operators. |
| Android Gradle Plugin | 8.11.1 | Android build orchestration | Already pinned in `android/settings.gradle.kts`; roadmap says keep it fixed in this phase. |
| Gradle wrapper | 8.14 | Android build runtime | Already pinned in `android/gradle/wrapper/gradle-wrapper.properties`; same phase guard as AGP. |
| Kotlin Android plugin | 1.9.25 | Current Android/Kotlin baseline | Warning exists, but the build failure is elsewhere and later phases own contract upgrades. |
| `pubspec.yaml` version field | currently `6.2.0+8012` | Source of truth for Flutter build-name/build-number | Official Flutter docs say Android `versionName` and `versionCode` come from here. |

### Supporting

| Tool / Pattern | Purpose | When to Use |
|----------------|---------|-------------|
| `android/local.properties` generated values | Mirror Flutter versionName/versionCode and local SDK paths | Verify the resolved Android metadata after `pubspec.yaml` changes. |
| `applicationVariants.all` + `outputFileName` | Keep the APK filename operator-readable | Safe to keep for simple naming changes only. |
| `flutter pub deps --style=compact` + `pubspec.lock` | Trace transitive packages involved in the native-assets failure | Useful for confirming where `objective_c` enters the graph and whether a dependency override is needed. |
| PowerShell smoke checks | Fast verification of version and naming drift | Good task-level checks before rerunning the full release build. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Fixing the current path/native-assets failure first | Upgrade Kotlin, AGP, or Gradle preemptively | High risk and violates the roadmap guard to keep the current toolchain fixed while closing concrete drift first. |
| `pubspec.yaml` as single source of truth | Hardcode `versionName` / `versionCode` directly in Gradle | Duplicates metadata and makes milestone version drift more likely. |
| Simple `outputFileName` customization | Deeper AGP output-file manipulation or custom rename scripts | Android docs call more complex output mutation brittle; unnecessary for this phase. |
| One end-to-end recovery plan | Separate build-baseline recovery from version-metadata alignment | One plan would overload shared files and make the root-cause fix harder to verify independently. |

## Recommended Architecture

### Pattern 1: Treat the failure as baseline recovery, not feature debugging

The first plan should:

- reproduce the release build failure from the current checkout
- make the smallest repo/environment-safe change that removes the path/native-assets break
- rerun `flutter build apk --release` until the build reaches packaging output

This keeps the phase aligned with `BUILD-01` instead of drifting into unrelated app feature work.

### Pattern 2: Make version metadata flow one-way from `pubspec.yaml`

The second plan should:

- update `pubspec.yaml` to the v7.0 milestone value
- confirm derived Android values (`flutter.versionName`, `flutter.versionCode`) match after a build
- keep the APK filename derived from `variant.versionName`

That gives operators one place to read and one release artifact to recognize.

### Pattern 3: Keep output naming simple and operator-visible

The build script's filename override is already in the simplest supported shape. Phase 46 should keep:

- `versionName` / `versionCode` flowing from Flutter
- `outputFileName` derived from the final version string

and avoid adding post-build rename scripts or more invasive AGP internals.

### Pattern 4: Separate environment-sensitive recovery from toolchain-contract work

Phase 46 should recover a working build path with today's pinned versions. Documenting and hardening the long-term machine contract belongs in Phase 47. That means:

- no opportunistic Kotlin/AGP/Gradle jumps in Phase 46
- no signing overhaul yet
- no new product features mixed into the recovery work

## Do Not Hand-Roll

| Problem | Do Not Build | Use Instead | Why |
|---------|--------------|-------------|-----|
| Release verification | Custom ad hoc shell scripts that never call the real Flutter release command | `flutter build apk --release` as the canonical full gate | BUILD-01 is about the real packaging path, not a synthetic approximation. |
| Version source of truth | Duplicate version literals in Gradle and docs | `pubspec.yaml` plus Flutter-generated Android metadata | Official Flutter docs already wire Android metadata from `pubspec.yaml`. |
| APK renaming | Post-build file moves or manual explorer renames | Existing `outputFileName` customization in Gradle | Simpler, closer to documented AGP behavior, and easier to verify. |
| Toolchain remediation | Broad upgrades to AGP / Kotlin / Gradle during baseline recovery | Minimal change that clears the current blocker with pinned versions | The roadmap explicitly defers contract-level upgrades and guardrails to later work. |
| Native-assets diagnosis | Guessing the failing dependency from app source | `flutter pub deps`, `pubspec.lock`, and the exact build log | The blocker is transitive and build-time, so dependency tracing matters more than app feature inspection. |

## Common Pitfalls

### Pitfall 1: Chasing the Kotlin warning instead of the verified blocker

**What goes wrong:** The phase turns into a risky toolchain migration, but the real release blocker was a Windows path/native-assets problem.

**How to avoid:** Keep Kotlin 1.9.25, AGP 8.11.1, and Gradle 8.14 fixed in Phase 46 unless a direct blocker proves otherwise.

### Pitfall 2: Updating only `pubspec.yaml` without checking generated Android metadata

**What goes wrong:** The source version changes, but the operator still sees stale version strings or artifact names from a previous build.

**How to avoid:** Verify `flutter.versionName`, `flutter.versionCode`, and the release APK filename after the version bump.

### Pitfall 3: Solving the build only on the current machine path accidentally

**What goes wrong:** The release works once on a quirky local path but the plan leaves no stable, repeatable baseline for the next clean checkout.

**How to avoid:** Use a canonical, space-safe release path or dependency-level fix that can be repeated from a clean checkout.

### Pitfall 4: Overloading the phase with signing or distribution changes

**What goes wrong:** Upload-key work and publication mechanics blur the phase boundary and hide whether the baseline itself is fixed.

**How to avoid:** Stop this phase at "release packaging succeeds and v7.0 metadata is correct." Leave signing and publication workflow to later phases.

## Code Examples

### Current repo pattern for Android metadata

```kotlin
defaultConfig {
    versionCode = flutter.versionCode
    versionName = flutter.versionName
}
```

### Current repo pattern for APK filename

```kotlin
applicationVariants.all {
    val variant = this
    variant.outputs.all {
        val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
        output.outputFileName = "ABSENKOK-v${variant.versionName}.apk"
    }
}
```

### Canonical full release verification

```powershell
flutter build apk --release
```

### Fast metadata smoke check

```powershell
Select-String -Path 'pubspec.yaml','android/local.properties','android/app/build.gradle.kts' `
  -Pattern 'version: ','flutter.versionName','flutter.versionCode','outputFileName'
```

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | PowerShell smoke checks plus the real Flutter Android release build |
| Config file | `pubspec.yaml`, `android/local.properties`, `android/app/build.gradle.kts` |
| Quick run command | `powershell -Command "Select-String -Path 'pubspec.yaml','android/local.properties','android/app/build.gradle.kts' -Pattern 'version: ','flutter.versionName','flutter.versionCode','outputFileName' | Measure-Object"` |
| Full suite command | `flutter build apk --release` |
| Estimated runtime | ~120 seconds |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BUILD-01 | Canonical release build reaches Android packaging from the current checkout | full release build | `flutter build apk --release` | Existing |
| BUILD-03 | v7.0 version is visible in `pubspec.yaml`, generated Android metadata, and release artifact naming | metadata smoke + release build | `powershell -Command "Select-String -Path 'pubspec.yaml','android/local.properties','android/app/build.gradle.kts' -Pattern 'version: ','flutter.versionName','flutter.versionCode','outputFileName' | Measure-Object"` | Existing |

### Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The produced APK name is obviously readable to an operator as the active milestone artifact | BUILD-03 | Human judgment is still useful for the final filename format | After the successful release build, open `build/app/outputs/apk/release/` and confirm the generated APK filename clearly exposes the v7.0 version string without cross-checking planning docs. |
| The recovered release path is truly the canonical one the team should keep using | BUILD-01 | Needs an operator sanity check on machine/path assumptions | Re-run the documented release command from a fresh shell in the repo root and confirm there are no hidden prerequisites outside the recorded baseline fix. |

## Sources

### Primary (HIGH confidence)

- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\ROADMAP.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\REQUIREMENTS.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\STATE.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\RETROSPECTIVE.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\pubspec.yaml`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\android\settings.gradle.kts`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\android\gradle\wrapper\gradle-wrapper.properties`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\android\app\build.gradle.kts`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\android\local.properties`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\pubspec.lock`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\22-production-release\22-01-SUMMARY.md`
- `C:\Users\HYPE R Series\AppData\Local\Pub\Cache\hosted\pub.dev\objective_c-9.3.0\hook\build.dart`
- `C:\Users\HYPE R Series\AppData\Local\Pub\Cache\hosted\pub.dev\objective_c-9.3.0\pubspec.yaml`
- `C:\Users\HYPE R Series\AppData\Local\Pub\Cache\hosted\pub.dev\path_provider_foundation-2.6.0\pubspec.yaml`
- direct command evidence: `flutter build apk --release` run in this repo on 2026-03-23
- direct command evidence: `flutter pub deps --style=compact`

### Secondary (MEDIUM confidence)

- Flutter docs: https://docs.flutter.dev/deployment/android
- Android Developers known issues: https://developer.android.com/studio/known-issues
- dart-lang/native repository overview: https://github.com/dart-lang/native
- Flutter issue on Windows path sensitivity: https://github.com/flutter/flutter/issues/149194

## Metadata

**Confidence breakdown:**

- Current blocker: HIGH - reproduced directly with the repo's real release command.
- Version metadata flow: HIGH - confirmed by both local build files and Flutter's Android release docs.
- Recovery strategy choice: MEDIUM - the failure is clear, but the least-invasive permanent fix could be path normalization, dependency pruning, or another native-assets workaround discovered during execution.

**Research date:** 2026-03-23
**Valid until:** 2026-04-22
