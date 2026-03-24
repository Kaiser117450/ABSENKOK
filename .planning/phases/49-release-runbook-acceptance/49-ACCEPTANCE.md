---
phase: 49-release-runbook-acceptance
plan: 02
requirement: OPS-01
status: passed
result: obfuscated-smoke-verified-release
executed_at: 2026-03-25T00:50:52+08:00
release_label: ABSENKOK-v7.0.0+8013
---

# Phase 49 Acceptance Record

## Outcome

The tracked local runbook now passes end to end on this machine through environment verification, preflight, packaging, obfuscation, and smoke verification. The final release lane installed and launched the canonical retained APK on device `V8X8ROMVSWVKIVW8` without using bypass flags, then the staged artifact was uploaded to GitHub Release `v7.0.0`.

No bypass flags were used. `tool/release_preflight.ps1` completed successfully, `tool/release_build.ps1 -SmokeVerify -Obfuscate` produced the staged release directory and manifest, `smoke-check.txt` records successful install and launch evidence for the same retained APK, and the published GitHub asset matches the staged SHA-256 digest.

## Bootstrap Checkpoint

- Local `android/key.properties` exists and remained untracked during the run.
- The keystore path referenced by `storeFile` exists locally.
- `adb devices -l` reported device `V8X8ROMVSWVKIVW8` in `device` state before the acceptance run.
- The scripted smoke gate used that device for both `adb install -r` and `adb shell monkey` launch verification.

## Command Surface Executed

1. `powershell -ExecutionPolicy Bypass -File tool/release_env.ps1 -CheckOnly`
   - Passed.
   - Confirmed Java 21 JBR, Flutter 3.41.1, AGP 8.11.1, Gradle 8.14, and Kotlin 1.9.25.
2. `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly -SmokeVerify`
   - Passed.
   - Confirmed release label `ABSENKOK-v7.0.0+8013`, canonical APK target, app package `com.enakko.absensi_enakko_flutter`, resolved `adb.exe`, and default `Bundle retention: omitted`.
3. `powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1`
   - Passed.
   - Exit code: `0`
   - Notes:
     - `flutter analyze` completed with non-fatal warning/info debt (`129 issues found`).
     - `flutter test --no-test-assets` passed after replacing stale Wave 0 stubs and removing the remaining test-only shader dependency.
     - `android\gradlew.bat :app:compileReleaseSources` passed once the script was corrected to run from the `android` directory.
4. `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -SmokeVerify -Obfuscate`
   - Built the canonical retained APK and staged release evidence under `build/releases/android/ABSENKOK-v7.0.0+8013/`.
   - Exit status: `0`
   - Smoke result: `passed`
   - `adb devices` output during the scripted smoke gate:
     - `List of devices attached`
     - `V8X8ROMVSWVKIVW8    device`
   - `adb install -r` output:
     - `Performing Streamed Install`
     - `Success`
   - `adb shell monkey` injected one launcher event and returned exit code `0`.
5. `gh release upload v7.0.0 "build\releases\android\ABSENKOK-v7.0.0+8013\ABSENKOK-v7.0.0+8013.apk#ABSENKOK-v7.0.0+8013 obfuscated smoke-verified APK" --repo Kaiser117450/ABSENKOK`
   - Uploaded the staged canonical APK to the existing GitHub release tag.
   - Published asset digest: `sha256:600eb099456f981a3a4b38af083d7f676c7dce1aed5db96b17aa9141ac0dfab1`

## Blocking Findings

No active blockers remain for Phase 49.

Repo-side acceptance blockers closed during execution:
- `admin_login_screen_test.dart` now targets the restored pure biometric helper.
- `pdf_service_color_test.dart` now matches the current `AttendanceDailyPdfStats` DTO.
- stale Wave 0 dashboard and kiosk streak stub tests were replaced with real widget and behavior coverage.
- `tool/release_preflight.ps1` now uses the release-safe `flutter test --no-test-assets` lane and runs Gradle from the correct `android` working directory.
- `tool/release_build.ps1` now handles dirty-worktree Git metadata, PowerShell 5.1 native `adb` stderr, scalar-versus-array device snapshots, and both truthful non-obfuscated and retained-symbol obfuscated release modes.

## Artifact State

- Staged release directory produced:
  - `build/releases/android/ABSENKOK-v7.0.0+8013/`
- Canonical retained APK produced:
  - `build/releases/android/ABSENKOK-v7.0.0+8013/ABSENKOK-v7.0.0+8013.apk`
- Release manifest produced:
  - `build/releases/android/ABSENKOK-v7.0.0+8013/release-manifest.json`
  - manifest `smokeVerification.status`: `passed`
  - manifest `debugArtifacts.obfuscationEnabled`: `true`
- Smoke evidence produced:
  - `build/releases/android/ABSENKOK-v7.0.0+8013/smoke-check.txt`
  - records successful `adb devices`, install, and launch evidence for device `V8X8ROMVSWVKIVW8`
- Debug evidence retained:
  - `mapping.txt`
  - `symbols/` release directory staged at the documented location
  - manifest `debugArtifacts.splitDebugInfoStatus`: `retained`
  - `symbolFiles`: `app.android-arm.symbols`, `app.android-arm64.symbols`, and `app.android-x64.symbols`
- Optional bundle retention remained omitted because the acceptance run did not request `-IncludeAppBundle`.
- GitHub release asset published:
  - `https://github.com/Kaiser117450/ABSENKOK/releases/download/v7.0.0/ABSENKOK-v7.0.0%2B8013.apk`
  - label: `ABSENKOK-v7.0.0+8013 obfuscated smoke-verified APK`

## Operator Notes

- The repo-side release contract is now behaving as intended through packaging and smoke verification.
- The release manifest now records whether split-debug-info files were actually emitted, and the final published v7.0 artifact uses the obfuscated path with retained symbol files.
- GitHub publication in this environment currently relies on `gh` CLI fallback because the app automation could not read the local staged artifact path directly.

## Next Action

Phase 49 is complete. The next planning action is milestone closeout for v7.0.
