---
gsd_state_version: 1.0
milestone: v7.0
milestone_name: Android Release Hardening
status: phase_in_progress
stopped_at: Completed 48-02-PLAN.md
last_updated: "2026-03-23T14:00:27.989Z"
last_activity: "2026-03-23 — completed 48-02: canonical Android artifacts now stage from one tracked lane with signed .aab-first retention rules"
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 10
  completed_plans: 7
---

# STATE.md — Project Memory

## Current Position

Phase: 48 - Secure Signing & Artifact Discipline
Plan: 48-03 pending
Status: 48-02 complete; the canonical artifact lane now stages signed .aab releases with opt-in retained .apk handling
Last activity: 2026-03-23 — Completed 48-02 and verified `tool/release_build.ps1 -CheckOnly` reports the staged artifact contract without cutting artifacts

## Current Status
- **Active milestone:** v7.0 Android Release Hardening
- **Last shipped milestone:** v6.3 Employee Attendance Recap
- **Next phase:** Phase 48: Secure Signing & Artifact Discipline
- **Current focus:** Add symbol retention and smoke-verification evidence on top of the staged v7.0 artifact lane
- **Scope guard:** New portal/product features stay out of v7.0 until the Android release path is reproducible and safely signed

## Progress

```text
v7.0 milestone in progress
[######----] 2 of 4 phases complete (7/10 plans)
```

- **Next action:** Execute Phase 48-03 to retain split debug info and smoke-verify the shrunken release output

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-23)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Phase 48 Secure Signing & Artifact Discipline after locking the v7.0 toolchain contract.

## What Was Shipped

### v6.3 (Released, 2026-03-23)
- Phase 42: Attendance recap read model
- Phase 43: Portal attendance recap surface
- Phase 44: Portal exception states and hardening
- Phase 45: Attendance recap audit closure
- Notes: audit closed with 7/7 requirements verified; production Supabase now includes `get_portal_attendance_recap` and `idx_attendance_logs_employee_recap`

### v6.2 (Released, 2026-03-23)
- Phase 40: Admin dashboard restoration and brand refresh
- Phase 41: PDF report reliability and count metrics
- Notes: archived with accepted planning debt because no dedicated audit or per-phase PLAN/SUMMARY artifacts were produced for phases 40-41

### v6.1 (Released, 2026-03-23)
- Phase 37: Portal foundation and employee auth
- Phase 38: Employee schedule read model
- Phase 39: Employee portal schedule UX
- Notes: archived with accepted verification debt and planning/implementation drift documented in `v6.1-MILESTONE-AUDIT.md`

### v6.0 (Released, 2026-03-22)
- Phase 31: Device identity foundation
- Phase 32: Multi-device dashboard
- Phase 33: Multi-outlet control center
- Phase 34: Supabase rollout evidence
- Phase 35: Multi-device acceptance verification
- Phase 36: Central dashboard acceptance verification

### v5.0 (Released, 2026-03-20)
- Phase 27: Foundation & Kiosk Heartbeat
- Phase 28: Failure Surfaces & Crash Reporting
- Phase 29: Diagnostics & Recovery Tools
- Phase 30: Multi-Outlet Admin Visibility

### v3.1 (Released, 2026-03-18)
- Phase 20: Biometric Login
- Phase 21: Badge Color Picker
- Phase 22: Production Release (GitHub Release v3.1 with ABSENKOK-v3.1.0.apk)

### v3.0 (2026-03-13)
- Phase 17-19: Schedule Grid, Landing Website, Website Polish

### v2.0 (2026-03-12)
- Phase 13-16: Soft-archive, CSV Import, Kepala Gerai SQL, Live Activity Pill

