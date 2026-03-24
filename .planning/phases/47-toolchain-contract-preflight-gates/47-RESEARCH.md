# Phase 47: Toolchain Contract & Preflight Gates - Research

**Researched:** 2026-03-23
**Domain:** Windows-hosted Flutter Android release contract, fail-fast release preflight, and pinned Kotlin/Gradle compatibility for v7.0
**Confidence:** HIGH for the current repo/toolchain state and command behavior; MEDIUM for the final helper-script shape because the repo does not yet have a tracked release-ops script convention

## Summary

Phase 46 restored the local release lane and aligned the APK naming/version metadata, but the machine contract is still implicit. The repo root now builds successfully through `C:\flutter\bin\flutter.bat`, while the default shell still resolves `java` to Temurin 25.0.1 and Gradle defaults to that JVM unless the shell is explicitly pointed at Android Studio JBR. That is the exact drift the roadmap calls out for Phase 47.

The measured state on 2026-03-23 is:

1. `java -version` from the default shell reports Temurin 25.0.1 LTS.
2. `android\gradlew.bat -version` without `JAVA_HOME` uses launcher/daemon JVM 25.0.1.
3. `android\gradlew.bat -version` with `JAVA_HOME=C:\Program Files\Android\Android Studio\jbr` uses Java 21.0.9 JBR.
4. `flutter analyze` currently fails with 152 issues, including hard errors in `test/screens/admin/admin_login_screen_test.dart` and `test/services/pdf_service_color_test.dart`.
5. `flutter test` runs broadly but ends with 26 failures, including compile failures and known stub tests.
6. `android\gradlew.bat :app:compileReleaseSources` succeeds under Java 21 JBR, runs `compileFlutterBuildRelease` plus release Java/Kotlin compilation, and stops before `packageRelease`, `bundleRelease`, or signing tasks.
7. Flutter prints the Kotlin warning for `1.9.25` and suggests `--android-skip-build-dependency-validation`, but the roadmap explicitly says not to rely on bypass flags or surprise upgrades during v7.0.

That means Phase 47 should not try to "fix everything green." It should instead make the contract explicit, tracked, and reproducible:

- one tracked release-contract document another operator can follow
- one tracked helper that resolves the supported Java runtime instead of trusting PATH
- one tracked preflight command that fails on current analyzer/test debt before signing or full packaging begins
- one explicit compatibility decision for Flutter 3.41.1 + AGP 8.11.1 + Gradle 8.14 + Kotlin 1.9.25 + Java 21 JBR, including a ban on `--android-skip-build-dependency-validation` for v7.0

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BUILD-02 | Operator can run one preflight release check that fails before signing when analysis, tests, or release-only compile steps are broken. | Measured `flutter analyze` and `flutter test` are red today, while `:app:compileReleaseSources` is a release-only compile gate that stops before signing/package tasks. |
| TOOL-01 | Operator can build with an explicitly documented Java runtime for Gradle instead of relying on whichever `java` is first on PATH. | Measured PATH Java is Temurin 25.0.1 while JBR Java 21 is the intended runtime; a tracked helper/doc must close that drift. |
| TOOL-02 | Operator can follow a pinned Flutter/Kotlin/Gradle compatibility decision for v7.0 without using ad hoc bypass flags or surprise upgrades. | The repo already pins Flutter 3.41.1, AGP 8.11.1, Gradle 8.14, and Kotlin 1.9.25. Flutter warns about future Kotlin support, so the project needs an explicit "hold this line in v7.0" decision. |
</phase_requirements>

## Current State Analysis

### 1. Java runtime drift is real and currently visible from the command line

Default-shell evidence:

- `java -version` -> `openjdk version "25.0.1" 2025-10-21 LTS`
- `where java` -> `C:\Program Files\Eclipse Adoptium\jdk-25.0.1.8-hotspot\bin\java.exe`
- no `JAVA_HOME` environment variable is currently set in the shell session

