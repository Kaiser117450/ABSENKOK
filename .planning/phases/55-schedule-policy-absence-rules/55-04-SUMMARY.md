# Phase 55 Plan 04 Summary

Upgraded the Admin Reports Rekap Harian tab to consume the Phase 55 policy recap contract instead of relying on raw daily-summary heuristics alone. The screen now exposes reusable policy badges, fast filter chips, and operational reason copy while keeping the Per Scan tab and export behavior intact.

## What changed

- Added `lib/widgets/attendance_policy_badge.dart` with one reusable `AttendancePolicyBadge` for:
  - `Terlambat`
  - `Break-first`
  - `Kandidat break-first`
  - `Belum masuk`
  - `Tidak hadir`
  - `Hadir tanpa jadwal`
  - leave states such as `Sakit`, `Izin`, `Cuti`, and `Libur`
- Added `test/widgets/attendance_policy_badge_test.dart` to cover normal late, candidate/confirmed break-first, no-show, and current-day `Belum masuk` states.
- Updated `lib/screens/admin/admin_reports_screen.dart` so the Rekap Harian tab:
  - calls `AttendancePolicyRecapService`
  - renders `AttendancePolicyBadge`
  - exposes the exact filter set `Semua`, `Terlambat`, `Terlambat Normal`, `Break-first`, `Kandidat Break-first`, `Belum Masuk`, `Tidak Hadir`, and `Hadir Tanpa Jadwal`
  - shows policy context for band, required hours, lateness cutoff, and break-first deadline
  - shows operational reason copy for `belum_masuk`, `tidak_hadir`, candidate break-first, and late arrivals
  - keeps Per Scan pagination and CSV/PDF export behavior unchanged

## Behavior covered

- `Terlambat Normal` only matches rows with `late_kind = normal`.
- `Break-first` and `Kandidat Break-first` render with distinct labels and tones.
- Current-day rows use the exact reason copy `Hari kerja masih berjalan dan belum ada scan masuk.`
- Closed-day no-show rows use the exact reason copy `Tidak ada scan pada hari kerja yang sudah selesai.`
- Candidate break-first rows use the exact reason copy `Masih dalam jendela break-first, menunggu konfirmasi.`
- Unscheduled present rows use the exact reason copy `Hadir tanpa jadwal`.
- Rekap Harian now shows explicit empty states when:
  - no outlet is selected for policy computation
  - the policy recap SQL rollout is not yet available for the selected outlet
  - the active filter returns no matching rows

## Verification

- Passed:
  - `C:\flutter\bin\flutter.bat test test/widgets/attendance_policy_badge_test.dart`
  - `C:\flutter\bin\flutter.bat analyze lib/screens/admin/admin_reports_screen.dart lib/widgets/attendance_policy_badge.dart lib/services/attendance_policy_recap_service.dart test/widgets/attendance_policy_badge_test.dart`

## Files changed

- `lib/screens/admin/admin_reports_screen.dart`
- `lib/widgets/attendance_policy_badge.dart`
- `test/widgets/attendance_policy_badge_test.dart`
- `.planning/phases/55-schedule-policy-absence-rules/55-04-SUMMARY.md`
