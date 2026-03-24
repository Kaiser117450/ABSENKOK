---
phase: 47
slug: toolchain-contract-preflight-gates
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-23
---

# Phase 47 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PowerShell helper scripts plus Flutter CLI and Gradle release-compile tasks |
| **Config file** | `docs/android-release-contract.md`, `tool/release_env.ps1`, `tool/release_preflight.ps1`, `android/settings.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties` |
| **Quick run command** | `powershell -ExecutionPolicy Bypass -File tool/release_env.ps1 -CheckOnly` |
| **Full suite command** | `powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1` |
| **Estimated runtime** | ~6 minutes with current analyzer/test load |

---

## Sampling Rate

- **After every task commit:** run the narrowest matching script/doc grep for the files touched by that task
- **After every plan wave:** run `powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1`
- **Before final phase verification:** confirm the preflight lane fails before package/sign tasks when analyzer/test debt is still present, and confirm the tracked contract still pins Java 21 JBR plus Kotlin 1.9.25
- **Max feedback latency:** 6 minutes

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 47-01-01 | 01 | 1 | TOOL-01 | env helper | `powershell -ExecutionPolicy Bypass -File tool/release_env.ps1 -CheckOnly` | Planned | pending |
| 47-01-02 | 01 | 1 | TOOL-01 | contract doc grep | `powershell -Command "Select-String -Path 'README.md','docs/android-release-contract.md' -Pattern 'Java 21','Flutter 3.41.1','Gradle 8.14','Kotlin 1.9.25','C:\\\\flutter'"` | Planned | pending |
| 47-02-01 | 02 | 2 | BUILD-02 | script structure | `powershell -Command "Select-String -Path 'tool/release_preflight.ps1' -Pattern 'flutter analyze','flutter test','compileReleaseSources'"` | Planned | pending |
| 47-02-02 | 02 | 2 | BUILD-02 | fail-fast lane | `powershell -Command "& { powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1; if ($LASTEXITCODE -eq 0) { throw 'preflight unexpectedly passed despite known analyzer/test debt' } }"` | Planned | pending |
| 47-03-01 | 03 | 3 | TOOL-02 | version decision grep | `powershell -Command "Select-String -Path 'docs/android-release-contract.md','android/settings.gradle.kts' -Pattern '1\\.9\\.25','8\\.11\\.1','8\\.14','3\\.41\\.1'"` | Existing/Planned | pending |
| 47-03-02 | 03 | 3 | TOOL-02 | bypass-flag guard | `powershell -Command "Select-String -Path 'tool/release_preflight.ps1','docs/android-release-contract.md' -Pattern 'android-skip-build-dependency-validation','surprise upgrades','Kotlin 2'"` | Planned | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

Existing infrastructure is enough to validate this phase. No new test framework is required before execution; the missing pieces are the tracked PowerShell helper and preflight scripts themselves.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Another operator can discover the release contract from the repo root | TOOL-01, TOOL-02 | Discoverability is a documentation UX concern, not just a regex check | Open `README.md` and confirm it points directly to the tracked Android release contract. |
| The preflight lane stops before package/sign tasks | BUILD-02 | Operators need to verify the lane semantics, not only its exit code | Inspect `tool/release_preflight.ps1` and confirm it never calls `assembleRelease`, `bundleRelease`, `packageRelease`, or signing tasks. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or existing script/grep coverage
- [ ] Sampling continuity: no 3 consecutive implementation tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 6 minutes
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
