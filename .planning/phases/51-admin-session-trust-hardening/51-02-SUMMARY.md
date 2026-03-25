---
phase: 51-admin-session-trust-hardening
plan: 02
subsystem: auth
tags: [flutter, supabase, biometrics, riverpod, security]
requires:
  - phase: 37-portal-foundation-employee-auth
    provides: Supabase auth wiring and current role-based admin session surfaces
  - phase: 39-employee-portal-schedule-ux
    provides: Local-scope logout precedent and SharedPreferences session handling patterns
  - phase: 50-kiosk-device-boundary-hardening
    provides: Current v7.1 security baseline and accepted admin routing constraints
provides:
  - Shared trusted admin-session claim parser sourced from app_metadata only
  - Hardened login, auth-listener, and biometric re-entry flow that derives privilege from the live Supabase session
  - Regression coverage for claim parsing and biometric preference cleanup
affects: [admin-login, admin-shell, app-provider, supabase-auth]
tech-stack:
  added: []
  patterns: [shared app-metadata-only claim parsing, live-session biometric privilege restore]
key-files:
  created:
    - lib/core/admin_session_claims.dart
    - test/phase51/admin_session_claims_test.dart
    - .planning/phases/51-admin-session-trust-hardening/51-02-SUMMARY.md
  modified:
    - lib/app.dart
    - lib/screens/admin/admin_login_screen.dart
    - lib/screens/admin/admin_shell.dart
    - lib/providers/app_provider.dart
    - test/screens/admin/admin_login_screen_test.dart
    - test/providers/app_provider_biometric_test.dart
key-decisions:
  - "Trusted privileged routing now parses app_metadata in one shared helper so login, auth-state listeners, and biometric settings cannot drift back to userMetadata fallbacks."
  - "Biometric login keeps only the enablement preference in SharedPreferences and always re-derives privilege from the current Supabase session after local biometric success."
  - "Legacy remembered role and outlet keys are cleared defensively during biometric preference load/toggle so stale local data cannot influence future admin routing."
patterns-established:
  - "Privileged Flutter session state must flow through AdminSessionClaims.fromUser before AppNotifier applies admin or kepala-gerai mode."
  - "Biometric convenience is allowed only as a second factor over an already-valid server-issued privileged claim, never as an offline role restore."
requirements-completed: [SECACC-02, SECACC-03]
duration: 11min
completed: 2026-03-25
---

# Phase 51 Plan 02: Admin Session Trust Hardening Summary

**Trusted admin-session parsing from Supabase app metadata, with biometric re-entry and admin routing now tied to the live server-issued session instead of writable metadata or remembered roles.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-03-25T04:27:05Z
- **Completed:** 2026-03-25T04:37:45Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Added `lib/core/admin_session_claims.dart` plus focused tests so privileged admin and `kepala_gerai` claims are resolved from `app_metadata` only.
- Rewired `lib/app.dart`, `lib/screens/admin/admin_login_screen.dart`, `lib/screens/admin/admin_shell.dart`, and `lib/providers/app_provider.dart` to apply trusted live-session claims instead of `userMetadata` fallbacks or remembered role/outlet values.
- Expanded regression coverage so biometric entry requires a trusted privileged session and disabling or reloading biometric preferences clears legacy remembered privilege keys.

## Task Commits

Each task was committed atomically:

1. **Task 1: Introduce a shared app-metadata-only admin session claim resolver with regression coverage** - `cb53c4e` (test), `bca8700` (feat)
2. **Task 2: Rewire admin login, auth restore, and biometric re-entry to use live trusted session claims** - `db3285d` (fix)

**Plan metadata:** pending docs commit

## Files Created/Modified
- `lib/core/admin_session_claims.dart` - Shared trusted parser for privileged admin session claims.
- `lib/app.dart` - Auth listener now applies privileged mode through the shared claim parser.
- `lib/screens/admin/admin_login_screen.dart` - Login and biometric flows now require a live trusted privileged session.
- `lib/screens/admin/admin_shell.dart` - Biometric enablement validates the current session and no longer stores remembered privilege data.
- `lib/providers/app_provider.dart` - Centralized helpers for applying or clearing trusted admin session state and purging legacy remembered keys.
- `test/phase51/admin_session_claims_test.dart` - Regression coverage for valid and invalid privileged claim parsing.
- `test/screens/admin/admin_login_screen_test.dart` - Biometric helper coverage updated for trusted-session requirements.
- `test/providers/app_provider_biometric_test.dart` - Preference cleanup coverage for legacy remembered privilege keys.
- `.planning/phases/51-admin-session-trust-hardening/51-02-SUMMARY.md` - Execution summary for plan 51-02.

## Decisions Made
- Kept the existing explicit-sign-in-only auto-routing rule in `lib/app.dart`, but switched the privileged claim source to the shared parser so biometric gating remains intact after restart.
- Treated missing or empty `managed_outlet_id` for `kepala_gerai` as an invalid privileged claim across login, biometric re-entry, and settings validation.
- Left biometric convenience as a stored boolean preference only; the app now clears any legacy remembered role/outlet keys instead of trusting them for re-entry.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- The expected home-scoped `gsd-tools.cjs` path was unavailable in this environment, so local repo tooling and direct verification commands were used during execution.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 51 Flutter hardening is covered by `C:\flutter\bin\flutter.bat test test/screens/admin/admin_login_screen_test.dart test/providers/app_provider_biometric_test.dart test/phase51/admin_session_claims_test.dart`.
- Combined with Plan 51-01, the codebase now has both server-side and Flutter-side privilege hardening needed to close the current admin-session trust gap.
- Phase-level planning state files can now be advanced to Phase 52 after roadmap/state completion bookkeeping.

## Self-Check: PASSED

- FOUND: `lib/core/admin_session_claims.dart`
- FOUND: `test/phase51/admin_session_claims_test.dart`
- FOUND: `.planning/phases/51-admin-session-trust-hardening/51-02-SUMMARY.md`
- FOUND: task commit `cb53c4e`
- FOUND: task commit `bca8700`
- FOUND: task commit `db3285d`

---
*Phase: 51-admin-session-trust-hardening*
*Completed: 2026-03-25*
