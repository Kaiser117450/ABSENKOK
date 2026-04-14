# Phase 62: Schedule Gap Notices - Research

**Researched:** 2026-04-01
**Domain:** outlet-scoped schedule-gap follow-up notices on top of the recovered recap dataset and existing kepala gerai dashboard workflows
**Confidence:** HIGH

## Summary

Phase 62 should not touch recap semantics again. Phase 61 already restored truthful admin recap rows by exposing canonical merged `AttendancePolicyRecapDay` output plus explicit `fallbackRows` from `AdminPolicyRecapDatasetService`. Those fallback rows are the strongest local signal for the remaining problem Phase 62 needs to solve: attendance-backed employee/date combinations that still have no usable schedule and therefore need operational follow-up, not enforcement.

The best implementation direction is to keep the new behavior lightweight and dashboard-first:

1. build one pure outlet-scoped schedule-gap notice read model from the same recap compatibility signal Phase 61 now trusts, then
2. surface those notices in `AdminDashboardScreen` using the existing kepala gerai outlet lock, quick-action badge, and bottom-sheet follow-up pattern already used for `Belum Absen Pulang`.

This keeps the phase aligned with the roadmap wording:

- notices stay scoped to one outlet,
- the surface is operational and non-blocking,
- recap penalties, export colors, and pending semantics remain untouched.

**Primary recommendation:** plan Phase 62 in two waves:

1. extract a shared `ScheduleGapNoticeService` plus typed notice model that derives unresolved notice rows from the canonical compatibility dataset instead of raw-log heuristics, and
2. wire those notices into `AdminDashboardScreen` as a lightweight quick-action and detail sheet with a direct path to the existing shift scheduler, backed by focused service and widget tests.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| `SCHED-05` | Kepala gerai can see outlet-scoped notifications for employee/date schedule gaps that still need to be filled, and those notices do not block report generation or mutate payroll penalty semantics. | `AppProvider` and `AdminDashboardScreen` already enforce kepala gerai outlet scoping, while Phase 61 now exposes honest no-schedule compatibility rows that can drive notices without rewriting recap rules. |

## Existing Code Findings

### 1. Canonical no-schedule gap detection already exists in Phase 61's compatibility layer

- `lib/services/admin_policy_recap_dataset_service.dart` now returns:
  - `mergedRows`
  - `strictRows`
  - `fallbackRows`
  - `isCompatibilityMode`
- `fallbackRows` are synthesized only for attendance-backed missing strict keys and preserve honest `hadirTanpaJadwal` / incomplete semantics.
- `test/services/admin_policy_recap_dataset_service_test.dart` locks:
  - strict-wins merge behavior,
  - overnight-safe `TWENTY_FOUR_HOUR` logical dates, and
  - null schedule-only cutoff fields on fallback rows.

**Implication:** Phase 62 does not need a new raw attendance heuristic to find schedule gaps. The repo already has one trustworthy signal: compatibility rows produced when attendance exists but schedule-backed strict recap output does not.

### 2. The admin reports screen still owns too much recap-loading orchestration locally

- `lib/screens/admin/admin_reports_screen.dart` contains `_loadDailySummaryData()`, which currently:
  - fetches the selected outlet roster,
  - fetches strict recap rows through `AttendancePolicyRecapService`,
  - builds merged recap rows through `AdminPolicyRecapDatasetService`, and
  - stores `fallbackRows` for compatibility disclosure.
- The fetch/query boundary is still screen-local rather than shared with other admin surfaces.

**Implication:** If Phase 62 reads the same compatibility signal from the dashboard, it should extract or wrap this reporting fetch chain instead of re-implementing recap-loading logic directly inside `AdminDashboardScreen`.

### 3. `AdminDashboardScreen` already has the exact outlet-scoped follow-up UX pattern this phase needs

- `lib/screens/admin/admin_dashboard_screen.dart` already:
  - restricts kepala gerai data to `managedOutletId`,
  - shows outlet-specific quick actions,
  - renders a red/amber count badge on `Belum Pulang`, and
  - opens a detail bottom sheet with actionable rows and follow-up CTA.
- `_loadOpenShifts()` is outlet-scoped for both kepala gerai and full admin-with-selected-outlet.
- `_openShiftScheduler()` already routes to the shift scheduler using the active outlet context.

