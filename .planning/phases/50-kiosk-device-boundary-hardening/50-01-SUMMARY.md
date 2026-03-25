---
phase: 50-kiosk-device-boundary-hardening
plan: 01
subsystem: database
tags: [supabase, sql, kiosk, activation, rpc, security]
requires:
  - phase: 31-device-identity-foundation
    provides: persistent kiosk UUIDs and the original kiosk_devices heartbeat contract
  - phase: 32-multi-device-dashboard
    provides: kiosk device admin RPCs and dashboard device management surfaces
provides:
  - activation-bound kiosk device RPC that binds one persistent UUID to one outlet
  - heartbeat contract that updates telemetry only for an existing active binding
  - scoped nickname and archive RPC authorization for admin and managed kepala gerai users
affects: [phase-51, kiosk-activation, kiosk-heartbeat, device-management]
tech-stack:
  added: []
  patterns:
    - bind kiosk devices during outlet activation before persisting the local kiosk session
    - keep anon heartbeat writes limited to refreshing telemetry on an existing active device row
key-files:
  created:
    - sql/phase_50_kiosk_boundary_hardening_20260325.sql
    - .planning/phases/50-kiosk-device-boundary-hardening/50-USER-SETUP.md
    - .planning/phases/50-kiosk-device-boundary-hardening/50-01-SUMMARY.md
  modified:
    - lib/screens/setup/setup_screen.dart
key-decisions:
  - "The kiosk setup screen now calls `activate_kiosk_device` with the persistent installation UUID instead of verifying outlet credentials separately."
  - "Activation failures are translated into kiosk-friendly operator copy so device-binding problems read as activation issues, not raw RPC noise."
  - "Blank outlet names and passwords are rejected inside the migration before outlet verification runs."
patterns-established:
  - "Activation-before-session: only persist a kiosk session after Supabase confirms the outlet binding and echoes the same device UUID."
  - "Scoped device management: nickname and archive RPCs check `auth.jwt().app_metadata` role and managed outlet before mutating kiosk rows."
requirements-completed: [SECDEV-01, SECDEV-02]
duration: 7 min
completed: 2026-03-25
---

# Phase 50 Plan 01: Kiosk Boundary Summary

**Supabase now binds a kiosk's persistent UUID at activation time, and the Flutter setup flow stores the session only after that binding succeeds**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-25T11:26:22+08:00
- **Completed:** 2026-03-25T11:33:44+08:00
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added the additive Phase 50 migration that creates `activate_kiosk_device`, hardens `upsert_kiosk_heartbeat`, and scopes `set_device_nickname` / `archive_device` to the right authenticated roles.
- Rewired the setup screen to send the persistent device UUID through `activate_kiosk_device` while preserving the same outlet-name plus password UX.
- Added activation-specific error mapping so outlet mismatches, blank device identity, and rebound-device failures surface as operator-readable setup errors.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create the additive SQL hardening migration for activation-bound heartbeat and scoped device-management RPCs** - `822cd7d`, `298e387` (fix)
2. **Task 2: Update the kiosk activation flow to send the persistent device UUID through the new activation RPC** - `7c9c12c` (fix)

## Files Created/Modified

- `sql/phase_50_kiosk_boundary_hardening_20260325.sql` - additive migration for activation-bound device binding, heartbeat enforcement, and scoped device-management RPCs.
- `lib/screens/setup/setup_screen.dart` - kiosk activation now uses `activate_kiosk_device`, validates the echoed device UUID, and keeps activation failures user-facing.
- `.planning/phases/50-kiosk-device-boundary-hardening/50-USER-SETUP.md` - manual rollout step for applying the additive SQL in Supabase.

## Decisions Made

- Reused the existing verified-outlet contract by wrapping `verify_kiosk_password` inside the new activation RPC instead of duplicating password logic in Flutter.
- Kept the local kiosk session shape unchanged; Phase 50 tightens the trust boundary without introducing new secrets or local state.
- Required the server to echo the same `device_uuid` back to Flutter before the kiosk session is persisted.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Parallel executor overlap landed the first SQL version under a `50-02` commit label**
- **Found during:** Task 1 closeout review
- **Issue:** The parallel executor mixed the initial SQL migration creation into commit `822cd7d`, which belongs to the other plan's TDD flow.
- **Fix:** Re-reviewed the migration, added blank-input validation, and recorded the stabilized SQL work in a dedicated `50-01` commit.
- **Files modified:** `sql/phase_50_kiosk_boundary_hardening_20260325.sql`
- **Verification:** `Select-String` confirmed all four RPC names, `SET search_path = public`, and `REVOKE` / `GRANT` statements after the follow-up commit.
- **Committed in:** `298e387` (fix)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** The deviation affected commit hygiene only. The final migration and setup wiring match the planned security boundary.

## Issues Encountered

- Parallel plan execution wrote directly into the main worktree and required manual closeout after the agents stopped returning structured results.

## User Setup Required

**External services require manual configuration.** See [50-USER-SETUP.md](./50-USER-SETUP.md) for:
- Supabase SQL Editor rollout steps
- The additive production migration path
- Basic verification expectations after rollout

## Next Phase Readiness

- Phase 51 can now assume kiosk device bindings are outlet-locked before admin session hardening begins.
- Production rollout still depends on manually applying `sql/phase_50_kiosk_boundary_hardening_20260325.sql` in Supabase.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/50-kiosk-device-boundary-hardening/50-01-SUMMARY.md`.
- `git log --oneline --all --grep="50-01"` now returns the dedicated phase commits.
- `lib/screens/setup/setup_screen.dart` analyzes cleanly after switching to `activate_kiosk_device`.
- `sql/phase_50_kiosk_boundary_hardening_20260325.sql` contains the four hardened RPC definitions and explicit grants.

---
*Phase: 50-kiosk-device-boundary-hardening*
*Completed: 2026-03-25*
