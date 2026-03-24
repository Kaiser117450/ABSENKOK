---
phase: 49
slug: release-runbook-acceptance
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-23
---

# Phase 49 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PowerShell release helpers plus markdown/runbook contract inspection |
| **Config file** | `tool/release_env.ps1`, `tool/release_preflight.ps1`, `tool/release_build.ps1`, `docs/android-release-runbook.md`, `docs/android-release-contract.md` |
| **Quick run command** | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly -SmokeVerify` |
| **Full suite command** | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -SmokeVerify -Obfuscate` |
| **Estimated runtime** | ~30 seconds for quick contract checks, longer for a full smoke-verified release run |

---

## Sampling Rate

- **After every task commit:** run the narrowest matching command for the touched artifact or helper contract
- **After every plan wave:** run `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly -SmokeVerify`
- **Before final phase verification:** run the full documented release lane with `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -SmokeVerify -Obfuscate`
- **Max feedback latency:** 30 seconds for quick checks; acceptance run is the explicit longer gate

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 49-01-01 | 01 | 1 | OPS-01 | runbook marker audit | `powershell -Command '& { $content = Get-Content "docs/android-release-runbook.md" -Raw; $markers = @("powershell -ExecutionPolicy Bypass -File tool/release_env.ps1 -CheckOnly","powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1","powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly","powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -SmokeVerify","android/key.properties.example","ABSENKOK-v7.0.0+8013","-IncludeAppBundle"); foreach ($marker in $markers) { if ($content -notmatch [regex]::Escape($marker)) { throw ("Missing runbook marker: " + $marker) } } }'` | Planned | green |
| 49-01-02 | 01 | 1 | OPS-01 | helper contract check | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly -SmokeVerify` | Existing | green |
| 49-02-01 | 02 | 2 | OPS-01 | bootstrap checkpoint | Manual checkpoint before release run | Human | green |
| 49-02-02 | 02 | 2 | OPS-01 | release record acceptance | `powershell -Command '& { $label = "ABSENKOK-v7.0.0+8013"; $dir = Join-Path "build/releases/android" $label; $apk = Join-Path $dir ($label + ".apk"); $manifestPath = Join-Path $dir "release-manifest.json"; $smokePath = Join-Path $dir "smoke-check.txt"; $acceptancePath = ".planning/phases/49-release-runbook-acceptance/49-ACCEPTANCE.md"; if (-not (Test-Path $apk)) { throw "Canonical APK missing" }; if (-not (Test-Path $manifestPath)) { throw "Manifest missing" }; if (-not (Test-Path $smokePath)) { throw "Smoke evidence missing" }; if (-not (Test-Path $acceptancePath)) { throw "Acceptance note missing" }; $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json; if ($manifest.canonicalArtifact -notmatch "\.apk$") { throw "Manifest canonicalArtifact is not APK" }; if ($manifest.smokeVerification.status -ne "passed") { throw ("Smoke status was " + $manifest.smokeVerification.status) }; if ($manifest.debugArtifacts.obfuscationEnabled -ne $true) { throw "Published release is not obfuscated" }; if ($manifest.debugArtifacts.splitDebugInfoStatus -ne "retained") { throw ("Debug artifact status was " + $manifest.debugArtifacts.splitDebugInfoStatus) } }'` | Existing | green |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

Existing infrastructure covers the repo-side phase requirements. No new framework or test scaffold is needed before execution; the remaining prerequisites are local operator state:
- untracked `android/key.properties`
- private upload keystore availability
- an `adb`-visible Android target for smoke verification

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Private signing inputs remain local-only and are not added to git | OPS-01 | The repo cannot create or verify private upload-key values safely | After bootstrap, confirm `android/key.properties` and the upload keystore exist locally and remain untracked. |
| At least one Android target is available for smoke verification | OPS-01 | Device or emulator availability is outside the repo | Run `adb devices` until one target appears in `device` state before Task 49-02-02. |
| A second operator could follow the written runbook without tribal knowledge | OPS-01 | Human readability and operational clarity still need a manual review | Read `docs/android-release-runbook.md` end-to-end and confirm no hidden prerequisite is implied rather than stated. |

---

## Validation Sign-Off

- [x] All implementation tasks have an `<automated>` verify
- [x] Sampling continuity: no 3 consecutive implementation tasks without automated verification
- [x] Wave 0 covers all missing references through existing release tooling
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` set in frontmatter
- [x] Full smoke-verified release run completes or records a concrete blocker for follow-up

**Approval:** approved on 2026-03-25 after `tool/release_build.ps1 -SmokeVerify -Obfuscate` produced the canonical APK, `release-manifest.json`, `smoke-check.txt`, retained `symbols/`, and `mapping.txt`, with `smokeVerification.status = passed`, `debugArtifacts.obfuscationEnabled = true`, and `debugArtifacts.splitDebugInfoStatus = retained`.
