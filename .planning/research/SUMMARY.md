# Project Research Summary

**Project:** Absensi Enakko (ABSENKOK) — v4.0 Smart Attendance + Admin Dashboard
**Domain:** NFC kiosk attendance management for restaurant chain (4 outlets, 14 employees)
**Researched:** 2026-03-18
**Confidence:** HIGH (existing codebase fully inspected, well-understood domain)

## Executive Summary

Absensi Enakko v4.0 adds smart analytics and admin workflow features to an existing, production-stable Flutter NFC kiosk app. The project is not a greenfield build — 90% of the infrastructure (NFC, Supabase, SQLite offline queue, 3-tier notifications, Riverpod state, badge system, PDF export) already exists and works. The research conclusion is clear: **v4.0 requires only one new Flutter dependency** (`fl_chart: ^0.70.2` for charts), one new Supabase Edge Function (`create-kepala-gerai`), and four new Supabase RPC functions for server-side aggregation. Every other feature is achievable with existing dependencies and pure Dart computation.

The recommended build approach is bottom-up: fix the production NFC double-scan bug first, lay the database foundation (RPC functions, streak cache table), build service layer logic without UI, then add UI components progressively. Dashboard charts come before notifications and onboarding because they are the highest-value visible feature for the product owner. The smart pattern detection algorithm must be pre-computed and cached — never computed synchronously during NFC scan handling — as NFC response time is a primary UX constraint.

The top risks are: (1) chart widget memory leaks on a 24/7 kiosk tablet, solvable with `AutomaticKeepAliveClientMixin` and `fl_chart`'s lightweight Canvas renderer; (2) accidental exposure of the Supabase `service_role` key during Kepala Gerai onboarding, which must be routed through a server-side Edge Function with JWT validation; and (3) streak calculation breaking for night-shift workers if the existing "noon rule" (noon-to-noon logical days) is not reused. All three risks have well-understood mitigations documented in PITFALLS.md.

## Key Findings

### Recommended Stack

The v4.0 additions are deliberately minimal. The existing stack (Flutter 3.41.1, Dart >=3.3.0, Supabase Flutter ^2.8.4, Riverpod, SQLite, `flutter_foreground_task`, `flutter_local_notifications`, `nfc_manager`, `share_plus`, `confetti`, badge system) handles virtually everything. Adding only `fl_chart` keeps the dependency surface small and avoids Kotlin version conflicts from Firebase packages.

**Core technologies (new additions only):**
- `fl_chart ^0.70.2`: Bar, line, and pie charts for attendance dashboard — chosen over Syncfusion (commercial license) and charts_flutter (archived by Google); pure Dart Canvas, lightweight for 24/7 kiosk
- Supabase Edge Function (`create-kepala-gerai`): Secure server-side user creation using `service_role` key — the only safe pattern for client-initiated Supabase Auth admin operations
- Supabase RPC functions (4 new): Server-side PostgreSQL aggregation for `get_attendance_rates`, `get_weekly_trend`, `get_outlet_comparison`, `update_employee_streak` — faster and more correct than fetching rows to Dart
- Firebase/FCM (conditional only): Only if admin personal-phone push is needed; default approach is local-only via existing `flutter_foreground_task` + `flutter_local_notifications`, which avoids Kotlin 1.9.25 compatibility risk entirely

### Expected Features

**Must have (table stakes):**
- NFC double-scan fix — production crash during employee NFC card registration; blocking issue for all new features
- Kepala Gerai onboarding via app — currently SQL-only; new outlet setup requires direct DB access, unscalable
- Attendance rate card widget — daily/weekly/monthly % with concrete counts ("Hadir 14/16 hari"), expected on any HR dashboard
- Missing clock-out notification — standard in every attendance system; admins cannot manage shift end without this
- Overtime tracking — restaurant labor cost control requires visibility of hours worked vs shift template duration

**Should have (differentiators):**
- Smart attendance pattern detection (BETA) — statistical median of historical check-in times per employee per day-of-week; proactive anomaly flagging vs reactive reporting
- Gamification streak — consecutive on-time attendance days with auto-badge awards at milestones (7, 30, 90 days); builds on existing badge system
- Mini chart dashboard (single-screen recap) — all key metrics visible without navigation; highest perceived value feature for kepala gerai ("rekap 1 layar")
- Cross-outlet attendance comparison — admin-only grouped bar chart; unique capability for chain operations vs single-outlet apps

**Defer to future:**
- Employee-facing mobile app — employees use shared kiosk; personal phones are out of scope
- ML-based absence prediction — insufficient data volume (89 logs currently); minimum ~200 employees + 6 months of data required
- Complex gamification (XP, levels, rewards shop) — over-engineering for 14 restaurant employees