**Implication:** the lowest-risk notice surface is another dashboard notice affordance that mirrors the existing `Belum Pulang` pattern rather than introducing a new full screen or modifying recap UI again.

### 4. The schedule domain contract already exists and can support follow-up navigation

- `lib/models/shift_schedule.dart` provides `ShiftSlot`, `ScheduleEntry`, and `OutletSchedule`.
- `lib/screens/admin/shift_scheduler_screen.dart` already reads from `schedules` and `schedule_entries` for the selected outlet and date window.
- `lib/screens/admin/admin_employees_screen.dart` already queries `schedule_entries` directly for employee-related archive warnings.

**Implication:** Phase 62 should reuse the existing shift scheduler route as the notice resolution path. The notice surface should tell operators what is missing and send them to scheduling; it should not attempt inline schedule editing inside the dashboard.

### 5. There is a local-notification batching pattern, but Phase 62 should stay in-app first

- `lib/services/missing_clockout_service.dart` already demonstrates:
  - pure grouping/body-format helpers,
  - per-outlet notification batching, and
  - isolated test coverage in `test/services/missing_clockout_service_test.dart`.
- The roadmap language for Phase 62 says "notification saja", but the requirement is specifically kepala gerai-visible operational follow-up, not kiosk push behavior.

**Implication:** the service/test shape is reusable, but the actual Phase 62 scope should stay in the admin dashboard first. Device-local push/escalation workflows belong to future deferred work, not this milestone.

### 6. The repo has no explicit dashboard regression coverage for this new notice surface yet

- `test/screens/admin` covers recap, payroll matrix, chart dashboard, and central dashboard flows.
- There is no focused widget suite for `AdminDashboardScreen` notice chips/sheets today.

**Implication:** Phase 62 needs dedicated coverage for the new notice service and dashboard surface. Without it, the lightweight UI goal will be fragile and easy to regress.

## Standard Stack

### Core
| Library / System | Purpose | Why Standard |
|------------------|---------|--------------|
| `AttendancePolicyRecapService` | strict recap fetch boundary | Already provides the canonical RPC-backed strict recap rows for a date range and outlet. |
| `AdminPolicyRecapDatasetService` | compatibility-aware merged recap read model | Already exposes `fallbackRows`, which are the safest local schedule-gap signal. |
| `AdminDashboardScreen` | kepala gerai landing surface | Already owns outlet-scoped quick actions and follow-up bottom sheets. |
| `flutter_test` | service + widget regression coverage | Existing test framework for pure services and admin widgets. |

### Supporting
| Library / System | Purpose | When to Use |
|------------------|---------|-------------|
| `AppProvider` | kepala gerai outlet scoping | Reuse for full-admin selected-outlet behavior and kepala gerai outlet lock. |
| `ShiftSchedulerScreen` | schedule-filling destination | Use as the direct operator follow-up path from a notice CTA. |
| `ScheduleEntry` / `OutletSchedule` models | schedule contract language | Use if the notice model needs explicit date/employee scheduling references. |
| `MissingClockoutService` test shape | pure helper/service testing pattern | Reuse only as a structural pattern, not as the actual source of truth for schedule gaps. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Compatibility-driven notice read model | Raw `attendance_logs` diffed against `schedule_entries` only | Faster to sketch, but would duplicate logic and risk diverging from the recap semantics Phase 61 just stabilized. |
| Dashboard quick action + bottom sheet | Re-open `AdminReportsScreen` for yet another recap-side banner | Lower implementation effort initially, but it would blur the roadmap boundary and keep schedule follow-up coupled to recap semantics. |
| Scheduler deep-link resolution | Inline schedule editing on the dashboard | More "complete" on paper, but much higher UI and state risk for a phase explicitly scoped as lightweight and non-blocking. |

## Architecture Patterns

### Pattern 1: Use compatibility rows as the canonical notice input

**What:** derive schedule-gap notices from `fallbackRows` or explicitly compatibility-marked recap rows, not from unrelated dashboard heuristics.

**Why:** Phase 61 already proved these rows are the truthful representation of attendance days that still lack schedule-backed recap semantics.

