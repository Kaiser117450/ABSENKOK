---
phase: 17
slug: schedule-grid-ui-redesign
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (built-in) |
| **Config file** | `analysis_options.yaml` (existing) |
| **Quick run command** | `flutter test test/models/shift_schedule_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/models/shift_schedule_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 17-01-01 | 01 | 1 | GRID-01 | widget | `flutter test test/screens/admin/schedule_grid_test.dart` | ❌ W0 | ⬜ pending |
| 17-01-02 | 01 | 1 | GRID-02 | widget | `flutter test test/screens/admin/schedule_grid_test.dart` | ❌ W0 | ⬜ pending |
| 17-01-03 | 01 | 1 | GRID-03 | manual-only | Visual verification on tablet | N/A | ⬜ pending |
| 17-01-04 | 01 | 1 | GRID-04 | manual-only | Visual verification on tablet | N/A | ⬜ pending |
| 17-01-05 | 01 | 1 | GRID-05 | unit | `flutter test test/models/shift_schedule_test.dart` | ✅ | ⬜ pending |
| 17-01-06 | 01 | 1 | GRID-06 | widget | `flutter test test/screens/admin/schedule_grid_test.dart` | ❌ W0 | ⬜ pending |
| 17-01-07 | 01 | 1 | GRID-07 | widget | `flutter test test/screens/admin/schedule_grid_test.dart` | ❌ W0 | ⬜ pending |
| 17-01-08 | 01 | 1 | GRID-08 | unit | `flutter test test/models/shift_schedule_test.dart` | ✅ | ⬜ pending |
| 17-01-09 | 01 | 1 | GRID-09 | widget | `flutter test test/screens/admin/schedule_grid_test.dart` | ❌ W0 | ⬜ pending |
| 17-01-10 | 01 | 1 | GRID-10 | widget | `flutter test test/screens/admin/schedule_grid_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `flutter pub add two_dimensional_scrollables` — add grid dependency
- [ ] `flutter analyze` — verify no analysis issues after dependency add
- [ ] `test/screens/admin/schedule_grid_test.dart` — widget test stubs for GRID-01, GRID-02, GRID-06, GRID-07, GRID-09, GRID-10

*Existing infrastructure covers GRID-05 (shift colors) and GRID-08 (data persistence).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Employee column pinned on horizontal scroll | GRID-03 | Scroll behavior requires real viewport/tablet | Scroll grid horizontally — employee names stay visible |
| Header row pinned on vertical scroll | GRID-04 | Scroll behavior requires real viewport/tablet | Scroll grid vertically — day headers stay visible |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