### Architecture Approach

The architecture follows the existing codebase's singleton service pattern with `supabaseReady` guard, local `setState()` in screens, and flat file organization (no subdirectories in services/). Five new services (`AttendancePatternService`, `StreakService`, `ChartDataService`, `UserManagementService`, `MissingClockOutService`) are added alongside two new models and three new screens. The critical architectural decisions are: (a) all aggregations computed via Supabase RPC, not in Dart; (b) streak and pattern data cached in SQLite/`employee_streaks` table to survive reboots; (c) missing clock-out detection piggybacks on the existing foreground service timer; (d) chart data service returns plain Dart maps so the chart library remains swappable.

**Major components:**
1. `AttendancePatternService` — historical median check-in analysis per employee per day-of-week; runs in `Isolate.run()` on schedule (not per-scan); cached in SQLite `employee_patterns`
2. `StreakService` + `employee_streaks` table — consecutive on-time day calculation using noon-rule logical days, cached for dashboard and kiosk scan display; updated after successful sync
3. `ChartDataService` — wraps 4 Supabase RPC calls, returns plain Dart maps for fl_chart widgets in `ChartDashboardScreen`
4. `UserManagementService` + Edge Function `create-kepala-gerai` — server-side user creation with JWT validation, returns auto-generated credentials for WhatsApp sharing via existing `share_plus`
5. `MissingClockOutService` — 30-minute timer in existing `KioskBackgroundService`; batches notifications per outlet (1 notification for 3 missing employees, not 3 separate notifications)

### Critical Pitfalls

1. **Chart widget memory leak on 24/7 kiosk** — wrap `ChartDashboardScreen` with `AutomaticKeepAliveClientMixin`, set `swapAnimationDuration: Duration.zero`, run 4-hour stress test (100+ dashboard navigations) before shipping; consider disabling Impeller on Android if using Flutter 3.22+
2. **`service_role` key exposure via APK decompile** — never call `supabase.auth.admin.*` from Flutter; always route through Edge Function that validates caller JWT has `app_role: admin`; run `grep -r "service_role" lib/` as a mandatory pre-ship check
3. **Streak broken for night-shift workers (noon rule misalignment)** — streak calculator must use logical attendance days (noon-to-noon), not calendar midnight; write unit tests specifically for 22:00-06:00 shift workers before merging
4. **Pattern algorithm blocking NFC scan handler** — pre-compute and cache in SQLite on a schedule; NFC scan handler reads cached result (simple subtraction, <1ms); never trigger live computation during scan
5. **Supabase RLS silently blocking new dashboard queries** — write and test RLS policies in SQL editor FIRST before writing Dart queries; test as both `admin` and `kepala_gerai` roles from actual Flutter app (SQL editor bypasses RLS)

## Implications for Roadmap

Based on combined research, the dependency chain and risk profile strongly suggest a 4-phase structure. All three research files (FEATURES.md, ARCHITECTURE.md, PITFALLS.md) independently converge on this same ordering.

### Phase 1: Bug Fix + Database Foundation

**Rationale:** The NFC double-scan bug is a production blocker — it must ship before any new features. The Supabase RPC functions and `employee_streaks` table are prerequisites for all downstream phases; building them now keeps later phases unblocked. Zero UI work in this phase means zero regression risk to the existing app.

**Delivers:** Stable NFC card registration, 4 deployed RPC functions, `employee_streaks` table schema, composite index on `attendance_logs(scan_outlet_id, scanned_at)`

**Addresses:** NFC double-scan fix (P1 table stakes), database prerequisites for all dashboard features

**Avoids:** Adding new complexity while a production bug is open; deploying dashboard queries before RLS policies exist

**Research flag:** Standard patterns — NFC debounce lock is a well-understood pattern; Supabase SQL migrations are fully documented. No additional phase research needed.

### Phase 2: Core Service Layer + Analytics Foundation

**Rationale:** Services must exist before UI can consume them. `StreakService` and `AttendancePatternService` are independently testable without any UI. Building them in isolation validates the noon-rule alignment and median algorithm before committing to screen designs. Attendance rate card and overtime tracking are the data-query foundation that all later dashboard widgets consume.

**Delivers:** Working `StreakService`, `AttendancePatternService`, `ChartDataService`, `MissingClockOutService`; attendance rate card widget added to existing `AdminDashboardScreen`; overtime tracking logic; missing clock-out notifications via existing 3-tier notification infrastructure

**Addresses:** Attendance rate card (P1 must-have), overtime tracking (P2), missing clock-out notification (P1), smart pattern detection (P2 BETA)

