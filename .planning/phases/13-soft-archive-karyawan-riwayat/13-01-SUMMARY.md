---
phase: 13-soft-archive-karyawan-riwayat
plan: 01
subsystem: database
tags: [supabase, employee-model, soft-delete, archived-at, dart]

# Dependency graph
requires: []
provides:
  - "Employee model with archivedAt DateTime? field"
  - "archived_at TIMESTAMPTZ column on employees table"
  - "Soft-delete foundation for employee lifecycle management"
affects: [13-02, 13-03, 14-admin-outlet-management, 15-export-data]

# Tech tracking
tech-stack:
  added: []
  patterns: ["nullable DateTime field with null-safe JSON deserialization"]

key-files:
  created: []
  modified: ["lib/models/employee.dart"]

key-decisions:
  - "archivedAt as DateTime? (not String) for type-safe timestamp handling"
  - "Null-safe deserialization: check null before DateTime.parse to handle existing employees"
  - "Database migration done manually via Supabase SQL Editor (security: no service_role key in code)"

patterns-established:
  - "Soft-delete pattern: archived_at timestamp + is_active boolean"
  - "Additive migration: nullable column with DEFAULT NULL for backward compatibility"

requirements-completed: [ARCH-01, ARCH-05]

# Metrics
duration: 2min
completed: 2026-03-11
---

# Phase 13 Plan 01: Foundation Archive Infrastructure Summary

**Employee model extended with archivedAt DateTime? field and archived_at TIMESTAMPTZ column added to production database**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-11T15:01:34Z
- **Completed:** 2026-03-11T15:03:18Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Database migration: `archived_at TIMESTAMPTZ DEFAULT NULL` column added to employees table (production-safe, backward compatible)
- Employee model updated with `DateTime? archivedAt` field including fromJson, toJson, and copyWith support
- All 14 existing employees retain `archived_at = NULL` (no data loss)
- Existing kiosk apps (v1.1) can still INSERT employees without `archived_at` field

## Task Commits

Each task was committed atomically:

1. **Task 1: Run database migration (archived_at column)** - Manual (user in Supabase SQL Editor)
2. **Task 2: Update Employee model with archivedAt field** - `8373123` (feat)

## Files Created/Modified
- `lib/models/employee.dart` - Added archivedAt DateTime? field, fromJson deserialization with null-safe DateTime.parse, toJson serialization, copyWith parameter

## Decisions Made
- Used `DateTime?` type for archivedAt (not `String?`) to enable type-safe date comparisons in future archive/restore logic
- Null-safe deserialization pattern: explicit null check before `DateTime.parse` to handle existing employees with no archived_at value
- Field positioned after `updatedAt` and before `activeBadgeId` to maintain logical grouping of timestamp fields

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

Database migration was completed manually by user in Supabase SQL Editor:
- ✅ `ALTER TABLE employees ADD COLUMN archived_at TIMESTAMPTZ DEFAULT NULL;`
- ✅ Column verified to exist with all existing employees having `archived_at = NULL`

## Next Phase Readiness
- Employee model now supports archive state tracking — ready for Plan 02 (archive/restore service + admin UI)
- `is_active` boolean remains the primary query filter; `archivedAt` is the informational timestamp
- All subsequent plans (13-02, 13-03) can import Employee model and access archivedAt field

---
*Phase: 13-soft-archive-karyawan-riwayat*
*Completed: 2026-03-11*

## Self-Check: PASSED

- ✅ FOUND: 13-01-SUMMARY.md
- ✅ FOUND: archivedAt in employee.dart (6 occurrences: field, constructor, fromJson, toJson, copyWith param, copyWith body)
- ✅ FOUND: commit 8373123
- ✅ flutter analyze: No issues found
