# Codebase Concerns

**Analysis Date:** 2026-04-14

## Project State & Documentation Drift

**Root guidance points to missing or stale repo contracts:**
- Issue: `AGENTS.md:13-18` says `pubspec.yaml` is `v8.1.0`, tells agents to read `CLAUDE.md`, and references `build_flutter.ps1`, but `pubspec.yaml:4` is `8.7.0+8700`, `CLAUDE.md` is absent from the repo root, and `build_flutter.ps1` is absent while the active build scripts live in `tool/release_build.ps1`, `tool/release_preflight.ps1`, and `tool/release_env.ps1`.
- Files: `AGENTS.md`, `pubspec.yaml`, `tool/release_build.ps1`, `tool/release_preflight.ps1`, `tool/release_env.ps1`
- Impact: onboarding, automation, and release guidance can route contributors to files that do not exist and to milestone metadata that no longer matches the shipped app version.
- Fix approach: refresh `AGENTS.md` to reference the `tool/` scripts, remove the hard dependency on missing `CLAUDE.md`, and align all version references with `pubspec.yaml`.

**Planning state overstates verification closure:**
- Issue: `.planning/STATE.md:20-44` marks milestone `v8.1` complete with no next phase, while `.planning/phases/62-schedule-gap-notices/62-VALIDATION.md:1-74` is still `draft`, `nyquist_compliant: false`, `wave_0_complete: false`, and all mapped checks remain pending.
- Files: `.planning/STATE.md`, `.planning/phases/62-schedule-gap-notices/62-VALIDATION.md`
- Impact: milestone closeout looks more complete than the verification ledger says it is, which weakens future audits and follow-up planning.
- Fix approach: either close the Phase 62 validation artifact truthfully or reopen the milestone verification state until the artifact matches the shipped status.

**Inventory docs lag behind the actual repo surface:**
- Issue: `sql/AGENTS.md:8` says `sql/` contains 27 files through Phase 59, but `sql/` currently contains 30 tracked `.sql` files including `sql/phase_58_shift_roles_table.sql` and `sql/phase_62_parttime_late_overnight_fixes.sql`; `test/screens/kiosk/AGENTS.md:7-12` says the kiosk suite has 2 tests while `test/screens/kiosk/` contains 3 tracked tests.
- Files: `sql/AGENTS.md`, `sql/phase_58_shift_roles_table.sql`, `sql/phase_62_parttime_late_overnight_fixes.sql`, `test/screens/kiosk/AGENTS.md`, `test/screens/kiosk/kiosk_idle_cleanup_test.dart`, `test/screens/kiosk/kiosk_scan_server_time_test.dart`, `test/screens/kiosk/kiosk_scan_streak_test.dart`
- Impact: codebase maps and agent guidance are not reliable inventories of the current repo.
- Fix approach: refresh AGENTS inventories whenever new SQL or test files land.

## Tech Debt

**Tracked repair artifacts still compete with real source:**
- Issue: the root keeps 64 tracked `fix_*.py` rewrite scripts plus helper scripts such as `run_fixes.py`, `step1_imports.py`, `step2_snackbars.py`, `step3_containers.py`, `step4_shimmers.py`, and `convert_containers.py`; the source tree also tracks 8 `.checkpoint2` snapshots such as `lib/core/constants.dart.checkpoint2`, `lib/screens/admin/admin_reports_screen.dart.checkpoint2`, `lib/services/sqlite_service.dart.checkpoint2`, and `lib/services/sync_service.dart.checkpoint2`.
- Files: `fix_admin_dashboard.py`, `fix_outlets_proper*.py`, `fix_shimmer*.py`, `fix_snackbar*.py`, `run_fixes.py`, `step1_imports.py`, `step2_snackbars.py`, `step3_containers.py`, `step4_shimmers.py`, `convert_containers.py`, `lib/core/constants.dart.checkpoint2`, `lib/screens/admin/admin_dashboard_screen.dart.checkpoint2`, `lib/screens/admin/admin_employees_screen.dart.checkpoint2`, `lib/screens/admin/admin_reports_screen.dart.checkpoint2`, `lib/services/sqlite_service.dart.checkpoint2`, `lib/services/sync_service.dart.checkpoint2`
- Impact: repo search results are noisy, source-of-truth files are harder to identify, and cleanup/refactor work has a higher chance of touching the wrong artifact.
- Fix approach: remove obsolete repair scripts from the tracked tree or move them into an explicitly archival directory outside the active source surface; drop `.checkpoint2` files from version control once their content is either merged or discarded.

