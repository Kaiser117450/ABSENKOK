---
phase: 14-batch-csv-import
plan: 01
subsystem: services
tags: [csv, file-picker, batch-import, validation, dart]

# Dependency graph
requires:
  - phase: 13-soft-archive
    provides: "Employee model with archivedAt, Outlet model, SupabaseClientFactory"
provides:
  - "CsvRow, CsvRowValidation, CsvImportResult data models"
  - "CsvImportService with parseBytes, validate, buildInsertPayloads, generateTemplateCsv, insertAll"
  - "30 unit tests covering all CSV parse/validate/insert logic"
affects: [14-batch-csv-import]

# Tech tracking
tech-stack:
  added: [csv ^6.0.0, file_picker ^8.1.0]
  patterns: [pure-function-service, pre-fetched-data-validation, consistent-key-payloads]

key-files:
  created:
    - lib/models/csv_import_result.dart
    - lib/services/csv_import_service.dart
    - test/models/csv_import_result_test.dart
    - test/services/csv_import_service_test.dart
  modified:
    - pubspec.yaml
    - pubspec.lock

key-decisions:
  - "Normalize line endings (\\r\\n → \\n) before CSV parsing for cross-platform reliability"
  - "validate() takes pre-fetched data as parameters (pure function) — only insertAll() touches Supabase"
  - "Every insert payload has ALL keys with null for optional (not omitted) to prevent Supabase batch mismatch"

patterns-established:
  - "Pure-function service: parse/validate/build methods take data params, no DB access — trivially testable"
  - "Consistent-key payloads: all maps in batch insert have identical key sets, optional values are null"
  - "Duplicate detection: dual-layer check (within-CSV set + existing DB set) using lowercase_name|outlet_id composite key"

requirements-completed: [CSV-01, CSV-02, CSV-03, CSV-05, CSV-06]

# Metrics
duration: 14min
completed: 2026-03-11
---

# Phase 14 Plan 01: CSV Import Service Summary

**Pure-function CSV parse/validate/insert service with 30 unit tests, BOM handling, case-insensitive outlet resolution, and dual-layer duplicate detection**

## Performance

- **Duration:** 14 min
- **Started:** 2026-03-11T16:47:54Z
- **Completed:** 2026-03-11T17:01:33Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- CsvRow, CsvRowValidation, CsvImportResult pure Dart data models
- CsvImportService with 5 public methods: parseBytes, validate, buildInsertPayloads, generateTemplateCsv, insertAll
- 30 comprehensive unit tests covering all behavior (BOM, quoted fields, required fields, outlet resolution, duplicates, URL format)
- csv ^6.0.0 and file_picker ^8.1.0 packages added to pubspec.yaml

## Task Commits

Each task was committed atomically:

1. **Task 1: Add packages + create CsvRow/CsvRowValidation data models**
   - `8cab1b3` (test: failing model tests — RED)
   - `fa5d176` (feat: models + packages — GREEN)
2. **Task 2: Create CsvImportService with parse/validate/insert logic + unit tests**
   - `c94302a` (test: failing service tests — RED)
   - `c0eaf40` (feat: full service implementation — GREEN)

_TDD tasks each have RED and GREEN commits._

## Files Created/Modified
- `lib/models/csv_import_result.dart` — CsvRow, CsvRowValidation, CsvImportResult data classes
- `lib/services/csv_import_service.dart` — Parse, validate, insert, template logic (289 lines)
- `test/models/csv_import_result_test.dart` — 7 model unit tests
- `test/services/csv_import_service_test.dart` — 23 service unit tests (391 lines)
- `pubspec.yaml` — Added csv ^6.0.0 and file_picker ^8.1.0

## Decisions Made
- **Normalize line endings before CSV parse:** CsvToListConverter defaults to `\r\n` eol; normalizing `\r\n` and `\r` → `\n` ensures cross-platform reliability (Windows-saved CSVs, Mac CSVs, etc.)
- **Pure-function validation:** validate() takes pre-fetched outlet maps and employee keys as parameters — zero Supabase dependency, trivially testable
- **Consistent-key payloads:** Every batch insert map has all 5 keys (name, position, home_outlet_id, photo_url, is_active) with null for optional — prevents Supabase batch mismatch errors

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed CSV line ending handling**
- **Found during:** Task 2 (GREEN phase)
- **Issue:** CsvToListConverter default eol is `\r\n`; test strings with `\n` caused header+data to merge into single "row"
- **Fix:** Added line ending normalization (`\r\n` → `\n`, `\r` → `\n`) and explicit `eol: '\n'` in converter
- **Files modified:** lib/services/csv_import_service.dart
- **Verification:** All 23 service tests pass after fix
- **Committed in:** c0eaf40 (part of Task 2 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix)
**Impact on plan:** Essential for correctness — CSV files from different OS platforms would fail without normalization. No scope creep.

## Issues Encountered
- **Flutter test runner + spaces in path:** `flutter test` fails due to `objective_c` native asset build hook not quoting paths with spaces. Workaround: created directory junctions (`C:\FlutterSDK`, `C:\AbsensiApp`) to space-free paths. All tests run successfully via junction paths.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- CSV import service layer complete and fully tested
- Ready for Plan 14-02: CSV Import UI screen that consumes CsvImportService
- All public methods are documented and have comprehensive test coverage

## Self-Check: PASSED

All 5 created files verified present. All 4 commit hashes verified in git log.

---
*Phase: 14-batch-csv-import*
*Completed: 2026-03-11*
