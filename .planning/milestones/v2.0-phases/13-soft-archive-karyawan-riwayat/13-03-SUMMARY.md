---
phase: 13-soft-archive-karyawan-riwayat
plan: 03
subsystem: admin-archived-employees
tags: [flutter, admin, archive, riwayat, restore]
dependency_graph:
  requires: [13-01]
  provides: [ArchivedEmployeesScreen, /admin/archived-employees route]
  affects: [admin navigation, employee restore flow]
tech_stack:
  added: []
  patterns: [ConsumerStatefulWidget, AppCard list, RefreshIndicator, Supabase query filters]
key_files:
  created:
    - lib/screens/admin/archived_employees_screen.dart
  modified:
    - lib/app.dart
decisions:
  - Used theme AppBar (red) instead of white override — consistent with all admin screens
  - Import from core/theme.dart for AppColors (not core/colors.dart which doesn't exist)
  - Import from core/supabase_client.dart for SupabaseClientFactory (not core/supabase_client_factory.dart)
metrics:
  duration: 8m
  completed: "2026-03-11T15:16:31Z"
  tasks: 2
  files_created: 1
  files_modified: 1
requirements:
  - ARCH-02
  - ARCH-05
  - ARCH-06
---

# Phase 13 Plan 03: Riwayat Karyawan Screen Summary

**Archived employee list screen with restore functionality using AppCard pattern and Supabase query filters**

## What Was Done

### Task 1: Create ArchivedEmployeesScreen with restore action
**Commit:** `2a2ef6d`
**Files:** `lib/screens/admin/archived_employees_screen.dart` (created, 256 lines)

Created the full Riwayat Karyawan screen implementing:
- **Data loading:** Supabase query with `.eq('is_active', false).not('archived_at', 'is', null)` to fetch only archived employees, ordered by `archived_at` descending
- **Outlet resolution:** Separate outlets query, matched via `homeOutletId` for display
- **Employee cards:** `_ArchivedEmployeeCard` using `AppCard` pattern with CircleAvatar (initial), name, outlet name, archive date formatted as "Diarsipkan d MMM yyyy" (Indonesian locale)
- **Restore action:** `_restoreEmployee()` updates employee to `is_active=true, archived_at=null`, shows success/error toast, refreshes list
- **Empty state:** `AppEmptyState` with archive icon and "Belum Ada Karyawan Diarsipkan" message
- **Loading state:** Shimmer skeleton with 5 placeholder cards
- **Refresh:** `RefreshIndicator` wrapping ListView for pull-to-refresh

### Task 2: Add route and navigation
**Commit:** `bd63bf3`
**Files:** `lib/app.dart` (modified)

- Added import for `ArchivedEmployeesScreen`
- Registered `GoRoute` at `/admin/archived-employees` inside admin `ShellRoute`
- Route is automatically protected by existing admin authentication guard (parent ShellRoute + redirect logic)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed incorrect import paths from plan**
- **Found during:** Task 1
- **Issue:** Plan specified `../../core/colors.dart` and `../../core/supabase_client_factory.dart` which don't exist
- **Fix:** Used correct paths `../../core/theme.dart` (for AppColors) and `../../core/supabase_client.dart` (for SupabaseClientFactory)
- **Files modified:** `lib/screens/admin/archived_employees_screen.dart`
- **Commit:** `2a2ef6d`

**2. [Rule 1 - Bug] Removed AppBar style override**
- **Found during:** Task 1
- **Issue:** Plan overrode AppBar to white background, but the app theme uses red AppBar consistently across all admin screens
- **Fix:** Removed `backgroundColor: Colors.white, elevation: 0` and `TextStyle(fontWeight: FontWeight.w900)` overrides, letting the theme handle AppBar styling
- **Files modified:** `lib/screens/admin/archived_employees_screen.dart`
- **Commit:** `2a2ef6d`

## Verification Results

```
flutter analyze lib/screens/admin/archived_employees_screen.dart → No issues found!
dart analyze lib/app.dart → No issues found!
```

**Query patterns verified:**
- `eq('is_active', false)` at line 41
- `not('archived_at', 'is', null)` at line 42
- `'is_active': true` at line 75 (restore)
- `'archived_at': null` at line 76 (restore)
- `onRestore.*_restoreEmployee` callback at line 129

**Route verified:**
- `/admin/archived-employees` at line 124 of app.dart
- Import at line 21 of app.dart

## Key Links Verified

| From | To | Via | Status |
|------|----|-----|--------|
| `_loadData` | employees table | `.eq('is_active', false).not('archived_at', 'is', null)` | ✅ |
| `_ArchivedEmployeeCard` restore button | `_restoreEmployee` | `onRestore` callback | ✅ |

## Artifacts

| Artifact | Status | Lines |
|----------|--------|-------|
| `lib/screens/admin/archived_employees_screen.dart` | ✅ Created | 256 |
| `lib/app.dart` route registration | ✅ Modified | +5 |

## Self-Check: PASSED

All files exist, all commits verified, route registered correctly.
