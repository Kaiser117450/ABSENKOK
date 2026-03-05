---
phase: 08
slug: schedule-system-fix-supabase-integration
status: validated
nyquist_compliant: false
wave_0_complete: true
created: 2026-03-05
---

# Phase 8 — Validation Strategy

> Schedule System Fix + Supabase Integration

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | `pubspec.yaml` (dev_dependencies → flutter_test) |
| **Quick run command** | `flutter test test/models/shift_schedule_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/models/shift_schedule_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 3 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | REQ-M5-01 | unit | `flutter test test/models/shift_schedule_test.dart` | ✅ | ✅ green |
| 08-01-02 | 01 | 1 | REQ-M5-01 | unit | `flutter test test/models/shift_schedule_test.dart` | ✅ | ✅ green |
| 08-02-01 | 02 | 2 | REQ-M5-02 | manual | N/A (widget+Supabase dep) | ❌ | ⚠️ manual |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Automated Test Coverage (24 tests)

### `test/models/shift_schedule_test.dart`

| Group | Tests | Covers |
|-------|-------|--------|
| ShiftSlot factories | 4 | Shift name, time range, color for Pagi/Siang/Sore/Libur |
| ShiftSlot serialization | 1 | toJson → fromJson round-trip |
| ScheduleEntry factories | 4 | fromEmployee, sakit, izin, dayOff factory behavior |
| ScheduleEntry serialization | 3 | Round-trip normal, sakit status preserved, null status default |
| OutletSchedule | 5 | isDraft, isWeekly, getEntriesForDate, toJson/fromJson |
| Date normalization | 4 | split(T)[0] pattern, DateTime.parse, round-trip, same-day |
| ScheduleStatus extension | 2 | Indonesian labels, distinct colors |

---

## Wave 0 Requirements

- [x] `test/models/shift_schedule_test.dart` — model + date normalization tests
- Existing infrastructure covers Phase 8 model-level requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Supabase-first load with SQLite fallback | REQ-M5-01 | Requires live Supabase + SQLite runtime | Open Jadwal Shift → check debug logs for "Loaded schedule from Supabase" |
| Dual-write save order (Supabase → SQLite) | REQ-M5-01 | Requires Supabase insert + SQLite write-through | Save schedule → check Supabase dashboard + debug log |
| Unsaved changes indicator (amber dot) | REQ-M5-01 | UI visual verification | Auto-generate → verify "Simpan *" appears on save button |
| Bulk assign skips sakit/izin days | REQ-M5-02 | Widget requires full Supabase mock | Assign Pagi to all → check sakit employee cells unchanged |
| Select All + bulk shift picker flow | REQ-M5-02 | Widget integration test | Tap checklist FAB → Select All → pick Siang → verify all cells |
| Bulk mode toggle enters/exits selection | REQ-M5-02 | Widget state test | Tap FAB → orange AppBar → tap X → normal AppBar |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Manual-Only designation
- [x] Model serialization and date normalization covered by automated tests
- [ ] Widget-level bulk assign tests need Supabase mock (manual for now)
- [x] Wave 0 covers all model-level requirements
- [x] Feedback latency < 3s
- [ ] `nyquist_compliant: true` — blocked by manual-only items

**Approval:** partial 2026-03-05

---

## Validation Audit 2026-03-05

| Metric | Count |
|--------|-------|
| Gaps found | 7 |
| Resolved (automated) | 4 |
| Escalated (manual) | 6 |