**Admin/reporting surfaces are still monolithic ownership hotspots:**
- Issue: `lib/screens/admin/admin_reports_screen.dart` is 2642 lines, `lib/screens/admin/admin_dashboard_screen.dart` is 2323 lines, `lib/screens/admin/admin_employees_screen.dart` is 2047 lines, and `lib/screens/admin/shift_scheduler_screen.dart` is 1773 lines, each combining screen state, data loading, mutations, and multiple embedded view models/widgets.
- Files: `lib/screens/admin/admin_reports_screen.dart`, `lib/screens/admin/admin_dashboard_screen.dart`, `lib/screens/admin/admin_employees_screen.dart`, `lib/screens/admin/shift_scheduler_screen.dart`
- Impact: concurrent work conflicts quickly, regressions are hard to localize, and simple feature changes require editing large multi-responsibility files.
- Fix approach: keep extracting feature-specific panels and service/controller seams, especially around payroll export, dashboard mutation flows, employee management dialogs, and scheduler persistence.

**Deferred algorithm and RPC contract work remains in the runtime path:**
- Issue: `lib/services/schedule_generator.dart:171` still contains the balancing TODO, and `lib/services/payroll_matrix_builder.dart:59` still contains the `TODO(per-day-role)` note that depends on richer recap RPC output.
- Files: `lib/services/schedule_generator.dart`, `lib/services/payroll_matrix_builder.dart`
- Impact: roster fairness remains only partially implemented, and per-day role-aware payroll semantics remain blocked on an unfinished backend/UI contract.
- Fix approach: finish the balancing rules in `ScheduleGenerator` and complete the per-day role payload contract end-to-end before broadening payroll semantics again.

## Known Bugs

**Guidance contract bug at the repo root:**
- Symptoms: following `AGENTS.md` literally sends contributors to `CLAUDE.md` and `build_flutter.ps1`, neither of which exists in the root repo, while the listed app version no longer matches `pubspec.yaml`.
- Files: `AGENTS.md`, `pubspec.yaml`, `tool/release_build.ps1`, `tool/release_preflight.ps1`
- Trigger: onboarding, AI automation, or manual release work that starts from root guidance.
- Workaround: use `README.md` plus the `tool/release_*.ps1` scripts as the active release surface.

**Verification ledger bug for completed Phase 62 work:**
- Symptoms: project state treats Phase 62 as complete, but the matching validation ledger remains pending/draft.
- Files: `.planning/STATE.md`, `.planning/phases/62-schedule-gap-notices/62-VALIDATION.md`
- Trigger: milestone closeout, codebase mapping, or audit work that trusts `.planning/STATE.md` without checking phase validation artifacts.
- Workaround: consult the Phase 62 summaries and tests directly instead of trusting the validation frontmatter.

## Rollout Constraints

**Database rollout stays manual and additive-only:**
- Constraint: `.planning/STATE.md:34` says production schema changes remain additive only and still require explicit user confirmation before any production migration is applied.
- Files: `.planning/STATE.md`, `sql/phase_54_workforce_contract_outlet_mode_20260326.sql`, `sql/phase_55_schedule_policy_foundation_20260326.sql`, `sql/phase_56_server_time_scan_authority_20260327.sql`, `sql/phase_57_strict_recap_evaluation_engine_20260327.sql`, `sql/phase_62_parttime_late_overnight_fixes.sql`
- Impact: rollout sequencing and applied/unapplied migration truth remain operationally critical; repo state alone is not enough to know what production already has.
- Fix approach: keep an explicit applied-migration ledger tied to each milestone closeout and annotate pending SQL files before release work starts.

