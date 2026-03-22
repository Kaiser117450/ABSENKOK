---
phase: 38
slug: employee-schedule-read-model
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-03-22
---

# Phase 38 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Astro `astro check` + `astro build`; targeted SQL contract smoke via PowerShell `Select-String` |
| **Config file** | `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\package.json` |
| **Quick run command** | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` |
| **Full suite command** | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run the targeted SQL smoke or `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"`
- **After every plan wave:** Run `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 38-01-01 | 01 | 1 | SCHED-01 | SQL smoke | `powershell -Command "Select-String -Path 'sql/phase_38_employee_schedule_read_model_20260322.sql' -Pattern 'get_portal_schedule_week','resolve_portal_employee','outlet_name','shift_name' | Measure-Object"` | ❌ | ⬜ pending |
| 38-01-02 | 01 | 1 | SCHED-03 | SQL smoke | `powershell -Command "Select-String -Path 'sql/phase_38_employee_schedule_read_model_20260322.sql' -Pattern 'logical_date','ends_next_day','employee_id, date' | Measure-Object"` | ❌ | ⬜ pending |
| 38-02-01 | 02 | 2 | SCHED-01 | type/build smoke | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` | ❌ | ⬜ pending |
| 38-02-02 | 02 | 2 | SCHED-02 | type/build smoke | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` | ❌ | ⬜ pending |
| 38-02-03 | 02 | 2 | SCHED-03 | full build | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` | ❌ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real overnight shift stays on the logical start day and shows next-day end context | SCHED-03 | Requires live or seeded overnight data; repo fixtures do not cover that portal scenario today | Provision one employee with a 22:00 -> 06:00 shift, sign in to `/portal`, and confirm the row stays on the scheduled start day while showing a next-day end indicator |
| Portal "today" matches the intended business-local date near midnight | SCHED-01 | Server-rendered environment timezone needs live confirmation | Check the same employee's portal session before and after local midnight and confirm the highlighted "today" row changes on the correct local date |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
