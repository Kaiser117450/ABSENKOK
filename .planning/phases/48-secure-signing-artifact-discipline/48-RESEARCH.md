# Phase 48: Secure Signing & Artifact Discipline - Research

**Researched:** 2026-03-23
**Domain:** Flutter Android upload-key signing, canonical release artifact staging, split debug info retention, and smoke verification for v7.0
**Confidence:** HIGH for the current repo/build state and current Flutter CLI semantics; MEDIUM for the final smoke-verification ergonomics because they depend on an attached Android target

## Summary

Phase 47 made the toolchain contract explicit, but the repo still cannot cut a signed Android release safely. `android/app/build.gradle.kts` still signs `release` with the debug config, there is no `android/key.properties` scaffold or privacy guard in git, and `tool/release_preflight.ps1` intentionally stops before packaging or signing. Phase 48 therefore needs a downstream release lane, not a wider preflight lane.

The strongest repo-specific conclusions are:

1. Replace the current debug-signing fallback with a fail-fast upload-key configuration loaded from a private `android/key.properties`.
2. Keep all secret material out of git by tracking only an example/template plus ignore rules for the real `key.properties` and keystore files.
3. Add one release entrypoint that always runs `tool/release_preflight.ps1` first, then builds a canonical `.aab`, and only retains a release `.apk` when the operator explicitly needs side-loading or smoke-install support.
4. Stage the final artifact set into a versioned release directory with a manifest instead of relying on AGP internal output names and folders.
5. Retain release symbols with `--split-debug-info` without forcing Dart obfuscation, and capture a smoke-verification result next to the signed artifacts before distribution.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REL-01 | Operator can produce a release artifact signed with the private upload keystore instead of the debug keystore. | The repo still signs `release` with `signingConfigs.getByName("debug")`, and Flutter's current Android release guidance still uses `android/key.properties` plus a dedicated `release` signing config. |
| REL-02 | Operator can produce the agreed release artifact set from one validated release lane: canonical `.aab`, plus release `.apk` only if outlet side-loading still requires it. | Phase 47 already created the preflight gate; Phase 48 needs a packaging lane that shells through that gate, builds `.aab` every time, and retains `.apk` only on an explicit path. |
| REL-03 | Operator can retain the matching split debug info or symbol artifacts for each signed release and verify the shrunken release build before distribution. | The installed Flutter CLI supports `--split-debug-info=<dir>` on release `appbundle` and `apk` builds without requiring `--obfuscate`, and Android release shrinking already produces `mapping.txt` when R8 minification is enabled. |
</phase_requirements>

## Current State Analysis

### 1. The repo still signs `release` with the debug key

Current `android/app/build.gradle.kts` contains:

```kotlin
buildTypes {
    release {
        // Signing with debug keys for now
        signingConfig = signingConfigs.getByName("debug")
        isMinifyEnabled = true
        isShrinkResources = true
    }
}
```

That is the exact gap called out in the roadmap. REL-01 cannot be satisfied until the release build stops depending on the debug keystore entirely.

### 2. There is no tracked private-signing scaffold yet

Measured repo state on 2026-03-23:

- `android/key.properties` does not exist
- `android/key.properties.example` does not exist
- `android/upload-keystore.jks` does not exist
- `.gitignore` already ignores `app.*.symbols` and `app.*.map.json`
- `.gitignore` does not yet ignore `android/key.properties` or common keystore file patterns

That means Phase 48 needs both sides of the privacy contract:

- tracked repo guidance for the expected `key.properties` shape
- tracked ignore rules so the real keystore material does not leak into git

### 3. Preflight already exists and should stay separate from packaging

`tool/release_preflight.ps1` currently:

1. enters through `tool/release_env.ps1`
2. runs `flutter analyze`
3. runs `flutter test`
4. runs `android\gradlew.bat :app:compileReleaseSources`

It explicitly does not call `assembleRelease`, `bundleRelease`, `packageRelease`, or signing tasks. That is correct for Phase 47 and should remain correct for Phase 48. The release packaging lane should call preflight first, not absorb preflight into the packaging script.

### 4. Artifact naming is only partially formalized today

Current `android/app/build.gradle.kts` renames APK outputs to:

```kotlin
output.outputFileName = "ABSENKOK-v${variant.versionName}.apk"
```

That helps with APK discoverability, but it still leaves real gaps:

- there is no equivalent staging rule for the `.aab`
- the build number is not linked to the final retained artifact name
- there is no manifest tying together build version, git revision, artifacts, and symbol files
- artifact retention currently depends on knowing AGP's transient output directories