**Release preflight does not fail on analyzer warnings:**
- Constraint: `tool/release_preflight.ps1:81-88` runs `flutter analyze --no-fatal-infos --no-fatal-warnings` before tests and `:app:compileReleaseSources`.
- Files: `tool/release_preflight.ps1`
- Impact: warning debt can ship through the official preflight lane, so release readiness depends on manual discipline rather than a strict static-analysis gate.
- Fix approach: add a strict analyzer lane for release or a second script that fails on warnings for milestone closeout and shipping branches.

**Shared-root env workflow couples the Flutter app and Astro portal:**
- Constraint: `README.md:53-77` describes one root `.env` workflow for the portal, while `lib/main.dart:33-66` loads `.env` for Flutter and `pubspec.yaml:122-126` packages `.env` into the app bundle.
- Files: `README.md`, `lib/main.dart`, `pubspec.yaml`, `src/lib/supabase/env.ts`
- Impact: operator/build steps must keep mobile-safe and server-only environment values separated manually; one mistake can put the wrong secret set on the wrong runtime.
- Fix approach: split app and server env contracts into separate templates and file names, and make the Flutter build fail fast when server-only keys are present.

## Security Considerations

**Portal auth falls back to a hardcoded default secret:**
- Risk: `src/lib/portal/auth.ts:55-62` derives hidden portal passwords from `PORTAL_SECRET` but silently falls back to `'enakko-portal-default-secret'` when the env var is missing.
- Files: `src/lib/portal/auth.ts`, `.env.example`, `README.md`
- Current mitigation: none in the tracked repo; `.env.example:1-4` and `README.md:71-77` do not document `PORTAL_SECRET`, so new environments can miss it and still boot.
- Recommendations: remove the fallback, require `PORTAL_SECRET`, and fail closed during server startup when it is missing.

**The same root env template invites service-role leakage into the mobile app bundle:**
- Risk: `pubspec.yaml:123` includes `.env` as a Flutter asset, while `.env.example:3` and `README.md:74-76` teach the same root env flow to include `SUPABASE_SERVICE_ROLE_KEY` for portal provisioning.
- Files: `pubspec.yaml`, `lib/main.dart`, `.env.example`, `README.md`, `src/lib/supabase/env.ts`
- Current mitigation: `.gitignore:64-66` ignores `.env` and `.env.*`, so the secret file itself is not tracked by default.
- Recommendations: split env files by runtime, reject service-role-like keys during Flutter build packaging, and document a mobile-only env contract that contains only `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SENTRY_DSN`.

**Service-role admin provisioning lives in the same repo as public portal auth helpers:**
- Risk: `src/lib/supabase/admin.ts:4-117` and `src/lib/portal/provision.ts:21-125` keep service-role account creation/update logic beside the public portal codepaths, which increases the chance of accidental misuse during future refactors.
- Files: `src/lib/supabase/admin.ts`, `src/lib/portal/provision.ts`, `src/lib/supabase/env.ts`, `supabase/functions/provision-employee-portal-user/index.ts`
- Current mitigation: the service-role client is server-side only and `ensurePortalPasswordlessAccount()` checks for active/non-archived employees plus matching `app_role` and `employee_id`.
- Recommendations: add explicit startup validation and audit logging around provisioning entrypoints, and keep privileged helpers isolated from request-layer code.

## Performance Bottlenecks

**Portal account provisioning scales as a full auth-user scan:**
- Problem: `src/lib/portal/provision.ts:91-125` pages through `admin.auth.admin.listUsers()` 200 users at a time until it finds a matching hidden email or exhausts the user list.
- Files: `src/lib/portal/provision.ts`
- Cause: there is no direct indexed lookup path from `employee_id` or hidden auth email to auth user id before hitting the auth admin API.
- Improvement path: persist and trust the auth user id in `employee_portal_accounts`, query that mapping first, and only fall back to `listUsers()` for one-off recovery work.

**Export/reporting orchestration is still heavy and centralized:**
- Problem: `lib/screens/admin/admin_reports_screen.dart` owns daily report fetches, payroll roster loading, PDF export, spreadsheet export, tab state, and filter state; `lib/services/payroll_spreadsheet_export_service.dart` and `lib/services/payroll_pdf_matrix_export_service.dart` are also large single-pass builders.
- Files: `lib/screens/admin/admin_reports_screen.dart`, `lib/services/payroll_spreadsheet_export_service.dart`, `lib/services/payroll_pdf_matrix_export_service.dart`
- Cause: screen-level orchestration, export assembly, and artifact-specific formatting are still tightly coupled.
- Improvement path: push more data assembly into dedicated controllers/services and keep the screen focused on state transitions and presentation.