Gradle evidence:

- `android\gradlew.bat -version` without `JAVA_HOME` uses `Launcher JVM: 25.0.1` and `Daemon JVM: ... jdk-25.0.1.8-hotspot`
- the same command with `JAVA_HOME=C:\Program Files\Android\Android Studio\jbr` uses `Launcher JVM: 21.0.9` and `Daemon JVM: ... Android Studio\jbr`

This is the strongest signal for TOOL-01. The intended release runtime exists, but the default CLI session does not select it automatically.

### 2. `android/local.properties` cannot be the tracked contract

Current `android/local.properties` contains:

```properties
sdk.dir=C:\\Users\\HYPE R Series\\AppData\\Local\\Android\\Sdk
java.home=C:\\Program Files\\Android\\Android Studio\\jbr
flutter.sdk=C:\\flutter
flutter.buildMode=release
flutter.versionName=7.0.0
flutter.versionCode=8013
```

That file is machine-local and gitignored by repo design. Phase 46 used it successfully as local execution evidence, but Phase 47 needs a tracked contract that survives a clean checkout on another Windows machine. The contract therefore has to live in tracked docs and helper scripts, not only in `local.properties`.

### 3. The project already has the pinned Android baseline Phase 47 should document, not upgrade

Tracked pins today:

- Flutter `3.41.1`
- Dart `3.11.0`
- AGP `8.11.1` in `android/settings.gradle.kts`
- Gradle `8.14` in `android/gradle/wrapper/gradle-wrapper.properties`
- Kotlin plugin `1.9.25` in `android/settings.gradle.kts`
- app-level Java/Kotlin bytecode target `17` in `android/app/build.gradle.kts`
- intended Gradle runtime `Java 21` via Android Studio JBR

Phase 47 should document that split clearly: runtime JDK 21 for Gradle, while Android source/target compatibility stays at Java 17 in the app module.

### 4. Analyzer and test debt is already sufficient to prove the need for a fail-fast preflight lane

Measured command results:

- `flutter analyze` exits non-zero with 152 issues
- hard errors include:
  - missing `canUseBiometricLogin` in `test/screens/admin/admin_login_screen_test.dart`
  - named-parameter drift in `test/services/pdf_service_color_test.dart`
- `flutter test` exits non-zero after 206 test executions with 26 failures
- failures include:
  - the same `canUseBiometricLogin` compile break
  - `AttendanceDailyPdfStats`/`AttendanceDailyPdfEmployeeRow` API drift
  - wave-0 stub failures in chart/streak-related tests

This is important because BUILD-02 does not require the lane to be green in Phase 47. It requires one command that exposes red checks before signing or expensive packaging begins. The repo already provides real red inputs for that proof.

### 5. `:app:compileReleaseSources` is the right release-only compile gate for this phase

Measured task graph evidence from `android\gradlew.bat :app:tasks --all`:

- available tasks include `compileFlutterBuildRelease`, `compileReleaseKotlin`, `compileReleaseJavaWithJavac`, `compileReleaseSources`, `packageRelease`, `bundleRelease`, and `signReleaseBundle`

Measured execution evidence:

- `android\gradlew.bat :app:compileFlutterBuildRelease` succeeds in ~100s under JBR and does not sign/package
- `android\gradlew.bat :app:compileReleaseSources` succeeds in ~42s after warm-up under JBR
- `compileReleaseSources` runs `compileFlutterBuildRelease`, `compileReleaseKotlin`, and `compileReleaseJavaWithJavac`
- it does **not** run `packageRelease`, `bundleRelease`, `packageReleaseBundle`, or `signReleaseBundle`

That makes `compileReleaseSources` the best single release-only gate for BUILD-02: it is more specific than `flutter analyze`, cheaper than full packaging, and still exercises release-only compile paths.

### 6. The Kotlin warning should be converted into an explicit v7.0 decision, not a surprise migration