For Phase 48, the safest pattern is to copy outputs into a versioned release directory after the build, rather than fighting AGP internals to rename the `.aab` in place.

### 5. The installed Flutter CLI supports split debug info without forcing obfuscation

Local command evidence from `C:\flutter\bin\flutter.bat build appbundle -h` on 2026-03-23:

- `--split-debug-info=<dir>` stores Dart program symbols in a separate host directory for later symbolization
- `--obfuscate` must be combined with `--split-debug-info`

This matters because REL-03 does not require obfuscation. The repo can retain Dart symbol files with `--split-debug-info` while avoiding the higher behavioral risk of obfuscating identifiers during the same milestone.

### 6. Existing shrink settings already imply symbol retention should include R8 output

The current release build enables:

- `isMinifyEnabled = true`
- `isShrinkResources = true`

That means the release lane is already a shrunken build. Phase 48 should therefore retain:

- Dart symbol files from `--split-debug-info`
- Android shrinker output such as `build/app/outputs/mapping/release/mapping.txt` when present

Those files should live next to the staged signed artifacts so each retained release version has matching debugging material.

### 7. Smoke verification is easiest with a signed release APK, even if the final distributed artifact is the `.aab`

The roadmap makes `.aab` the canonical release artifact and keeps `.apk` optional for outlet side-loading only. However, smoke verification still needs an installable artifact for a connected device or emulator. The least risky design is:

- always build the `.aab`
- optionally build a signed release `.apk`
- if the `.apk` is only needed for smoke verification, mark it as transient or smoke-only in the release manifest and omit it from the final retained artifact set when operations do not need side-loading

That preserves the `.aab` as the canonical deliverable while keeping smoke verification practical on local hardware.

## Standard Stack

### Core

| Library / Tool | Version / State | Purpose | Why Standard |
|----------------|-----------------|---------|--------------|
| `android/key.properties` | private, machine-local | release signing input | Matches current Flutter Android signing guidance and keeps secrets out of tracked code. |
| upload keystore (`.jks` / `.keystore`) | private, operator-managed | upload-key material | Required to stop relying on debug signing for `release`. |
| `tool/release_build.ps1` | planned | single packaging entrypoint | Keeps artifact staging, manifest creation, and optional APK retention in one place. |
| `tool/release_preflight.ps1` | existing from Phase 47 | validated gate before packaging | Prevents packaging/signing work from starting on a red repo. |
| `flutter build appbundle --release --split-debug-info=<dir>` | available in installed Flutter CLI | canonical signed `.aab` plus Dart symbol output | Satisfies the `.aab` side of REL-02 and the symbol-retention side of REL-03. |
| `flutter build apk --release --split-debug-info=<dir>` | available in installed Flutter CLI | installable smoke or side-load artifact | Keeps smoke verification practical and lets APK retention stay opt-in. |
| `adb` | environment dependency | install/launch smoke verification | Simplest local proof that the shrunken signed release still starts on Android hardware. |

### Supporting

| Tool / Pattern | Purpose | When to Use |
|----------------|---------|-------------|
| `android/key.properties.example` | tracked placeholder schema for signing inputs | Commit this instead of any real secret file. |
| `.gitignore` rules for `android/key.properties` and keystores | privacy boundary | Add before wiring release signing so secrets do not leak during testing. |
| `build/releases/android/ABSENKOK-v<name>+<code>/` | staged release bundle directory | Use as the canonical retained location for artifacts, symbols, and smoke evidence. |
| `release-manifest.json` or equivalent | ties version to artifact/symbol retention | Write after each successful build. |
| `build/app/outputs/mapping/release/mapping.txt` | Android shrinker mapping | Copy into the staged release directory when it exists. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Private `android/key.properties` plus example file | Hardcode keystore paths/passwords in tracked Gradle or scripts | Breaks the privacy boundary immediately and makes the repo unsafe. |
| Separate packaging lane after preflight | Expand `tool/release_preflight.ps1` to also package/sign | Blurs two different guarantees and makes the fail-fast lane harder to reason about. |
| Staging copied artifacts into a versioned directory | Depend on AGP's default `app-release.aab` and nested output folders | Output discovery remains brittle and version linkage stays implicit. |
| `--split-debug-info` without obfuscation | Force `--obfuscate` during the same milestone | Raises runtime and stack-trace behavior risk without a roadmap requirement to do so. |
| Optional APK retention | Always retain and distribute the APK | Weakens the "AAB is canonical" rule and keeps legacy side-load behavior alive by default. |

## Recommended Architecture

### Pattern 1: Add a repo-safe private signing scaffold first

