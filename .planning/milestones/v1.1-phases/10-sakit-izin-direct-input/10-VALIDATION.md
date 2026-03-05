---
phase: 10
slug: sakit-izin-direct-input
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-05
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (dart test) |
| **Config file** | `pubspec.yaml` (dev_dependencies: flutter_test) |
| **Quick run command** | `C:\flutter\bin\flutter.bat test --no-pub` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test --no-pub` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Manual Supabase query verification
- **After every plan wave:** Run quick command + manual device test
- **Before `/gsd:verify-work`:** Full UAT on device
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | REQ-M5-04 | integration | Supabase SQL query | N/A | ⬜ pending |
| 10-01-02 | 01 | 1 | REQ-M5-04 | integration | Supabase SQL query | N/A | ⬜ pending |
| 10-02-01 | 02 | 1 | REQ-M5-04 | manual+query | Device test + SQL | N/A | ⬜ pending |
| 10-02-02 | 02 | 1 | REQ-M5-04 | manual+query | Device test + SQL | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.*
- No new test framework needed
- Supabase RLS already supports admin ALL operations on attendance_logs
- attendance_logs schema already has sakit/izin type constraint

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Sakit/izin appears in Rekap Harian as badge | REQ-M5-04 | Requires UI rendering on device | 1. Set sakit for employee via dialog 2. Open Rekap Harian 3. Verify badge renders |
| Edit sakit/izin record | REQ-M5-04 | Requires UI interaction flow | 1. Open sakit/izin history 2. Tap edit on record 3. Change type/notes 4. Verify update in Rekap Harian |
| Delete sakit/izin record | REQ-M5-04 | Requires UI interaction flow | 1. Open sakit/izin history 2. Tap delete on record 3. Confirm 4. Verify removed from Rekap Harian |
| Backdated entry (last week) | REQ-M5-04 | Requires date picker interaction | 1. Set sakit for 5 days ago 2. Open Rekap Harian for that date range 3. Verify appears correctly |
| < 3 tap flow | REQ-M5-04 | UX measurement | 1. From employee list 2. Tap menu → Sakit/Izin 3. Tap Simpan = 3 taps total |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