Current `android/settings.gradle.kts` already contains:

```kotlin
id("org.jetbrains.kotlin.android") version "1.9.25" apply false
```

and a local comment noting `nfc_manager` incompatibility with Kotlin 2.x. The build and Gradle task listings also print:

- Flutter support for Kotlin `1.9.25` will soon be dropped
- suggestion to use `--android-skip-build-dependency-validation`

The roadmap explicitly says operators should not rely on bypass flags or surprise upgrades. Phase 47 therefore needs a tracked decision that says:

- v7.0 intentionally stays on Kotlin 1.9.25
- the reason is release-hardening scope plus `nfc_manager` compatibility risk
- `--android-skip-build-dependency-validation` is not allowed in the canonical v7.0 release lane
- any Kotlin/AGP/Gradle upgrade is a later spike, not an operator choice during release prep

## Standard Stack

### Core

| Library / Tool | Version / State | Purpose | Why Standard |
|----------------|-----------------|---------|--------------|
| Flutter SDK | 3.41.1 via `C:\flutter\bin\flutter.bat` | Canonical release CLI | Phase 46 already restored this as the working local baseline. |
| Gradle runtime JDK | Java 21 JBR (`C:\Program Files\Android\Android Studio\jbr`) | Supported Gradle JVM | Matches the milestone decision already recorded in planning state. |
| Android Gradle Plugin | 8.11.1 | Android build orchestration | Tracked in repo; Phase 47 documents rather than upgrades it. |
| Gradle wrapper | 8.14 | Build runner | Tracked in repo; warning-free baseline for current milestone scope. |
| Kotlin Android plugin | 1.9.25 | Current Android plugin compatibility line | Known Flutter warning, but intentionally held for v7.0. |
| Release compile gate | `android\gradlew.bat :app:compileReleaseSources` | Release-only compile preflight | Catches release-only compilation without signing/package work. |

### Supporting

| Tool / Pattern | Purpose | When to Use |
|----------------|---------|-------------|
| PowerShell env helper | Resolve/export JBR 21 and canonical Flutter path | Before any Gradle or Flutter release commands on Windows |
| Tracked release contract doc | Make toolchain/runtime decisions visible from a clean checkout | First stop for another operator preparing a build |
| `flutter analyze` | Surface repo-wide static breakage | First preflight stage |
| `flutter test` | Surface compile/test regressions | Second preflight stage |
| `README.md` link or release section | Discoverability for operators entering at the repo root | Needed because this repo mixes Flutter and Astro codebases |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| PowerShell helper that resolves Java 21 explicitly | Track `org.gradle.java.home` as an absolute path in `android/gradle.properties` | Too machine-specific for a shared repo; brittle if Android Studio is installed elsewhere. |
| `:app:compileReleaseSources` | `assembleRelease` or `bundleRelease` as the preflight lane | Too late in the pipeline; package/sign work has already begun. |
| Pinned v7.0 compatibility decision | Immediate Kotlin/AGP upgrade | Violates the roadmap guard and expands risk during release hardening. |
| Explicitly banning bypass flags | Rely on `--android-skip-build-dependency-validation` when warnings appear | Hides the decision instead of recording it; encourages unsupported operator behavior. |
| README + dedicated release doc | Leave the knowledge in `.planning/STATE.md` only | Planning docs are not the operator-facing contract for a clean checkout. |

## Recommended Architecture

### Pattern 1: Introduce one tracked operator-facing release contract

Add a tracked doc such as `docs/android-release-contract.md` and link it from `README.md`.

That document should capture:

- canonical release command: `C:\flutter\bin\flutter.bat build apk --release`
- supported Gradle JVM: Android Studio JBR Java 21
- pinned v7.0 baseline: Flutter 3.41.1, AGP 8.11.1, Gradle 8.14, Kotlin 1.9.25
- note that `android/local.properties` is machine-local and not the source of truth
- one preflight command operators run before any signed packaging

