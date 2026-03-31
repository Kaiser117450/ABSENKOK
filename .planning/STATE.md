---
gsd_state_version: 1.0
milestone: v8.1
milestone_name: Reporting Recovery & Schedule Gap Notifications
status: roadmap_defined
stopped_at: Roadmap approved for milestone v8.1
last_updated: "2026-03-31T19:50:09+08:00"
last_activity: 2026-03-31
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# STATE.md — Project Memory

## Current Position

Milestone: v8.1 — ACTIVE
Phase: 61 — Ready to start
Plan: —
Status: Roadmap approved; ready for phase discussion
Last activity: 2026-03-31 — Roadmap v8.1 approved

## Current Status

- **Active milestone:** v8.1 Reporting Recovery & Schedule Gap Notifications
- **Last shipped milestone:** v8.0 Strict Attendance & Payroll Reporting
- **Next phase:** Phase 61 Recap Semantics Recovery
- **Current focus:** Restore trusted Rekap Harian behavior for no-schedule legacy data while preserving strict contract-aware break-first and excessive-break reporting
- **Notification focus:** Empty schedule days should become kepala gerai follow-up notices, not recap-breaking logic
- **Rollout guard:** Database changes remain additive only and still require explicit user confirmation before any production migration is applied
- **Reporting guard:** Salary-facing spreadsheet/PDF output must stay aligned with the corrected recap semantics

## Progress

```text
v8.1 roadmap approved; implementation has not started
[░░░░░░░░░░░░░░░░░░] 0 of 3 phases complete (0 plans defined)
```

- **Next action:** Start Phase 61 with `$gsd-discuss-phase 61`.

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-31)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Phase 61 will recover recap semantics so legacy no-schedule days stay usable without losing strict contract-aware break evaluation or export fidelity.

## What Was Shipped

### v8.0 (Released, 2026-03-31)

- Phase 54: Workforce contract and outlet mode foundation
- Phase 55: Schedule policy and absence rules
- Phase 56: Server-time scan authority
- Phase 57: Strict recap evaluation engine
- Phase 58: Payroll matrix and spreadsheet export
- Phase 58.1: Schedule UX polish and legacy payroll fallback
- Phase 59: PDF and portal parity
- Phase 60: Rollout and payroll acceptance
- Notes: audit passed at `v8.0-MILESTONE-AUDIT.md`; remaining work is the manual operator rollout review before payroll use

### v7.1 (Released, 2026-03-25)

- Phase 50: Kiosk device boundary hardening
- Phase 51: Admin session trust hardening
- Phase 52: Portal surface minimization
- Phase 53: Security rollout and acceptance
- Notes: milestone archived after locking the accepted passwordless portal risk boundary and additive rollout checklist

### v7.0 (Released, 2026-03-25)

- Phase 46: Release baseline recovery
- Phase 47: Toolchain contract and preflight gates
- Phase 48: Secure signing and artifact discipline
- Phase 48.1: APK-first release artifact alignment
- Phase 49: Release runbook and acceptance
- Notes: archived without a dedicated audit by user choice; final published asset is the obfuscated smoke-verified `ABSENKOK-v7.0.0+8013.apk` on GitHub Release `v7.0.0`

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
| 48-03 | Keep `--split-debug-info` requested by default while leaving `--obfuscate` off for v7.0, and record when Flutter emits no symbol files | Preserves the debug-artifact intent without widening rollout risk or fabricating symbol retention |
| 48-03 | `release-manifest.json` records `apkRetentionState: smoke-only` when smoke verification needs an APK but side-load retention was not requested | Keeps smoke-install evidence explicit without quietly turning every APK into a distribution artifact |
| 48.1-01 | Canonical retained Android release artifact is the signed optimized `.apk`; `.aab` retention is opt-in via `tool/release_build.ps1 -IncludeAppBundle` | Restores the intended v7.0 shipped product before Phase 49 locks the operator contract |
| 48.1-02 | `tool/release_build.ps1` must remain truthful in Windows PowerShell 5.1; smoke verification installs the canonical retained APK and records evidence beside it | Matches the documented operator shell and removes stale smoke-only side-path semantics |
| 52-01 | Protected `/portal` requests now redirect before `next()` while still attaching refreshed Supabase SSR cookies | Keeps middleware as the single verified protected-route gate |
| 52-02 | Public chooser search now requires 3 normalized characters, caps results at 5, rejects 64+ character input, and returns only the rendered chooser DTO | Reduces enumeration-friendly exposure without removing passwordless card selection |
| 52-03 | Existing hidden portal auth users are reusable only when confirmed `employee_portal` metadata matches `employee_id`; recovery SQL skips conflicting ownership instead of repointing mappings | Recovery correctness now fails closed instead of trusting weak hidden-email inference |

## Key Constraints

- Production database serving 4 outlets — NO destructive migrations
- Kotlin 1.9.25 — no upgrade (breaks nfc_manager)
- Android only — no iOS target

