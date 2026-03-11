---
phase: 14
slug: batch-csv-import
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-11
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) |
| **Config file** | `analysis_options.yaml` (exists) |
| **Quick run command** | `flutter test test/services/csv_import_service_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/services/csv_import_service_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | CSV-01, CSV-02 | unit | `flutter test test/services/csv_import_service_test.dart` | ❌ W0 | ⬜ pending |
| 14-01-02 | 01 | 1 | CSV-03 | unit | `flutter test test/services/csv_import_service_test.dart` | ❌ W0 | ⬜ pending |
| 14-01-03 | 01 | 1 | CSV-05, CSV-06 | unit | `flutter test test/services/csv_import_service_test.dart` | ❌ W0 | ⬜ pending |
| 14-02-01 | 02 | 2 | CSV-04 | widget | Manual — wizard UI with mock data | N/A | ⬜ pending |
| 14-02-02 | 02 | 2 | CSV-01 | integration | `flutter analyze` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/csv_import_service_test.dart` — covers CSV-01, CSV-02, CSV-03, CSV-05, CSV-06 (parsing, validation, duplicate detection)
- [ ] Framework install: Not needed — flutter_test is SDK package

*New packages needed: `csv` and `file_picker` (added via pubspec.yaml in Plan 01)*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Wizard UI flow (Upload→Preview→Confirm→Result) | CSV-04 | Requires mounted widget with file picker interaction | 1. Open CSV import screen 2. Upload template CSV 3. Verify preview table shows rows 4. Confirm import 5. Verify result summary |
| File picker integration | CSV-01 | Android SAF file picker requires device/emulator | 1. Tap upload button 2. File picker opens 3. Select .csv file 4. File content loaded |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