### Pattern 2: Add a fail-fast PowerShell runtime helper

Create `tool/release_env.ps1` (or equivalent) that:

1. resolves the supported JBR path from:
   - `ABSENKOK_JAVA_HOME` if provided
   - otherwise the standard Android Studio JBR path
2. validates that the resolved runtime is Java 21, not whatever `java.exe` happens to be first on PATH
3. exports `JAVA_HOME` and prepends `$JAVA_HOME\bin` for the current process
4. verifies `C:\flutter\bin\flutter.bat` exists
5. prints a short contract summary or exits non-zero with a clear remediation message

This is the cleanest way to satisfy TOOL-01 without force-tracking host-specific files.

### Pattern 3: Add one release preflight lane that cannot drift into signing

Create `tool/release_preflight.ps1` that shells through the env helper, then runs exactly:

1. `C:\flutter\bin\flutter.bat analyze`
2. `C:\flutter\bin\flutter.bat test`
3. `android\gradlew.bat :app:compileReleaseSources`

Required behavior:

- fail immediately on the first non-zero stage
- print stage boundaries so the operator knows what failed
- never call `assembleRelease`, `bundleRelease`, `packageRelease`, or signing tasks

This turns the repo's existing analyzer/test debt into a useful proof that the gate fails before expensive packaging.

### Pattern 4: Record and enforce the Kotlin compatibility decision instead of hiding it

Phase 47 should move the Kotlin note from a local comment into tracked operator guidance and a script-level guard.

Recommended contract:

- v7.0 supports Kotlin 1.9.25 only
- no `--android-skip-build-dependency-validation` in canonical commands
- no Kotlin 2.x migration during release hardening
- if someone intentionally changes the Kotlin plugin version later, they must also update the tracked release contract

The cheapest enforcement is a preflight/doc check that greps `android/settings.gradle.kts` for `1.9.25` and errors if a bypass flag is introduced into the script or docs.

## Do Not Hand-Roll

| Problem | Do Not Build | Use Instead | Why |
|---------|--------------|-------------|-----|
| Java runtime selection | Ask operators to manually remember to switch shells | Tracked `tool/release_env.ps1` helper | Removes tribal knowledge and makes PATH drift observable. |
| Release-only validation | Full `build apk --release` as the first gate | `flutter analyze` + `flutter test` + `:app:compileReleaseSources` | BUILD-02 requires earlier failure than signing/package steps. |
| Kotlin warning handling | `--android-skip-build-dependency-validation` | Explicit v7.0 compatibility doc and guard | Bypass flags hide the real decision and weaken reproducibility. |
| Contract source of truth | `android/local.properties` only | Tracked doc + tracked helper scripts | `local.properties` is local evidence, not a repo contract. |
| Toolchain change detection | Silent version drift in settings/wrapper files | Script/doc assertions on pinned versions | Operators should see drift immediately, not during a late release failure. |

## Common Pitfalls

### Pitfall 1: Assuming `java.home` in `local.properties` protects CLI Gradle runs

**What goes wrong:** A shell still launches `gradlew.bat` on Temurin 25 because the operator never exported JBR 21.

**How to avoid:** Always enter the release lane through a tracked PowerShell helper that sets `JAVA_HOME` explicitly.

### Pitfall 2: Using full packaging as a preflight check

**What goes wrong:** The team spends time on packaging/signing just to rediscover analyzer or test failures that could have been caught earlier.

**How to avoid:** Stop the preflight lane at `:app:compileReleaseSources`.

### Pitfall 3: Treating the Flutter Kotlin warning as permission to upgrade on the spot

**What goes wrong:** An operator changes Kotlin or AGP locally, which risks `nfc_manager` and breaks the reproducible v7.0 lane.

**How to avoid:** Record the v7.0 compatibility decision in tracked files and reject bypass flags in the preflight script.

### Pitfall 4: Calling the contract "documented" without making it discoverable