### Pattern 2: Separate notice read model from the widget layer

**What:** introduce a pure typed notice model such as `ScheduleGapNoticeEntry` / `ScheduleGapNoticeGroup` plus a service that groups rows by outlet, employee, and logical date.

**Why:** the dashboard should only render notice counts and rows; grouping, copy decisions, and sort order should stay outside widget state.

### Pattern 3: Keep follow-up operational, not punitive

**What:** the notice model should expose missing employee/date combinations plus lightweight context like employee name, logical date, and maybe contract/outlet labels, but it must not compute new late/absence/pending statuses.

**Why:** the roadmap explicitly says this phase moves empty-schedule enforcement out of recap-breaking logic.

### Pattern 4: Reuse existing dashboard and scheduler affordances

**What:** add one more countable notice affordance beside `Belum Pulang`, then open a detail sheet with a "Buka Jadwal" action.

**Why:** this matches current operator muscle memory and minimizes UI churn on the kepala gerai landing surface.

### Pattern 5: Keep notices outlet-scoped and single-outlet-first

**What:** kepala gerai always sees only their managed outlet; full admins only see schedule-gap notices when a specific outlet is selected.

**Why:** Phase 62 is about outlet-scoped operational follow-up, not chain-wide reporting or escalation.

## Recommended Project Structure

```text
lib/models/
└── schedule_gap_notice.dart
   # typed notice row/group contract for employee/date follow-up

lib/services/
├── attendance_policy_recap_service.dart
├── admin_policy_recap_dataset_service.dart
└── schedule_gap_notice_service.dart
   # wraps recap fetch + compatibility grouping into dashboard-ready notice data

lib/screens/admin/
├── admin_dashboard_screen.dart
└── shift_scheduler_screen.dart

test/services/
├── admin_policy_recap_dataset_service_test.dart
└── schedule_gap_notice_service_test.dart

test/screens/admin/
└── admin_dashboard_schedule_gap_test.dart
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Schedule-gap detection | A second raw-log-only heuristic inside `AdminDashboardScreen` | `AttendancePolicyRecapService` + `AdminPolicyRecapDatasetService` + typed notice service | Phase 61 already solved the hard semantics problem. |
| Notice resolution | Inline schedule editor inside the dashboard sheet | Existing `ShiftSchedulerScreen` route | Lower-risk follow-up path that already owns scheduling state. |
| Outlet scoping | New kepala gerai permission branching | `AppProvider.isKepalaGerai` / `managedOutletId` | Existing role contract already gates outlet-scoped admin surfaces. |
| Badge/count formatting | Ad hoc string building in widgets | Pure service helpers, similar to `MissingClockoutService` | Easier to test and keep consistent. |

## Common Pitfalls

### Pitfall 1: Reopening recap semantics in Phase 62
**What goes wrong:** the implementation starts changing `pending`, penalty colors, or recap row copy again while trying to "help" operators fill schedules.
**How to avoid:** notices must read from the canonical compatibility signal and remain a separate operational follow-up surface.

### Pitfall 2: Duplicating the report screen's recap-loading logic in the dashboard
**What goes wrong:** `AdminDashboardScreen` gains its own strict/fallback merge code, which will drift the next time recap logic changes.
**How to avoid:** extract or wrap the existing service chain behind one dedicated notice service.

### Pitfall 3: Making the notice surface chain-wide by default
**What goes wrong:** full admin sees ambiguous counts spanning multiple outlets, and kepala gerai semantics stop matching the requirement.
**How to avoid:** only compute notices for a single resolved outlet at a time.

### Pitfall 4: Treating future roster completeness as the same problem
**What goes wrong:** the phase balloons into staffing-planning completeness instead of fixing attendance-backed missing schedules.
**How to avoid:** initial notice scope should be attendance-backed missing-schedule dates coming from compatibility rows, not generic future planning gaps.

### Pitfall 5: Shipping the UI without dedicated dashboard tests
**What goes wrong:** a small refactor to quick actions or bottom-sheet layout silently removes the notice count or CTA.
**How to avoid:** add one pure service suite and one focused dashboard widget suite as part of the phase.

## Open Questions

1. **What lookback window should the dashboard use when building schedule-gap notices?**
   - What we know: the dashboard has no date-range picker today.
   - Recommendation: start with a fixed recent operational window, such as the current month-to-date or the last 14 logical days, and keep the value explicit in the service contract so it can be tightened later without touching widget code.

2. **Should full admins see schedule-gap notices without selecting an outlet first?**
   - What we know: the requirement is outlet-scoped and the dashboard already supports an outlet filter.
   - Recommendation: no. Only show the notice surface when one outlet is resolved, while kepala gerai remains auto-scoped.

3. **Should a notice disappear only after refresh, or instantly after returning from the scheduler?**
   - What we know: the dashboard already has refresh flows and `_openShiftScheduler()` navigation.
   - Recommendation: refresh on return from scheduler and rebuild notices immediately; do not introduce persistent dismiss/acknowledge state in this phase.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` |
