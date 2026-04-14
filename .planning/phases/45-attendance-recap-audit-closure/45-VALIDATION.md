---
phase: 45
slug: attendance-recap-audit-closure
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-23
---

# Phase 45 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PowerShell source/doc smoke checks plus Astro `npm run build` in the website repo |
| **Config file** | `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\package.json` |
| **Quick run command** | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap-presentation.ts','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro' -Pattern 'logicalDate','referenceDate','getRecapDayPresentationForDay' | Measure-Object"` |
| **Full suite command** | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** run the targeted source/doc smoke check for the task that just landed
- **After every wave:** run `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` if website code changed in that wave
- **Before final audit closeout:** run the milestone-audit smoke check that fails on `gaps_found` or `orphaned`
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 45-01-01 | 01 | 1 | ATTN-05 | source smoke | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap-presentation.ts','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro' -Pattern 'getRecapDayPresentationForDay','logicalDate','referenceDate' | Measure-Object"` | Existing | pending |
| 45-01-02 | 01 | 1 | ATTN-05 | full build | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` | Existing | pending |
| 45-02-01 | 02 | 1 | ATTN-02, ATTN-03 | doc smoke | `powershell -Command "Test-Path '.planning/phases/42-attendance-recap-read-model/42-VERIFICATION.md'; Select-String -Path '.planning/phases/42-attendance-recap-read-model/42-VERIFICATION.md' -Pattern 'ATTN-02','ATTN-03','get_portal_attendance_recap','overnight' | Measure-Object"` | No | pending |
| 45-02-02 | 02 | 1 | ATTN-01, ATTN-04, PORT-03 | doc smoke | `powershell -Command "Test-Path '.planning/phases/43-portal-attendance-recap-surface/43-VERIFICATION.md'; Select-String -Path '.planning/phases/43-portal-attendance-recap-surface/43-VERIFICATION.md' -Pattern 'ATTN-01','ATTN-04','PORT-03','/portal/attendance' | Measure-Object"` | No | pending |
| 45-03-01 | 03 | 2 | ATTN-05, PORT-04 | doc smoke | `powershell -Command "Test-Path '.planning/phases/44-portal-exception-states-hardening/44-VERIFICATION.md'; Select-String -Path '.planning/phases/44-portal-exception-states-hardening/44-VERIFICATION.md' -Pattern 'ATTN-05','PORT-04','historical','PortalStatePanel' | Measure-Object"` | No | pending |
| 45-03-02 | 03 | 2 | ATTN-01, ATTN-02, ATTN-03, ATTN-04, ATTN-05, PORT-03, PORT-04 | audit smoke | `powershell -Command "$audit = Get-Content '.planning/v6.3-MILESTONE-AUDIT.md' -Raw; if ($audit -match 'gaps_found' -or $audit -match 'orphaned') { throw 'audit blocked' }"` | Existing | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new framework or database setup is needed before execution.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Historical follow-up rows read as past-day issues rather than sounding like they are happening today | ATTN-05 | Human readability and tense are easier to judge in the browser than from static text checks | Open `/portal/attendance` for an employee with a past `belum_pulang` or `tidak_hadir` row and confirm the supporting sentence clearly describes a historical workday. |
| Recap empty, error, and retry flows remain understandable after the helper/history refactor | PORT-04 | Needs browser navigation and state transitions | Exercise `/portal/attendance` empty/error/retry flows on a phone-width browser and confirm the state panel copy and shell behavior remain intact. |
| The recap route still feels like part of the same employee portal flow after audit closure | ATTN-01, ATTN-04, PORT-03 | Requires navigation and realistic data, not just source inspection | Move between `/portal` and `/portal/attendance`, confirm the shell context remains consistent, and spot-check that visible month summary counts still match current-month history rows. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or existing-artifact smoke coverage
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
