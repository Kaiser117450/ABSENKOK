---
gsd_state_version: 1.0
milestone: v4.0
milestone_name: Smart Attendance + Admin Dashboard
current_plan: "25-02"
status: in-progress
last_updated: "2026-03-19T08:22:00.000Z"
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 2
  completed_plans: 2
---

# STATE.md — Project Memory

## Current Status
- **Milestone:** v4.0 — Smart Attendance + Admin Dashboard
- **Phase:** 25 of 26 (Dashboard UI + Visualization) — in progress
- **Current Plan:** 25-02 (complete)
- **Last Updated:** 2026-03-19 — Phase 25 Plan 02 executed: StreakBadgeService + kiosk streak display

## Progress

```
v4.0 Smart Attendance + Admin Dashboard — IN PROGRESS
[█████░░░░░] 50% · 2/4 phases
```

- **Phase 23 progress:** 2/2 plans complete
- **Phase 24 progress:** 3/3 plans complete
- **Phase 25 progress:** 2/3 plans complete

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-18)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Phase 25 — Dashboard UI + Visualization

## What Was Shipped

### v3.1 (Released, 2026-03-18)
- Phase 20: Biometric Login
- Phase 21: Badge Color Picker
- Phase 22: Production Release (GitHub Release v3.1 with ABSENKOK-v3.1.0.apk)

### v3.0 (2026-03-13)
- Phase 17-19: Schedule Grid, Landing Website, Website Polish

### v2.0 (2026-03-12)
- Phase 13-16: Soft-archive, CSV Import, Kepala Gerai SQL, Live Activity Pill

### v1.1 (2026-03-05)
- Phase 1-12: Bug fixes, overlay pill, PDF/CSV reports, kiosk polish, admin UI, badges, logout resilience

## Key Decisions (Cumulative)

| # | Decision | Rationale |
|---|----------|-----------|
| 4 | SharedPreferences over FlutterSecureStorage | Eliminates ANR |
| 11 | two_dimensional_scrollables for grid | Official Flutter team package |
| 20 | Keep biometric_enabled on logout, clear remembered role | User shouldn't re-enable after re-login |
| 22 | Keep badge color storage as #RRGGBB strings | Allows visual picker UI without changing badge model |
| 23 | Phase 23 SQL must scope employees by `home_outlet_id` | The real employees schema has no `outlet_id` column |
| 24-01 | Time-based overtime threshold (8h default) instead of schedule-aware join | Avoids SQLite/Supabase cross-system join complexity |
| 24-01 | iconsax_flutter not in pubspec — use Material Icons.timer_outlined in OvertimeAlertRow | Package not available, Material Icon is functionally equivalent |
| 24-02 | Direct RPC call from MissingClockoutService (not AnalyticsService) | Wave 1 plan — avoids build-order dependency between services |
| 24-03 | isLate threshold is exclusive (>5 min, not >=) — exactly 5 min is not flagged | Matches plan spec: "late >5 minutes" |
| 24-03 | Pattern cache TTL 6 hours + compute() isolate for off-thread processing | Avoids blocking NFC scan (SMART-03) |
| 25-00 | Wave 0 stubs use pure flutter_test imports only — no app imports until implementation | Keeps stubs compilable before implementation classes exist |
| 25-02 | Exact match milestone check (== not >=) to avoid re-awarding streak badges | Prevents duplicate badge awards on subsequent days |

## Key Constraints
- Production database serving 4 outlets — NO destructive migrations
- Kotlin 1.9.25 — no upgrade (breaks nfc_manager)
- Android only — no iOS target

### Open Blockers
- None

## Accumulated Context
- NFC double-scan crash is a production bug — must fix before new features
- All dashboard aggregations must use Supabase RPC (server-side), not fetch-all-in-Dart
- Streak calculation must use existing noon-rule (noon-to-noon logical days)
- Pattern detection must run in background isolate, never block NFC scan
- service_role key must NEVER be in APK — Edge Function required for user creation
- fl_chart is the single new dependency for v4.0
- Dashboard and streak SQL must use `employees.home_outlet_id`, not the stale `outlet_id` placeholder from earlier notes
- Phase 23 production migrations applied: `phase_23_dashboard_foundation_20260318` and `phase_23_employee_streaks_rls_perf_20260318`
- Phase 24 production migrations applied: `phase_24_overtime_missing_rpc_20260318` and `phase_24_arrival_patterns_rpc_20260318`
- Attendance analytics widgets and pattern detection now rely on live RPCs in production
- Phase 24 Plan 02: MissingClockoutService (lib/services/missing_clockout_service.dart) checks every 30 min via get_missing_clockouts RPC, sends batched notification per outlet
- AttendanceRateCard and OvertimeAlertRow widgets created (lib/widgets/) — required for admin_dashboard_screen.dart to compile
- Phase 24 Plan 01 (24-01): AnalyticsService with 3 RPC methods (getAttendanceRates, getOvertimeFlags, getMissingClockouts), 2 SQL RPCs, 14 unit tests, spec-compliant widgets
- Phase 24 Plan 03 (24-03): PatternDetectionService with compute() isolate (first use), get_arrival_patterns RPC (PERCENTILE_CONT, HAVING >= 5), 14 unit tests, integrated into kiosk scan as fire-and-forget

## Database Safety Rules
- Sistem absensi SEDANG BERJALAN di production (4 gerai, karyawan aktif)
- **WAJIB konfirmasi ke user sebelum setiap perubahan database**
- Selalu jalankan migration additive (tidak merusak data yang ada)

## Supabase Project
- Project ID: `tmapxdftdhxovthgbhww`
- Region: ap-south-1 (Mumbai)
- Status: ACTIVE_HEALTHY

## File Locations
- Flutter project: `absensi apk/absensi_enakko_flutter/`
- Planning: `absensi apk/absensi_enakko_flutter/.planning/`
- Website project: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\`
- Codebase map: `.planning/codebase/`
- Milestones archive: `.planning/milestones/`
- SQL scripts: `sql/`
