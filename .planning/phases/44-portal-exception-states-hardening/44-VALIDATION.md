---
phase: 44
slug: portal-exception-states-hardening
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-23
---

# Phase 44 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Astro `astro check` + `astro build`; targeted PowerShell source-contract smoke checks |
| **Config file** | `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\package.json` |
| **Quick run command** | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` |
| **Full suite command** | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** run the targeted source-contract smoke or `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"`
- **After every plan wave:** run `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"`
- **Before `$gsd-verify-work`:** full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 44-01-01 | 01 | 1 | ATTN-05 | source smoke | `powershell -Command "Select-String -Path 'sql/phase_42_portal_attendance_recap_20260323.sql' -Pattern 'belum_pulang','tidak_hadir','sedang_bekerja','belum_masuk' | Measure-Object"` | Existing | pending |
| 44-01-02 | 01 | 1 | ATTN-05 | type/check | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` | No | pending |
| 44-02-01 | 02 | 2 | ATTN-05 | source smoke | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro' -Pattern 'needsFollowUp','followUpLabel','supportingCopy' | Measure-Object"` | Existing | pending |
| 44-02-02 | 02 | 2 | PORT-03 | type/check | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` | Existing | pending |
| 44-03-01 | 03 | 2 | PORT-04 | source smoke | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/attendance.astro','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceSummary.astro','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/layouts/PortalLayout.astro' -Pattern 'followUpCount','PortalStatePanel','days.length === 0','portal-progress','aria-busy' | Measure-Object"` | Existing | pending |
| 44-03-02 | 03 | 2 | PORT-04 | full build | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` | Existing | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Missing-clock-out and no-attendance days are visually distinguishable follow-up problems | ATTN-05 | Static source checks cannot judge whether the employee-facing copy is genuinely clear | Use one employee with both `belum_pulang` and `tidak_hadir` rows, then confirm each card explains a different problem instead of one generic warning. |
| A valid portal user with zero recap rows sees one explicit recap empty state | PORT-04 | Requires a real authenticated-but-empty account state | Sign in as an employee whose portal account resolves but has no recap rows, then confirm the page shows a recap-specific empty card instead of summary zeros plus a small history placeholder. |
| Shell navigation and retry actions show pending feedback on a phone-width viewport | PORT-04 | Requires interactive timing and viewport review | On a phone-width browser, tap `Kehadiran`, `Beranda`, and any recap retry CTA, then confirm the shell progress bar appears and the page remains navigable. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