| Config file | `analysis_options.yaml` |
| Quick run command | `C:\flutter\bin\flutter.bat test test/services/schedule_gap_notice_service_test.dart test/screens/admin/admin_dashboard_schedule_gap_test.dart test/services/admin_policy_recap_dataset_service_test.dart` |
| Full suite command | `C:\flutter\bin\flutter.bat test` |
| Estimated runtime | ~150 seconds |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| `SCHED-05` | compatibility-backed employee/date gaps are grouped into outlet-scoped notices without mutating recap semantics | unit | `C:\flutter\bin\flutter.bat test test/services/schedule_gap_notice_service_test.dart` | ❌ Wave 0 |
| `SCHED-05` | dashboard shows a lightweight notice count and detail surface for the resolved outlet only | widget | `C:\flutter\bin\flutter.bat test test/screens/admin/admin_dashboard_schedule_gap_test.dart` | ❌ Wave 0 |
| `SCHED-05` | notice sourcing stays aligned with the existing compatibility dataset contract | unit / regression | `C:\flutter\bin\flutter.bat test test/services/admin_policy_recap_dataset_service_test.dart test/services/schedule_gap_notice_service_test.dart` | ✅ / ❌ Wave 0 |

### Sampling Rate
- **After every task commit:** run the task-local command plus the quick run command whenever the notice service or dashboard wiring changed
- **After every plan wave:** run `C:\flutter\bin\flutter.bat test`
- **Before `$gsd-verify-work`:** full suite must be green
- **Max feedback latency:** 150 seconds

### Wave 0 Gaps
- `test/services/schedule_gap_notice_service_test.dart` - pure grouping, outlet scoping, and non-punitive notice-copy coverage
- `test/screens/admin/admin_dashboard_schedule_gap_test.dart` - dashboard quick-action badge, detail sheet, and scheduler CTA coverage

## Sources

### Primary (HIGH confidence)
- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `.planning/STATE.md`
- `.planning/phases/60-rollout-payroll-acceptance/60-VERIFICATION.md`
- `.planning/phases/61-recap-semantics-recovery/61-RESEARCH.md`
- `lib/services/attendance_policy_recap_service.dart`
- `lib/services/admin_policy_recap_dataset_service.dart`
- `test/services/admin_policy_recap_dataset_service_test.dart`
- `lib/screens/admin/admin_reports_screen.dart`
- `lib/screens/admin/admin_dashboard_screen.dart`
- `lib/screens/admin/shift_scheduler_screen.dart`
- `lib/models/shift_schedule.dart`
- `lib/services/missing_clockout_service.dart`
- `test/services/missing_clockout_service_test.dart`

### Secondary (MEDIUM confidence)
- `lib/providers/app_provider.dart`
- `lib/screens/admin/admin_employees_screen.dart`
- `test/screens/admin/admin_reports_policy_recap_test.dart`
- `test/screens/admin/rekap_harian_test.dart`

## Metadata

**Confidence breakdown:**
- compatibility rows as schedule-gap signal: HIGH - the repo now treats them as the honest representation of attendance-backed no-schedule days
- dashboard as the correct notice host: HIGH - it already has outlet scoping, quick-action affordances, and follow-up bottom sheets
- default lookback window: MEDIUM - the dashboard has no date-range contract yet, so the exact time window is still a planning decision

**Research date:** 2026-04-01
**Valid until:** 2026-05-01