## Fragile Areas

**Payroll/reporting parity chain:**
- Files: `lib/services/admin_policy_recap_dataset_service.dart`, `lib/services/payroll_matrix_builder.dart`, `lib/services/payroll_spreadsheet_export_service.dart`, `lib/services/payroll_pdf_matrix_export_service.dart`, `lib/screens/admin/admin_reports_screen.dart`, `test/services/report_export_parity_test.dart`
- Why fragile: salary-facing spreadsheet and PDF output must stay aligned with the corrected recap semantics, and the runtime path still spans multiple large services plus a large screen shell.
- Safe modification: update recap dataset logic, matrix building, both exporters, and parity tests together; do not treat one exporter as a secondary path.
- Test coverage: `test/services/report_export_parity_test.dart` locks the export seam, but the UI shell still concentrates a lot of state and wiring in one file.

**Kiosk runtime stack:**
- Files: `lib/screens/kiosk/kiosk_idle_screen.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/services/kiosk_background_service.dart`, `lib/services/heartbeat_service.dart`, `lib/services/nfc_service.dart`
- Why fragile: background service lifecycle, overlay/notification tiers, NFC listener state, queued fallback, and heartbeat reporting all interact across separate files and device-only behavior.
- Safe modification: validate idle cleanup, scan success/failure, heartbeat start/stop, and overlay cleanup as one device flow instead of editing single functions in isolation.
- Test coverage: `test/screens/kiosk/kiosk_idle_cleanup_test.dart`, `test/screens/kiosk/kiosk_scan_server_time_test.dart`, and `test/screens/kiosk/kiosk_scan_streak_test.dart` cover important slices, but `lib/services/kiosk_background_service.dart` and `lib/services/heartbeat_service.dart` have no dedicated test files.

**Scheduler surface:**
- Files: `lib/screens/admin/shift_scheduler_screen.dart`, `lib/services/schedule_generator.dart`, `lib/services/schedule_policy_service.dart`, `lib/services/schedule_sqlite_service.dart`
- Why fragile: one stateful screen combines Supabase loading, SQLite fallback, time-off flows, auto-generation, manual edits, and PDF export.
- Safe modification: regression-test load/save/export/bulk assign flows together and avoid changing fallback rules without matching integration coverage.
- Test coverage: `test/screens/admin/shift_scheduler_screen_test.dart` exists, but there is no dedicated test suite for `lib/services/schedule_policy_service.dart` or `lib/services/schedule_sqlite_service.dart`.

## Scaling Limits

**Portal auth provisioning cost grows with total auth-user count, not active employee count:**
- Current capacity: `src/lib/portal/provision.ts` scans auth users 200 at a time until it finds a match.
- Limit: provisioning and reset cost increases linearly as auth users accumulate, including stale hidden accounts and unrelated auth entries.
- Scaling path: persist auth ids in `employee_portal_accounts`, query the mapping first, and reserve auth-user scans for repair tools only.

**Large shared screens limit safe parallel delivery:**
- Current capacity: a small number of contributors can coordinate changes inside `lib/screens/admin/admin_reports_screen.dart` and `lib/screens/admin/admin_dashboard_screen.dart`.
- Limit: concurrent feature work collides quickly because reporting, dashboard, and scheduler logic still live in a few large shared files.
- Scaling path: keep splitting route shells into smaller feature widgets and dedicated mutation handlers so future changes land in narrower files.

## Dependencies at Risk

**The Android kiosk stack is pinned by plugin compatibility:**
- Risk: `AGENTS.md:39` explicitly says Kotlin must stay on `1.9.25` because Kotlin 2.x breaks `nfc_manager`; the kiosk path also depends on `flutter_foreground_task` and `flutter_overlay_window`.
- Files: `AGENTS.md`, `pubspec.yaml`, `lib/services/nfc_service.dart`, `lib/services/kiosk_background_service.dart`
- Impact: Kotlin/AGP upgrades remain coupled to NFC, background-service, and overlay behavior instead of being routine tooling changes.
- Migration plan: treat `nfc_manager`, `flutter_foreground_task`, and `flutter_overlay_window` as one upgrade spike and verify the whole kiosk runtime on-device before moving the Android toolchain.