Phase 48 should start by making the signing contract explicit and safe:

- add `.gitignore` entries for `android/key.properties` and common keystore file names
- add `android/key.properties.example` with placeholder keys only
- update `android/app/build.gradle.kts` to load `key.properties`
- create a dedicated `release` signing config
- remove the `signingConfigs.getByName("debug")` fallback from `buildTypes.release`
- fail with a clear Gradle error if a release build is requested without private signing inputs

This keeps REL-01 focused on wiring and safety, not on writing a full operator runbook.

### Pattern 2: Keep preflight and packaging as two linked entrypoints

The recommended Phase 48 flow is:

1. `tool/release_env.ps1`
2. `tool/release_preflight.ps1`
3. `tool/release_build.ps1`

`tool/release_build.ps1` should never skip the Phase 47 preflight on a real build. It may offer a `-CheckOnly` mode for repo-structure validation, but the real packaging path must remain "preflight first, package second."

### Pattern 3: Stage outputs into one versioned release directory

Recommended target shape:

```text
build/releases/android/ABSENKOK-v7.0.0+8013/
  ABSENKOK-v7.0.0+8013.aab
  ABSENKOK-v7.0.0+8013.apk          # only when retained for side-load distribution
  symbols/
    app.android-arm64.symbols
    ...
  mapping.txt
  release-manifest.json
  smoke-check.txt
```

The exact folder name can vary, but the design should:

- include version name and build number
- group artifacts and debugging material under one retained root
- write a manifest stating whether the APK is distributed, smoke-only, or omitted

### Pattern 4: Use `--split-debug-info` by default, not `--obfuscate`

For v7.0, the least risky REL-03 path is:

- pass `--split-debug-info=<releaseDir>/symbols` on release builds
- do not enable `--obfuscate` unless the team explicitly chooses to widen scope later
- copy `mapping.txt` into the same release directory when present

This preserves debugging material for the shrunken release without adding a new obfuscation variable to a release-hardening milestone.

### Pattern 5: Record smoke verification as release evidence, not tribal knowledge

The release lane should support a smoke-verification mode that:

1. checks `adb devices`
2. installs the signed release APK on an attached device or emulator
3. launches the app package
4. records device serial, timestamp, command results, and artifact version in a `smoke-check.txt`

If no Android target is attached, the lane should fail clearly instead of silently skipping smoke verification. The roadmap makes smoke verification part of the distribution gate, not an optional courtesy step.

## Do Not Hand-Roll

| Problem | Do Not Build | Use Instead | Why |
|---------|--------------|-------------|-----|
| Release signing | Keep `release` on debug signing "for now" | dedicated upload-key config loaded from `android/key.properties` | REL-01 is specifically about removing the debug-key dependency. |
| Secret handling | Commit `key.properties` or keystore files | example file plus `.gitignore` rules | Keeps operator secrets private and the repo shareable. |
| Artifact policy | Let every operator pull files out of `build/app/outputs/...` manually | staged release directory plus manifest | Removes guesswork and makes retention/version linkage explicit. |
| Symbol retention | Assume R8 mapping alone is enough | retain both `mapping.txt` and Flutter `--split-debug-info` outputs | Covers Dart stack traces as well as Android shrinker mappings. |
| Smoke verification | Treat packaging success as runtime proof | install/launch the signed release APK and record result | A shrunken signed build can still fail at startup or immediate boot. |

## Common Pitfalls

### Pitfall 1: Leaving the debug-signing fallback in `build.gradle.kts`

**What goes wrong:** The repo appears to support upload-key signing, but `release` quietly still works with the debug keystore.

**How to avoid:** Add a static verification that fails if `signingConfigs.getByName("debug")` still appears inside the `release` build type.

### Pitfall 2: Adding `key.properties.example` without ignoring the real `key.properties`

**What goes wrong:** An operator creates the private file locally and accidentally stages it in git.

**How to avoid:** Land the `.gitignore` rule in the same plan that introduces the example file.

### Pitfall 3: Using preflight as the packaging script

**What goes wrong:** The purpose of the fail-fast lane becomes unclear, and later changes may accidentally let packaging run after a failed check.

**How to avoid:** Keep `tool/release_preflight.ps1` narrow and make `tool/release_build.ps1` depend on it.

### Pitfall 4: Making the APK implicitly permanent again

**What goes wrong:** The repo says `.aab` is canonical, but operators keep distributing APKs by default because the script always retains one.

**How to avoid:** Gate final APK retention behind an explicit switch and record the choice in the manifest.

### Pitfall 5: Retaining symbols in ad hoc folders