**What goes wrong:** The release instructions exist only in planning artifacts, not where another operator would look from a clean checkout.

**How to avoid:** Link the dedicated release doc from `README.md`.

## Code Examples

### Default shell Java drift

```powershell
java -version
where java
```

### Supported Gradle JVM check

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
Set-Location android
.\gradlew.bat -version
```

### Release-only compile gate

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
Set-Location android
.\gradlew.bat :app:compileReleaseSources
```

### Current Kotlin plugin pin

```kotlin
id("org.jetbrains.kotlin.android") version "1.9.25" apply false
```

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | PowerShell helper scripts + Flutter CLI + Gradle release compile task |
| Config file | `docs/android-release-contract.md`, `tool/release_env.ps1`, `tool/release_preflight.ps1`, `android/settings.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties` |
| Quick run command | `powershell -ExecutionPolicy Bypass -File tool/release_env.ps1 -CheckOnly` |
| Full suite command | `powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1` |
| Estimated runtime | ~6 minutes with current analyzer/test load |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TOOL-01 | Helper resolves the supported Java 21 runtime and rejects PATH-only drift | env contract check | `powershell -ExecutionPolicy Bypass -File tool/release_env.ps1 -CheckOnly` | Planned |
| BUILD-02 | One command runs analyze, test, and release-only compile, failing before package/sign steps | preflight lane | `powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1` | Planned |
| TOOL-02 | Pinned Kotlin/Gradle/Flutter decision is visible and the bypass flag is forbidden | contract grep + preflight guard | `powershell -Command "Select-String -Path 'docs/android-release-contract.md','android/settings.gradle.kts','tool/release_preflight.ps1' -Pattern '1\\.9\\.25','8\\.11\\.1','8\\.14','3\\.41\\.1','android-skip-build-dependency-validation'"` | Planned |

### Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| A second operator can find the toolchain contract from the repo root without opening planning files | TOOL-01, TOOL-02 | Discoverability is partly a documentation judgment | Open `README.md` from a clean checkout and confirm it points to the release contract doc and preflight command. |
| Preflight clearly stops before packaging/signing | BUILD-02 | Operators should verify the lane semantics, not just exit codes | Read the script and confirm it never calls `assembleRelease`, `bundleRelease`, `packageRelease`, or signing tasks. |

## Sources

### Primary (HIGH confidence)

- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\ROADMAP.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\REQUIREMENTS.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\STATE.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\46-release-baseline-recovery\46-RESEARCH.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\46-release-baseline-recovery\46-01-SUMMARY.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\46-release-baseline-recovery\46-02-SUMMARY.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\README.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\pubspec.yaml`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\android\local.properties`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\android\settings.gradle.kts`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\android\app\build.gradle.kts`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\android\gradle\wrapper\gradle-wrapper.properties`
- direct command evidence on 2026-03-23:
  - `java -version`
  - `where java`
  - `C:\flutter\bin\flutter.bat --version`
  - `C:\flutter\bin\flutter.bat analyze`
  - `C:\flutter\bin\flutter.bat test`
  - `android\gradlew.bat -version` with and without `JAVA_HOME`
  - `android\gradlew.bat :app:tasks --all`
  - `android\gradlew.bat :app:compileFlutterBuildRelease`
  - `android\gradlew.bat :app:compileReleaseSources`

### Secondary (MEDIUM confidence)

- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\phase46_build.log`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\phase46_analyze.log`

## Metadata

**Confidence breakdown:**

- Java drift diagnosis: HIGH - measured directly from the current shell and Gradle wrapper.
- Preflight gate choice (`compileReleaseSources`): HIGH - measured task graph and execution show it covers release compile work without sign/package steps.
- Compatibility-decision enforcement shape: MEDIUM - the repo lacks an existing tracked release-scripting convention, so the exact helper-script interface is still a design choice for planning.

**Research date:** 2026-03-23
**Valid until:** 2026-04-22