**Avoids:** Streak noon-rule misalignment (must write unit tests for night-shift workers before merge); pattern algorithm blocking NFC (must use `Isolate.run()` from day one, not as an optimization); RLS blocking dashboard queries (RLS policies before Dart queries is mandatory process)

**Research flag:** Needs research during planning — the noon-rule logical day calculation and its interaction with the streak algorithm is the most nuanced domain logic. Locate and read the existing noon-rule implementation in the codebase before writing `StreakService` to avoid misalignment.

### Phase 3: Dashboard UI + Visualization

**Rationale:** Chart dashboard is the highest-value visible feature for the product owner ("rekap 1 layar"). It builds entirely on services from Phase 2 and the single new `fl_chart` dependency. Gamification streak display goes here because the streak leaderboard is a dashboard component. Cross-outlet comparison is admin-only and fits naturally as a section within the same screen.

**Delivers:** `ChartDashboardScreen` with attendance rate donut, weekly trend bar chart, streak leaderboard, overtime alerts, cross-outlet grouped bar chart; `StreakWidget` added to existing `AdminDashboardScreen`; GoRouter route for `/admin/chart-dashboard`; gamification streak milestones with `confetti` trigger

**Uses:** `fl_chart ^0.70.2` (the one new dependency), all Phase 2 services, existing GoRouter pattern and `AppColors`

**Implements:** `ChartDataService` -> `ChartDashboardScreen` data flow; stateless chart data aggregation pattern (plain Dart maps, no chart-library types in service layer)

**Avoids:** Chart memory leak — mandatory `AutomaticKeepAliveClientMixin` + 4-hour stress test before shipping; RLS for cross-outlet comparison correctly scoped (kepala_gerai sees only managed outlets)

**Research flag:** Standard patterns — fl_chart is well-documented with many Flutter examples. The `AutomaticKeepAliveClientMixin` pattern for navigation persistence is established Flutter practice. No additional phase research needed.

### Phase 4: Onboarding + Notification Polish

**Rationale:** Kepala Gerai onboarding via Edge Function is independent of all dashboard features and can be built last without blocking anything. The FCM vs local-only decision must be resolved before planning this phase; if local-only is confirmed sufficient, Firebase is not introduced at all. Notification batching (per-outlet, not per-employee) is a UX polish that improves admin experience without changing the core notification architecture.

**Delivers:** `KepalaGeraiOnboardingScreen` + `UserManagementService` + deployed Edge Function with JWT validation and rate limiting; notification batching ("3 karyawan belum pulang di Outlet A" not 3 individual alerts); optional FCM integration if remote push to admin personal phone is confirmed in scope

**Addresses:** Kepala Gerai onboarding (P1 must-have), push notification architecture (conditional)

**Avoids:** `service_role` key exposure — Edge Function required, `grep -r "service_role" lib/` must return zero hits; FCM breaking Kotlin 1.9.25 — evaluate Supabase Realtime vs FCM before committing to Firebase, pin versions explicitly if Firebase is chosen; notification ID collisions — reserve IDs 400-499 for any push notifications, document in `constants.dart`; Edge Function CORS misconfiguration — verify CORS headers work from kiosk tablet network before marking done

**Research flag:** Needs research during planning — Firebase/Kotlin 1.9.25 compatibility requires a concrete check against exact Firebase package versions if FCM is chosen. If the local-only approach satisfies requirements (kiosk tablet admin only, not personal phones), skip Firebase research entirely. Decision must be explicit before Phase 4 planning begins.

### Phase Ordering Rationale

- Production bug fix must precede all new features — shipping analytics over a broken registration flow is the wrong priority
- RPC functions before services before UI is the canonical bottom-up dependency chain; each layer is independently testable before the next is built
- Dashboard before onboarding because dashboard is the milestone deliverable ("rekap 1 layar") and onboarding is an independent utility with no downstream dependencies
- The existing codebase's single `AppProvider` StateNotifier + local `setState()` pattern must be preserved throughout — do not introduce new Riverpod providers per feature, which would create an inconsistent state management approach
- Gamification and cross-outlet comparison are bundled with the chart dashboard (Phase 3) rather than a separate phase because they are widgets within the same screen, not standalone features

### Research Flags

Phases needing deeper research during planning:
- **Phase 2 (noon rule + streak algorithm):** Read the existing noon-rule implementation in the codebase before writing `StreakService`. If the logical-day function is embedded in a widget or screen, extract it to a shared utility first. This is the highest-risk domain logic in the entire milestone.
- **Phase 4 (FCM vs local-only decision):** Firebase/Kotlin compatibility requires a concrete verification pass if FCM is chosen. Owner/PM must confirm whether notifications on admin personal phones (not kiosk tablet) are in scope — this single decision determines whether Firebase enters the project at all.