### Open Blockers

- None currently. Any future v8.0 production migration still needs explicit user approval before execution.

## Accumulated Context

### Roadmap Evolution

- Phase 58.1 inserted after Phase 58: urgent fixes for a dismissible/minimizable schedule-rule notice, readable shift-picker button text, and a legacy payroll fallback that derives required hours from employee contract when `schedule_entries` are missing so historical reports do not render empty (URGENT)
- Phase 58.1 planned on 2026-03-28: the fallback path now explicitly requires overnight-safe logical-day grouping for `TWENTY_FOUR_HOUR` legacy logs, plus mixed strict+fallback recap/export parity coverage before execution.
- Phase 58.1 completed on 2026-03-28: `ShiftSchedulerScreen` now lets admins minimize or dismiss the schedule-rule notice, and the assigned-entry bottom sheet uses explicit dark chip labels so shift and required-hours options stay readable in light and disabled states.
- Phase 58.1 completed on 2026-03-28: `LegacyPayrollRecapFallbackService` now synthesizes contract-aware no-schedule recap rows from raw attendance without fabricating late or absence states, and `AdminReportsScreen` merges those fallback rows into the same payroll matrix/spreadsheet dataset with a visible compatibility note.

- Phase 54 context captured on 2026-03-26: existing active employees default to `FULLTIME`, while new employee forms must require a contract but open with `PARTTIME` preselected.
- Phase 54 context captured on 2026-03-26: outlets default to `NORMAL`, outlet mode is admin-only, and the value must be visible in both the outlet sheet and outlet list.
- Phase 54 context captured on 2026-03-26: employee contract must surface as a badge plus filter in the employee list, remain editable by kepala gerai within their outlet scope, and stay visible in archived employee history.
- Phase 54 context captured on 2026-03-26: batch CSV import must require a contract column, normalize aliases into canonical `FULLTIME` / `PARTTIME`, reject legacy templates without the field, and update the downloadable template accordingly.
- Phase 54 completed on 2026-03-27: employee contract now persists across active employee forms, archived history, and CSV onboarding, while outlet operating mode now persists through the admin outlet surfaces.
- Phase 54 completed on 2026-03-27: SQL migration `sql/phase_54_workforce_contract_outlet_mode_20260326.sql` is ready but still awaits explicit user approval before production application.
- Phase 55 context captured on 2026-03-26: scheduled workdays must show `band + required hours`, required hours default from employee contract but stay editable, quick chips remain the primary assignment interaction, and exact clock ranges survive only as small hints.
- Phase 55 context captured on 2026-03-26: lateness cutoffs are `07:00` for pagi, `10:00` for siang, and `15:00` for sore; early scans stay valid; late arrivals remain present with a late tag; and admin needs separate audit filters for normal late vs break-first late.
- Phase 55 context captured on 2026-03-26: break-first rules apply to any shift only when there are no `break` / `kembali` logs; `PARTTIME` gets a 1-hour break-first window after the cutoff and `FULLTIME` gets a 2-hour window; saying "no" to break-first falls back to normal late.
- Phase 55 context captured on 2026-03-26: same-day zero-log scheduled rows stay `belum_masuk`, `tidak_hadir` is finalized only after the logical workday ends, leave states always override absence, and late-arriving valid logs or retroactive leave corrections automatically replace `tidak_hadir`.
- Phase 55 context captured on 2026-03-26: kepala gerai keeps the weekly grid, bulk assign stays with a short review step, the familiar 2-shift / 3-shift templates stay in place, and policy info should live in header/detail summaries instead of every schedule cell.
- Phase 55 deferred idea noted on 2026-03-26: per-schedule role labels (`Housekeeping`, `Kasir`, `Assambler`, `Kitchen`) plus PDF export visibility belong to a future phase, not the Phase 55 policy rewrite.
- Phase 55 Plan 01 completed on 2026-03-27: `ShiftBand`, `SchedulePolicyService`, and `ShiftSlot` now carry band-first policy metadata while preserving legacy clock hints for backward compatibility.
- Phase 55 Plan 01 completed on 2026-03-27: additive SQL patch `sql/phase_55_schedule_policy_foundation_20260326.sql` backfills active `schedule_entries.shift_slot` JSON with band, required-hours, lateness, and break-first keys but still awaits explicit user-approved production application.
- Phase 56 context captured on 2026-03-26: eligible first scans should expose an extra `Istirahat Dulu` path, still require a short confirmation, ask every eligible time, and confirm success with a hint that the next expected tap is `Selesai Istirahat`.
- Phase 56 context captured on 2026-03-26: if server time is unavailable, scans stay operational for cached employees by queueing pending events locally, syncing automatically later, and flagging suspicious reconciliations for admin review instead of silently rewriting history.
- Phase 56 context captured on 2026-03-26: live server-confirmed scans should show the authoritative WITA time, queued scans should use a visibly distinct success state, wording should stay human-first, and the current fast auto-close plus idle pending badge/banner remains the persistent follow-up signal.
- Phase 56 deferred idea noted on 2026-03-26: richer admin audit labeling for break-first-late vs normal late can stay flexible for planning, and any supervisor-only offline override remains a separate future capability.
- Phase 50 completed on 2026-03-25: kiosk activation now binds the persistent device UUID through `activate_kiosk_device`, and heartbeat writes only refresh an existing active binding.
- Phase 50 completed on 2026-03-25: `set_device_nickname` and `archive_device` now require authenticated `admin` or correctly scoped `kepala_gerai` callers in the additive SQL migration `sql/phase_50_kiosk_boundary_hardening_20260325.sql`.
- Phase 50 completed on 2026-03-25: `KioskDevice` parsing and admin dashboard device loading now degrade safely on malformed UUID or timestamp payloads; focused regression coverage lives in `test/phase50/kiosk_device_model_test.dart`.
- Phase 52 completed on 2026-03-25: protected `/portal` routes now redirect before downstream handlers run, and `resolvePortalEmployee()` trusts the middleware-cached `portalUser` boundary instead of refetching auth state.
- Phase 52 completed on 2026-03-25: public chooser search now uses a minimal DTO with a 3-character minimum, 64-character maximum, 5-result cap, and no-store Astro endpoint responses; production still needs `sql/phase_52_portal_search_minimization_20260325.sql` applied manually after approval.
- Phase 52 completed on 2026-03-25: `sql/repair_employee_portal_accounts_20260325.sql` restores only confirmed `employee_portal` identities with matching `employee_id` metadata, and passwordless provisioning now fails closed when an existing hidden-email auth user has conflicting metadata.
- Phase 49 acceptance rerun on 2026-03-25 closed the remaining operator blocker after `adb devices -l` again reported device `V8X8ROMVSWVKIVW8` in `device` state.
- Phase 49 release evidence on 2026-03-25: `tool/release_preflight.ps1` passed end-to-end, `tool/release_build.ps1 -SmokeVerify` built and staged `build/releases/android/ABSENKOK-v7.0.0+8013/ABSENKOK-v7.0.0+8013.apk`, `mapping.txt`, `release-manifest.json`, and `smoke-check.txt`, and the manifest records `smokeVerification.status = passed`.
- Phase 49 debug-artifact truth on 2026-03-25: Flutter did not emit `split-debug-info` files for this non-obfuscated v7.0 release build, so the staged `symbols/` directory is empty and `release-manifest.json` records `debugArtifacts.splitDebugInfoStatus = not-generated`.
- Phase 49 acceptance run also hardened `tool/release_build.ps1` for PowerShell 5.1 by fixing scalar-versus-array `.Count` assumptions, handling native `adb` stderr without aborting, and staging debug-artifact metadata truthfully.
- Phase 49-01 completed on 2026-03-24: `docs/android-release-runbook.md` now documents the exact `powershell.exe` helper order, the private signing placeholder schema, the expected `ABSENKOK-v7.0.0+8013` staged release directory, and the operator readiness checklist. Runbook marker audit plus `tool/release_build.ps1 -CheckOnly -SmokeVerify` both passed on this machine.
- Phase 48.1 completed on 2026-03-23: `tool/release_build.ps1` now retains the signed optimized `.apk` as the canonical artifact, keeps `.aab` output behind `-IncludeAppBundle`, records `bundleRetentionState` instead of `apkRetentionState`, and keeps smoke evidence attached to the same staged APK record in both `powershell.exe` 5.1 and `pwsh`.
- Phase 48-03 completed on 2026-03-23: `tool/release_build.ps1` now retains split-debug-info under `symbols/`, copies `mapping.txt` into the staged release directory when available, records both in `release-manifest.json`, and supports `-SmokeVerify`; `-CheckOnly -IncludeSideLoadApk -SmokeVerify` now resolves `adb`, the signed APK plan, and `smoke-check.txt` without needing an attached device; real smoke verification records install and launch results or fails clearly when no Android target is visible.
- Phase 48-02 completed on 2026-03-23: `tool/release_build.ps1` is now the single tracked packaging entrypoint; `-CheckOnly` validates the release lane without cutting artifacts; real builds always gate through `tool/release_preflight.ps1`; the delivered Phase 48 contract retained a signed `.aab` under `build/releases/android/ABSENKOK-v<versionName>+<versionCode>/` and kept the signed release `.apk` behind `-IncludeSideLoadApk`, but urgent Phase 48.1 now exists specifically to reverse that policy back to APK-first.
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

**Last session:** 2026-03-31T13:13:24+08:00
**Stopped at:** Archived milestone v8.0 Strict Attendance & Payroll Reporting
**Resume file:** .planning/milestones/v8.0-MILESTONE-AUDIT.md

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
