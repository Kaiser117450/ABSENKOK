---
gsd_state_version: 1.0
milestone: v6.0
milestone_name: Supabase Rollout Evidence
current_plan: Not started
status: completed
stopped_at: Completed 34-02-PLAN.md
last_updated: "2026-03-22T13:00:46.091Z"
last_activity: 2026-03-22 — Completed 32-02 (KioskDeviceCard + dashboard migration + bridge removal)
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 12
  completed_plans: 8
---

# STATE.md — Project Memory

## Current Position

Phase: 32 — Multi-Device Dashboard
Plan: 02 complete — Phase 32 done
Status: Complete
Last activity: 2026-03-22 — Completed 32-02 (KioskDeviceCard + dashboard migration + bridge removal)

## Current Status
- **Milestone:** v6.0 — Multi-Outlet & Multi-Device Control
- **Phase:** 31 — Device Identity Foundation (In Progress)
- **Current Plan:** Not started
- **Last Updated:** 2026-03-22 — Plan 32-02 complete

## Progress

```
v4.0 Smart Attendance + Admin Dashboard — COMPLETE
[██████████] 100% · 4/4 phases
```

- **Phase 23 progress:** 2/2 plans complete
- **Phase 24 progress:** 3/3 plans complete
- **Phase 25 progress:** 3/3 plans complete
- **Phase 26 progress:** 3/3 plans complete
- **Phase 28 progress:** 1/1 plans complete
- **Phase 29 progress:** 1/1 plans complete
- **Phase 30 progress:** 1/? plans complete

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-18)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Phase 31 — Device Identity Foundation

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
| 27-01 | battery_plus ^6.2.3 (not ^7.x) — v7 requires Kotlin 2.2.0 which breaks nfc_manager | Kotlin version constraint |
| 27-01 | All 5 heartbeat columns nullable with no DEFAULT | Existing production rows unaffected |
| 27-02 | HeartbeatService.stop() called first in KioskBackgroundService.stop() | Clean teardown order — stops heartbeat before other cleanup |
| 28-01 | Release-only Sentry DSN via kReleaseMode — empty DSN in dev | No crash traffic during development or test runs |
| 28-01 | Throttle fingerprint = operation:exceptionType (15-min window) | Prevents flood alerts from retry storms without losing distinct failure types |
| 29-01 | SlideTransition from top for sync strip (not AnimatedSwitcher) | Matches UI spec exactly — directional slide is more natural for a banner |
| 29-01 | Long-press only on brand logo column (not full header) | Intentionally hidden from employees — only operators who know will find it |
| 30-01 | Use withValues(alpha:) in new widgets — not withOpacity() | Matches Flutter 3.x deprecation guidance and existing codebase pattern |
| 31-01 | DeviceIdentityService as pure static class with SharedPreferences persistence | No instance state needed; uuid package already present at ^4.5.1 |
| 31-02 | Dual-write pattern: RPC primary (kiosk_devices) + outlets bridge until Phase 32 admin dashboard migration | Backward compatible; admin dashboard still reads outlets heartbeat columns |
| 31-02 | SECURITY DEFINER RPC (upsert_kiosk_heartbeat) for anon-key kiosk writes | Matches verify_kiosk_password pattern; anon key cannot direct-write with RLS |
| 32-01 | KioskDevice.isOnline uses <= 30 min threshold | Matches kiosk_health_card.dart existing logic — consistent across codebase |
| 32-01 | displayName falls back to "Kiosk {uuid[0:8]}" — 8-char prefix | UUID prefix is unique enough for admin display without cluttering UI |
| 32-02 | Archive failure is silent; device reappears on next load | Acceptable per UI-SPEC — avoids error dialog complexity for rare operation |
| 32-02 | HeartbeatService bridge write to outlets removed (Phase 32 done) | Admin dashboard reads kiosk_devices directly; dual-write overhead eliminated |
| 33-02 | CentralDashboardScreen uses injected loaders for testability | Widget tests run without Supabase; GoRouter drilldown tested via onOpenOutlet callback |
| 33-02 | Lihat Dashboard button disabled when no outlet selected | Prevents GoRouter push with empty outletId string — was a latent bug |

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
- Phase 27 context captured: heartbeat sends immediately on kiosk start, rolls every 15 minutes, retries on reconnect, uses SQLite pending+failed count, and stores app version as version+build
- Phase 27 Plan 02 (27-02): HeartbeatService created (lib/services/heartbeat_service.dart), wired into KioskBackgroundService start/stop lifecycle
- Phase 28 context captured: release-only Sentry, whole-app plus background coverage, benign Tag-lost-family NFC filtering, and deduped background reporting with outlet/device context
- Phase 29 Plan 01: KioskDiagnosticsScreen at /kiosk/diagnostics (battery, connectivity, version, pending/failed counts, Force Sync); amber sync indicator strip on idle screen slides in when pendingCount > 0; long-press logo opens diagnostics
- Phase 31 context captured: installation identity must persist across logout/setup, existing admin health surfaces must stay accurate during the schema transition, and one physical device keeps one identity even when reassigned between outlets
- Phase 31 Plan 02 (31-02): kiosk_devices table + upsert_kiosk_heartbeat SECURITY DEFINER RPC + HeartbeatService dual-write (RPC primary + outlets bridge). Migration file: sql/phase_31_kiosk_devices_20260320.sql — MUST be applied to Supabase before deploying updated APK
- Phase 32 Plan 01 (32-01): KioskDevice model (lib/models/kiosk_device.dart) with fromJson, isOnline (30-min threshold), displayName, copyWith; 8 unit tests passing; SQL migration sql/phase_32_device_mgmt_20260322.sql with set_device_nickname + archive_device SECURITY DEFINER RPCs — MUST be applied before Plan 02 UI deployment
- Phase 32 Plan 02 (32-02): KioskDeviceCard widget (lib/widgets/kiosk_device_card.dart); admin dashboard Status Kiosk section migrated from outlets to kiosk_devices; _showNicknameDialog + _showArchiveDialog with optimistic updates; realtime subscription on kiosk_devices_changes; HeartbeatService bridge write to outlets table removed
- Phase 34 rollout packet built (34-01, 2026-03-22): Three SQL migrations (phase_31_kiosk_devices_20260320.sql, phase_32_device_mgmt_20260322.sql, phase_33_central_dashboard_20260322.sql) verified correct in source code — all 5 function names confirmed present. Rollout order locked: 31 -> 32 -> 33. Operator checklist in 34-VALIDATION.md. Migrations awaiting operator application in Supabase SQL Editor before APK deployment.
- Phase 34 planning artifacts synchronized (34-02, 2026-03-22): HEALTH-02 marked complete based on implementation evidence from phases 31-32. Live heartbeat proof in kiosk_devices will be captured at first kiosk session on updated APK. Phases 35-36 acceptance verification will confirm E2E data flow.

## Session Continuity

**Last session:** 2026-03-22T13:00:46.085Z
**Stopped at:** Completed 34-02-PLAN.md
**Resume file:** None

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