Phases with standard patterns (skip research-phase):
- **Phase 1 (NFC debounce + RPC deployment):** NFC state lock is a well-understood debounce pattern; Supabase SQL migrations are fully documented
- **Phase 3 (fl_chart dashboard):** fl_chart has thorough documentation; `AutomaticKeepAliveClientMixin` is standard Flutter pattern; no novel integrations

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | `fl_chart` version confirmed via pub.dev but exact latest stable should be verified with `flutter pub get` at implementation time. All other decisions use existing dependencies — HIGH. |
| Features | HIGH | Feature set derived from production system needs, competitor analysis, and existing codebase capabilities. Dependency chain fully mapped. |
| Architecture | HIGH | Existing codebase fully inspected (50+ Dart files, ~22,000 LOC). All patterns are derived from what already works in production. |
| Pitfalls | HIGH | Most pitfalls grounded in project history (ANR log, notification system, Kotlin constraint from CLAUDE.md) or documented Flutter/Supabase issues with referenced sources. |

**Overall confidence:** HIGH

### Gaps to Address

- **fl_chart exact stable version:** Research found both 0.70.2 and 1.1.0 on pub.dev with ambiguous stable status. Resolve with `flutter pub add fl_chart` at implementation start and pin whatever pub.dev marks as stable.
- **Noon-rule implementation location in codebase:** Research confirms the noon rule exists as a business rule but the exact Dart file/function is not identified. Must read codebase before writing `StreakService` to avoid creating a duplicate or misaligned implementation.
- **FCM vs local-only decision:** Research documents both paths clearly. Decision depends on whether kepala gerai need notifications on personal phones (out of scope for current product) or only on the kiosk tablet (local-only is sufficient and preferred). Owner/PM must confirm before Phase 4 planning.
- **Current RLS policy state for attendance_logs:** Existing policies were not audited during research. Phase 2 should begin with a policy audit in the Supabase dashboard before writing any new queries.
- **Edge Function CORS config for kiosk tablet network:** PITFALLS.md flags this as a common miss. Verify `supabase functions deploy` CORS headers work specifically from the restaurant outlet tablet network before marking Kepala Gerai onboarding complete.

## Sources

### Primary (HIGH confidence)
- Existing codebase inspection (50+ Dart files, ~22,000 LOC) — all patterns, constraints, and integration points
- Project CLAUDE.md — Kotlin 1.9.25 constraint, notification IDs (300/101), ANR history, noon rule, GoRouter guards
- [Supabase Auth Admin API](https://supabase.com/docs/reference/dart/auth-admin-createuser) — `service_role` requirement and Edge Function pattern
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions) — invocation from Flutter via `functions.invoke()`
- [Supabase API keys security](https://supabase.com/docs/guides/api/api-keys) — service_role exposure risk
- [Supabase Edge Functions invocation from Flutter](https://supabase.com/docs/reference/dart/functions-invoke) — call pattern
- [Supabase Discussion #20790](https://github.com/orgs/supabase/discussions/20790) — Edge Function as recommended pattern for client-initiated user creation

### Secondary (MEDIUM confidence)
- [fl_chart on pub.dev](https://pub.dev/packages/fl_chart) — versions 0.70.2 and 1.1.0 found; exact latest stable to be confirmed at implementation
- [Firebase Messaging on pub.dev](https://pub.dev/packages/firebase_messaging) — version ^15.2.3; Kotlin 1.9.25 compatibility needs pre-implementation verification
- [Flutter Impeller memory leak (issue #161861)](https://github.com/flutter/flutter/issues/161861) — chart memory leak on Android evidence
- Industry reports on gamification in restaurant attendance (OnShift, MindTheProduct) — 40% late arrival reduction claim, streak design patterns
- [HR Attendance Dashboard Examples (Bold BI)](https://www.boldbi.com/dashboard-examples/hr/attendance-dashboard/) — attendance dashboard UI patterns

### Tertiary (LOW confidence)
- [Timezone edge cases in gamification streaks](https://trophy.so/blog/handling-time-zones-gamification) — informs noon-rule streak concern; generalizable pattern, but app-specific rule requires codebase verification
- [Syncfusion chart memory leak forum](https://www.syncfusion.com/forums/173730/memory-leak-on-rebuilding-charts) — specific to Syncfusion, not fl_chart; used as evidence for the general chart-widget-lifecycle leak pattern

---
*Research completed: 2026-03-18*
*Ready for roadmap: yes*
