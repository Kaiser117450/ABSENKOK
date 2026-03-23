---
phase: 43
slug: portal-attendance-recap-surface
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-23
---

# Phase 43 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Astro `astro check` + `astro build`; targeted PowerShell source-contract checks |
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
| 43-01-01 | 01 | 1 | ATTN-04 | source smoke | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceSummary.astro' -Pattern 'summaryCounts','hadir','belumPulang','libur' | Measure-Object"` | No | pending |
| 43-01-02 | 01 | 1 | PORT-03 | type/check | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` | Existing | pending |
| 43-02-01 | 02 | 1 | ATTN-01 | source smoke | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/layouts/PortalLayout.astro' -Pattern '/portal/attendance','activeSection','Kehadiran' | Measure-Object"` | Existing | pending |
| 43-02-02 | 02 | 1 | PORT-03 | source smoke | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/index.astro' -Pattern '/portal/attendance','activeSection=\"home\"','Lihat rekap kehadiran' | Measure-Object"` | Existing | pending |
| 43-03-01 | 03 | 2 | ATTN-01 | source smoke | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/attendance.astro' -Pattern 'loadPortalAttendanceRecap','PortalAttendanceSummary','PortalAttendanceHistorySection' | Measure-Object"` | No | pending |
| 43-03-02 | 03 | 2 | ATTN-04 | full build | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` | Existing | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Employee can open the recap from the portal shell and move back to Beranda without losing context | ATTN-01 | Requires real browser navigation and active-tab review | Open `/portal`, use the shell nav or CTA to visit `/portal/attendance`, then return to `/portal` and confirm the same shell and logout affordance remain visible. |
| Summary cards match the current-month recap rows for one employee | ATTN-04 | Needs realistic attendance data across multiple statuses | Use a portal account with mixed month data, then confirm the cards equal the visible recap rows whose `logicalDate` falls inside the current month. |
| The recap page remains readable on a phone-width viewport | PORT-03 | Visual density and wrapping are easier to validate manually | Review `/portal/attendance` around 390px width and confirm there is no horizontal scrolling and no clipped text in history cards or summary cards. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
