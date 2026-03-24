---
phase: 48
slug: secure-signing-artifact-discipline
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-23
---

# Phase 48 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PowerShell release helpers plus Flutter CLI, Gradle shrink outputs, and `adb` smoke verification |
| **Config file** | `android/app/build.gradle.kts`, `.gitignore`, `android/key.properties.example`, `tool/release_build.ps1`, `tool/release_preflight.ps1`, `docs/android-release-contract.md` |
| **Quick run command** | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly` |
| **Full suite command** | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -IncludeSideLoadApk -SmokeVerify` |
| **Estimated runtime** | ~12 minutes on a green lane plus device install time |

---

## Sampling Rate

- **After every task commit:** run the narrowest matching static check or `-CheckOnly` validation for the files touched by that task
- **After every plan wave:** run `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly`
- **Before final phase verification:** run `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -IncludeSideLoadApk -SmokeVerify` with real signing inputs and an attached Android target
- **Max feedback latency:** 12 minutes on a green lane; static checks should stay under 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 48-01-01 | 01 | 1 | REL-01 | privacy guard | `powershell -Command "Select-String -Path '.gitignore','android/key.properties.example' -Pattern 'android/key.properties','keyAlias','storeFile'"` | Planned | pending |
| 48-01-02 | 01 | 1 | REL-01 | signing-config guard | `powershell -Command "$content = Get-Content 'android/app/build.gradle.kts' -Raw; if ($content -notmatch 'key\\.properties' -or $content -notmatch 'create\\(\"release\"\\)') { throw 'missing release signing config' }; if ($content -match 'signingConfigs\\.getByName\\(\"debug\"\\)') { throw 'release still uses debug signing' }"` | Planned | pending |
| 48-02-01 | 02 | 2 | REL-02 | release lane structure | `powershell -Command "Select-String -Path 'tool/release_build.ps1' -Pattern 'release_preflight','build appbundle','IncludeSideLoadApk','release-manifest'"` | Planned | pending |
| 48-02-02 | 02 | 2 | REL-02 | check-only lane | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly` | Planned | pending |
| 48-03-01 | 03 | 3 | REL-03 | symbol retention | `powershell -Command "Select-String -Path 'tool/release_build.ps1' -Pattern 'split-debug-info','mapping.txt','symbols'"` | Planned | pending |
| 48-03-02 | 03 | 3 | REL-03 | smoke-verification lane | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly -IncludeSideLoadApk -SmokeVerify` | Planned | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

Existing infrastructure is enough to validate this phase. No new test framework is required before execution; the only external runtime dependency is a reachable Android target for the final smoke-verification step.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The private upload keystore and real `android/key.properties` stay outside tracked source control | REL-01 | Secret handling cannot be fully proven from tracked code alone | Confirm the real signing files are local-only and not staged in git before cutting a release. |
| The signed shrunken release reaches the first usable screen on representative Android hardware | REL-03 | Runtime smoke evidence needs a real device or emulator target | Run the smoke-verification mode against an attached device or emulator and retain the generated `smoke-check.txt` next to the signed artifacts. |
| If the final retained artifact set omits the APK, the manifest clearly marks any locally built APK as smoke-only or omitted | REL-02, REL-03 | Release-policy intent is not captured by syntax checks alone | Inspect the staged release directory and confirm `release-manifest.json` matches the actual distribution decision. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or existing static-check coverage
- [ ] Sampling continuity: no 3 consecutive implementation tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 12 minutes on a green lane
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
