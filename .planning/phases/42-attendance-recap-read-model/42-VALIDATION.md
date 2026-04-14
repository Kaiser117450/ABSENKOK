---
phase: 42
slug: attendance-recap-read-model
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-03-23
---

# Phase 42 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Astro `astro check` + `astro build`; targeted PowerShell SQL/source-contract smoke checks |
| **Config file** | `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\package.json` |
| **Quick run command** | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` |
| **Full suite command** | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** run the targeted SQL/source smoke or `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"`
- **After every plan wave:** run `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"`
- **Before `$gsd-verify-work`:** full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 42-01-01 | 01 | 1 | ATTN-02 | SQL smoke | `powershell -Command "Select-String -Path 'sql/phase_42_portal_attendance_recap_20260323.sql' -Pattern 'get_portal_attendance_recap','attendance_status','first_masuk_at','last_pulang_at','scan_count' | Measure-Object"` | No | pending |
| 42-01-02 | 01 | 1 | ATTN-03 | SQL smoke | `powershell -Command "Select-String -Path 'sql/phase_42_portal_attendance_recap_20260323.sql' -Pattern 'logical_date','pulang','12','history_start','resolve_portal_employee' | Measure-Object"` | No | pending |
| 42-02-01 | 02 | 2 | ATTN-02 | type/check | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` | No | pending |
| 42-02-02 | 02 | 2 | ATTN-02 | source smoke | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap.ts' -Pattern 'summaryCounts','recentDays','attendanceStatus','monthStart' | Measure-Object"` | No | pending |
| 42-02-03 | 02 | 2 | ATTN-03 | full build | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` | No | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Overnight shift with next-day `pulang` before noon stays on the prior logical day in the portal recap | ATTN-03 | Requires seeded or live overnight attendance data; repo fixtures do not cover this portal scenario today | Seed one employee with late `masuk` on Day 1 and pre-noon `pulang` on Day 2, then confirm the recap row shows both timestamps on Day 1 |
| Month-to-date summary counts equal the recap day rows for one employee | ATTN-02 | Requires realistic mixed attendance outcomes in the current month | Seed mixed `hadir`, `sakit`, `izin`, and incomplete days, then confirm the helper summary counts match the rows filtered to `logicalDate >= monthStart` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