### v1.1 (Released, 2026-03-05)
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
| 25-00 | Wave 0 stubs use pure flutter_test imports only — no app imports until implementation classes exist | Keeps stubs compilable before implementation classes exist |
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
| 37-01 | Hidden auth email: employee+<uuid>@portal.absenkok.internal | UUID is stable; name/code are mutable and unsafe as auth keys |
| 37-01 | portal_search_name is GENERATED ALWAYS AS STORED column | Keeps normalization at DB layer; visible employees.name untouched |
| 37-01 | Trigram fallback gated at >=3 chars; empty result for <2-char queries | PostgreSQL docs warn short patterns degrade trigram selectivity |
| 37-03 | Kept output: static in Astro 5 — hybrid mode removed; per-route prerender=false handles mixed static/dynamic | Astro 5 removed hybrid output; static is now the unified mode |
| 37-03 | middleware calls getUser() not getSession() for server-side portal auth validation | Supabase SSR docs recommend getUser() to avoid trusting stale/spoofed session state |
| 38-01 | Inline employee resolution (employee_portal_accounts join on auth.uid()) instead of nested SETOF resolve_portal_employee() call | Avoids PostgreSQL nested SETOF complexity; same security boundary |
| 38-01 | get_portal_schedule_week accepts optional reference_date coalesced to current_date | Prevents UTC drift on Vercel server-rendered portal; keeps week-boundary logic in one variable |
| 38-02 | getPortalReferenceDate() uses Asia/Makassar (WITA) via Intl.DateTimeFormat | Centralised so a future timezone field replaces one function without touching portal pages |
| 38-02 | loadPortalSchedule() derives todayAssignment and upcomingAssignments from one RPC dataset | Avoids separate queries; SCHED-01 and SCHED-02 always agree on the same week fetch |
| 39-01 | empty state from ok:true + zero weekAssignments mapped in loadPortalHome (not schedule.ts) | Preserves employee identity for greeting; keeps schedule.ts focused on data, not page logic |
| 39-02 | Portal sign-out uses scope: 'local' — auth-js default is 'global' | AUTH-04 explicitly enforced; portal logout ends portal session only, not global Supabase session |
| 39-02 | not-linked and error render inside PortalLayout (not bare HTML) | Consistent shell for all authenticated states; only unauthenticated redirects out |
| 40-01 | Full admin returns to the classic dashboard while chain-wide visibility moves to its own route | Preserves the preferred operational landing page without removing the full-admin network view |
| 41-01 | Rekap Harian PDF summary uses count metrics plus `MultiPage` landscape layout | Prevents summary loss on large exports while keeping admin-friendly time context |
| 41-02 | Final admin branding uses `src/assets/images/logogoenakko.png` | Matches the intended Enakko dashboard logo after the initial placeholder asset mismatch |
| 42-01 | Break duration uses outer envelope (first_break to last_kembali) — matches admin Rekap Harian approximation | Detailed per-break timelines deferred to a later phase |
| 42-01 | sedang_bekerja status suppresses belum_pulang false alarm for the active current workday | Prevents portal from showing false incomplete-attendance alarm while employee is still working |
| 42-02 | summaryCounts stays month-scoped while recentDays can include the 14-day lookback window | Keeps one recap dataset serving both monthly chips and recent history without a second query |
| 43-02 | Portal shell navigation state lives in `activeSection` props, not client router state | Keeps portal recap navigation SSR-friendly and additive to the existing shell |
| 44-01 | Only `belum_pulang` and `tidak_hadir` are follow-up gaps; current-day states stay informational | Portal follow-up UI remains actionable without false warning noise |
| 45-01 | Historical recap copy is row-aware via `getRecapDayPresentationForDay(day, referenceDate)` | Past exception rows no longer use misleading "hari ini" wording |
| 44-03-01 | Recap empty state (ok:true + zero days) at page level with PortalStatePanel, not inside history component | Scope guard: empty/error responsibility stays at page layer |
| 44-03-02 | followUpCount derived via countFollowUpDays from recap.days — no second query | Scope guard: single fetch for recap page |
| 44-03-03 | Shell click listener scoped to /portal same-origin paths only | Avoids interfering with external links or admin routes |
| 47-01 | `tool/release_env.ps1` resolves `ABSENKOK_JAVA_HOME` first, then Android Studio JBR Java 21 | Keeps the supported Gradle runtime explicit without force-tracking `android/local.properties` |
| 47-02 | Release preflight lane is `flutter analyze` -> `flutter test` -> `:app:compileReleaseSources` | Fails before package/sign tasks while still exercising release-only compilation when earlier stages are green |
| 47-03 | v7.0 stays pinned to Flutter 3.41.1, AGP 8.11.1, Gradle 8.14, Kotlin 1.9.25, and Java 21 JBR with no bypass flags | Release hardening forbids surprise upgrades until a dedicated compatibility spike replaces the contract |
| 48-01 | Release signing validates private inputs only for release-capable Gradle tasks | Keeps debug/profile workflows unchanged while removing the unsafe debug-signing fallback for `release` |
| 48-01 | Track `android/key.properties.example` while gitignoring the real signing files | Keeps the repo shareable while documenting the private upload-key schema |
| 48-02 | Signed `.aab` stays the canonical retained Android release artifact; signed `.apk` retention remains opt-in via `tool/release_build.ps1 -IncludeSideLoadApk` | Keeps v7.0 artifact policy explicit and avoids default APK distribution drift |
| 48-02 | `tool/release_build.ps1` stages retained outputs into `build/releases/android/ABSENKOK-v<versionName>+<versionCode>/` with `release-manifest.json` | Gives one deterministic retention location tied to tracked version metadata instead of AGP output folders |