**What goes wrong:** The team has symbol files somewhere under `build/`, but cannot match them to the shipped artifact later.

**How to avoid:** Write symbols directly into the versioned release directory and include their paths in the manifest.

### Pitfall 6: Silently skipping smoke verification when no device is attached

**What goes wrong:** Distribution proceeds with no real runtime evidence.

**How to avoid:** Make the smoke mode fail clearly when no `adb` target is available and require the resulting smoke-evidence file before distribution.

## Code Examples

### Current debug-signing gap

```kotlin
release {
    signingConfig = signingConfigs.getByName("debug")
    isMinifyEnabled = true
    isShrinkResources = true
}
```

### Recommended canonical build commands

```powershell
C:\flutter\bin\flutter.bat build appbundle --release --split-debug-info=build/releases/android/ABSENKOK-v7.0.0+8013/symbols
```

```powershell
C:\flutter\bin\flutter.bat build apk --release --split-debug-info=build/releases/android/ABSENKOK-v7.0.0+8013/symbols
```

### Smoke install example

```powershell
adb install -r build/releases/android/ABSENKOK-v7.0.0+8013/ABSENKOK-v7.0.0+8013.apk
```

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | PowerShell release helpers plus Flutter CLI, Gradle shrink outputs, and `adb` smoke install/launch checks |
| Config file | `android/app/build.gradle.kts`, `.gitignore`, `android/key.properties.example`, `tool/release_build.ps1`, `tool/release_preflight.ps1`, `docs/android-release-contract.md` |
| Quick run command | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly` |
| Full suite command | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -IncludeSideLoadApk -SmokeVerify` |
| Estimated runtime | ~12 minutes on a green lane plus device install time |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REL-01 | Release signing loads private upload-key inputs and no longer allows debug-signing fallback | static signing contract | `powershell -Command "$content = Get-Content 'android/app/build.gradle.kts' -Raw; if ($content -match 'signingConfigs\\.getByName\\(\"debug\"\\)') { throw 'release still uses debug signing' }"` | Planned |
| REL-02 | One release entrypoint stages a canonical `.aab` and optional retained `.apk` after preflight passes | release lane structure | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly` | Planned |
| REL-03 | Each signed release retains symbol artifacts and records smoke verification before distribution | symbol + smoke lane | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly -IncludeSideLoadApk -SmokeVerify` | Planned |

### Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The private upload keystore is stored outside the repo and backed up appropriately | REL-01 | Secret-storage policy cannot be proven from tracked code alone | Confirm the real `key.properties` and keystore are local-only and not staged in git before cutting a release. |
| The signed shrunken release reaches the first usable screen on representative Android hardware | REL-03 | Runtime smoke evidence needs a real device or emulator target | Run the smoke mode against an attached device or emulator, confirm install + launch success, and retain the generated smoke-evidence file next to the release artifacts. |
| If the final release omits an APK, the manifest clearly marks any locally built APK as smoke-only rather than distributed | REL-02, REL-03 | This is a release-policy judgment rather than a syntax check | Inspect the staged release directory and verify the manifest matches the actual distribution decision. |

## Sources

### Primary (HIGH confidence)

- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\ROADMAP.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\REQUIREMENTS.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\STATE.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\47-toolchain-contract-preflight-gates\47-RESEARCH.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\47-toolchain-contract-preflight-gates\47-01-PLAN.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\47-toolchain-contract-preflight-gates\47-02-PLAN.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\android\app\build.gradle.kts`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\docs\android-release-contract.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\tool\release_env.ps1`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\tool\release_preflight.ps1`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.gitignore`
- direct local command evidence on 2026-03-23:
  - `C:\flutter\bin\flutter.bat build appbundle -h`
  - `Test-Path android/key.properties`
  - `Test-Path android/key.properties.example`
  - `Test-Path android/upload-keystore.jks`

### External primary docs (HIGH confidence)

- Flutter Android release guide: `https://docs.flutter.dev/deployment/android`
- Flutter obfuscation and symbolization guide: `https://docs.flutter.dev/deployment/obfuscate`

## Metadata

**Confidence breakdown:**

- release-signing gap diagnosis: HIGH - directly measured from tracked Gradle config and missing local files
- artifact-staging recommendation: HIGH - current repo only formalizes APK naming, not final release retention
- split-debug-info recommendation without obfuscation: HIGH - confirmed by the installed Flutter CLI help text
- smoke-verification ergonomics: MEDIUM - the exact operator UX depends on available devices/emulators at execution time

**Research date:** 2026-03-23
**Valid until:** 2026-04-22