**The payroll artifact stack has a wide third-party surface:**
- Risk: payroll export depends on `syncfusion_flutter_xlsio`, `syncfusion_officechart`, `pdf`, and `printing`, with large builder services on top.
- Files: `pubspec.yaml`, `lib/services/payroll_spreadsheet_export_service.dart`, `lib/services/payroll_pdf_matrix_export_service.dart`, `lib/services/pdf_service.dart`
- Impact: exporter regressions can break payroll artifacts without touching attendance capture or recap logic.
- Migration plan: keep fixture-driven parity tests mandatory and add sample-artifact review whenever export dependencies move.

## Missing Critical Features

**No automated Astro/portal test lane:**
- Problem: `src/` contains no tracked `*.test.*` or `*.spec.*` files, and `package.json:6-10` defines only `dev`, `build`, `preview`, and `check`.
- Blocks: confident edits to portal auth, provisioning, employee resolution, and schedule rendering.

**No closed verification artifact for shipped Phase 62 work:**
- Problem: `.planning/phases/62-schedule-gap-notices/62-VALIDATION.md` still records pending Wave 0 gaps even though `.planning/STATE.md` presents the phase and milestone as complete.
- Blocks: trustworthy milestone closeout and future auditability.

## Test Coverage Gaps

**Offline and persistence services:**
- What's not tested: `lib/services/heartbeat_service.dart`, `lib/services/employee_cache_service.dart`, `lib/services/schedule_sqlite_service.dart`, `lib/services/sqlite_service.dart`, `lib/services/schedule_policy_service.dart`, `lib/services/location_service.dart`
- Files: `lib/services/heartbeat_service.dart`, `lib/services/employee_cache_service.dart`, `lib/services/schedule_sqlite_service.dart`, `lib/services/sqlite_service.dart`, `lib/services/schedule_policy_service.dart`, `lib/services/location_service.dart`
- Risk: background, offline, migration, and cache regressions surface only on-device or after rollout.
- Priority: High

**Background-service orchestration:**
- What's not tested: `lib/services/kiosk_background_service.dart`
- Files: `lib/services/kiosk_background_service.dart`
- Risk: overlay, notification, and service cleanup regressions are easy to ship because the device-only service layer has no dedicated safety net.
- Priority: High

**Sync failure handling beyond ordering:**
- What's not tested: live RPC failure, retry, partial recovery, and error/reporting behavior in `lib/services/sync_service.dart`; the existing suite in `test/services/sync_service_order_test.dart` only locks replay ordering semantics.
- Files: `lib/services/sync_service.dart`, `test/services/sync_service_order_test.dart`
- Risk: sync loss or noisy failure handling can slip through while the order-only tests stay green.
- Priority: High

**End-to-end PDF assembly behavior:**
- What's not tested: full document layout and content assembly in `lib/services/pdf_service.dart`; `test/services/pdf_service_color_test.dart` only covers helper color mapping, DTO construction, and role selection helpers.
- Files: `lib/services/pdf_service.dart`, `test/services/pdf_service_color_test.dart`
- Risk: artifact layout/data regressions can pass current tests.
- Priority: Medium

**Portal auth and provisioning:**
- What's not tested: `src/lib/portal/auth.ts`, `src/lib/portal/provision.ts`, and `src/lib/supabase/admin.ts`
- Files: `src/lib/portal/auth.ts`, `src/lib/portal/provision.ts`, `src/lib/supabase/admin.ts`
- Risk: hidden-account provisioning, deterministic password generation, and service-role request behavior can regress without any automated signal.
- Priority: High

**Root smoke lane remains placeholder-only:**
- What's not tested: the root `test/widget_test.dart:1-10` still contains only a placeholder widget test.
- Files: `test/widget_test.dart`
- Risk: the repo keeps a nominal smoke test without protecting any meaningful top-level app behavior.
- Priority: Low

---

*Concerns audit: 2026-04-14*