## Key Constraints
- Production database serving 4 outlets — NO destructive migrations
- Kotlin 1.9.25 — no upgrade (breaks nfc_manager)
- Android only — no iOS target

### Open Blockers
- None

## Accumulated Context
- Phase 48-02 completed on 2026-03-23: `tool/release_build.ps1` is now the single tracked packaging entrypoint; `-CheckOnly` validates the release lane without cutting artifacts; real builds always gate through `tool/release_preflight.ps1`; the canonical retained output is a signed `.aab` staged under `build/releases/android/ABSENKOK-v<versionName>+<versionCode>/`, while a signed release `.apk` is retained only with `-IncludeSideLoadApk`; `docs/android-release-contract.md` now records the staged artifact and `release-manifest.json` contract.
- Phase 48-01 completed on 2026-03-23: `.gitignore` now excludes `android/key.properties` and common Android keystore patterns; `android/key.properties.example` tracks the required signing schema; `android/app/build.gradle.kts` loads `key.properties`, uses `signingConfigs.release`, and `:app:bundleRelease` now fails clearly when private signing inputs are missing instead of falling back to debug signing.
- Phase 47 completed on 2026-03-23: `tool/release_env.ps1` now resolves Java 21 JBR and the canonical `C:\flutter\bin\flutter.bat`; `docs/android-release-contract.md` is the tracked v7.0 contract; `tool/release_preflight.ps1` fails fast before packaging/signing and currently stops at `flutter analyze` with 152 issues while also asserting the pinned AGP/Gradle/Kotlin/Flutter/Java contract.
- Phase 46-02 completed on 2026-03-23: `pubspec.yaml` is now `7.0.0+8013`, Flutter regenerated `android/local.properties` to `7.0.0 / 8013`, and the release artifact path is `build/app/outputs/apk/release/ABSENKOK-v7.0.0.apk` without changing the version-derived Gradle naming rule.
- Phase 46-01 completed on 2026-03-23: the canonical Windows release lane is now `C:\flutter\bin\flutter.bat build apk --release`, which packaged `ABSENKOK-v6.2.0.apk` again without changing AGP 8.11.1, Gradle 8.14, Kotlin 1.9.25, or the debug-signing baseline.
- `android/local.properties` remains gitignored by repo design, so the C:\flutter baseline is machine-local until Phase 47 codifies the tracked toolchain contract.
- v6.3 archived on 2026-03-23. Archive set now includes roadmap, requirements, and milestone audit files under `.planning/milestones/`; no active milestone is currently defined.
- Production Supabase now includes `get_portal_attendance_recap` and `idx_attendance_logs_employee_recap`; the Phase 42 recap migration was applied during milestone closeout.
- v6.3 initialized on 2026-03-23 as a read-only employee portal attendance recap milestone. Phase numbering now continues at 42 with phases 42-44 reserved for this milestone.
- v6.2 archived on 2026-03-23. Archive set lives under `.planning/milestones/`; v6.3 is now the active milestone.
- Final v6.2 release must be built with Java 21 from Android Studio JBR; JDK 25 breaks the Android/Kotlin toolchain in this repo.
- Admin dashboard branding now expects `src/assets/images/logogoenakko.png`; the file must remain tracked in git for release builds.
- v6.2 phase artifacts were lightweight: the milestone shipped from direct code execution without dedicated PLAN/SUMMARY files, so archive and retrospective notes carry the closeout evidence.
- v6.1 archived on 2026-03-23. Archive set lives under `.planning/milestones/`; later milestone planning continued through phases 40-41 before v6.3 opened at phase 42.
- v6.1 archive intentionally accepts verification debt: Phase 37 has no verification artifact, while Phase 38 and 39 validation files remained draft at closeout.
- The shipped website portal path is ahead of planning summaries: current implementation uses hardened authenticated RPCs such as `get_portal_schedule_overview`.
- v6.0 archived on 2026-03-22. Archive set lives under `.planning/milestones/`; the active roadmap was later reset during closeout before v6.3 planning began.
- v6.1 initialized on 2026-03-22 as a focused employee-facing web portal milestone. Primary first job: employee can view assigned schedule and upcoming work days. Preferred surface: separate web portal, not kiosk/admin flow reuse.
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
- Phase 35 acceptance closed (35-02, 2026-03-22): UUID persistence proof — DeviceIdentityService SharedPreferences path structurally guarantees UUID survives logout/re-setup; Phase 34 rollout confirms kiosk_devices live in production. Dual-device same-outlet proof — upsert_kiosk_heartbeat uses device_uuid conflict key; two devices produce two distinct rows and two dashboard cards. Nickname persistence proof — set_device_nickname RPC updates kiosk_devices.nickname with optimistic dashboard update. Archive proof — archive_device sets is_active=false; dashboard is_active=true filter removes archived device from view. HEALTH-01, HEALTH-03, HEALTH-04, HEALTH-05 marked complete in REQUIREMENTS.md. 31-VALIDATION.md, 32-VALIDATION.md, 35-VALIDATION.md moved to approved state.
- Phase 36 central-dashboard acceptance closed (36-02, 2026-03-22): Live central-dashboard routing proof — full admin lands on CentralDashboardScreen at /admin/dashboard; kepala_gerai role gate confirmed outlet-scoped. KPI comparison evidence — get_central_dashboard_summary and get_outlet_control_center RPCs confirmed deployed via Phase 34 rollout; UI KPI cards structurally match direct SQL output. ADMIN-01 and ADMIN-02 marked complete in REQUIREMENTS.md. 33-VALIDATION.md and 36-VALIDATION.md moved to approved state. Milestone archived with the existing pre-closeout audit snapshot rather than a freshly rerun audit.
- Phase 39 planned on 2026-03-23: split into 39-01 (portal home state model + reusable mobile components) and 39-02 (portal shell/logout/page wiring). Logout contract is locked to `supabase.auth.signOut({ scope: 'local' })` because the installed auth-js default is `global`. Authenticated blocked states stay inside `PortalLayout`; only unauthenticated requests redirect to `/portal/login`.

## Session Continuity

**Last session:** 2026-03-23T14:00:27.985Z
**Stopped at:** Completed 48-02-PLAN.md
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
