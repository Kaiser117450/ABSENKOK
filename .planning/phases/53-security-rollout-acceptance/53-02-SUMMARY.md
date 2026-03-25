---
phase: 53-security-rollout-acceptance
plan: "02"
subsystem: testing
tags: [powershell, flutter-test, acceptance, security, contract-test]

requires:
  - phase: 52-portal-surface-minimization
    provides: portal recovery contract test and hardened portal surface
  - phase: 51-admin-session-trust-hardening
    provides: SQL role guard contract test and admin session hardening
  - phase: 50-kiosk-boundary-hardening
    provides: kiosk device model regression test

provides:
  - Read-only PowerShell acceptance helper that sequences Phase 50-52 verification
  - Focused contract test that guards the acceptance helper command surface

affects: [53-03-closeout]

tech-stack:
  added: []
  patterns:
    - CheckOnly flag pattern for dry-run preview of automation command surface
    - String-based contract test for repo-local script content verification

key-files:
  created:
    - tool/security_hardening_acceptance.ps1
    - test/phase53/security_hardening_acceptance_contract_test.dart
  modified: []

key-decisions:
  - "53-02-01: Acceptance helper uses -CheckOnly flag to preview command surface without executing, consistent with tool/release_build.ps1 pattern"
  - "53-02-02: Helper fails fast on first non-zero exit and prints the failing command explicitly — no silent green output"
  - "53-02-03: Recovery SQL appears only in a Write-Host reminder block, never in the executable Args array"

patterns-established:
  - "Acceptance helpers expose -CheckOnly for safe operator preview before live execution"
  - "Contract tests guard script command surface using string-based assertions on repo-local files"

requirements-completed: [SECOPS-01]

duration: 15min
completed: 2026-03-25
---

# Phase 53 Plan 02: Security Hardening Acceptance Helper Summary

**Read-only PowerShell acceptance helper (`-CheckOnly` + execute) sequencing Phase 50-52 Flutter and Astro verification, guarded by a 5-test contract regression suite**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-25T07:30:00Z
- **Completed:** 2026-03-25T07:45:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `tool/security_hardening_acceptance.ps1` with a `-CheckOnly` dry-run mode and a sequenced execution mode covering all four Phase 50-52 Flutter tests plus `npm run check` and `npm run build`
- Clearly documents that live Supabase SQL rollout is manual operator evidence outside this helper
- Created `test/phase53/security_hardening_acceptance_contract_test.dart` with 5 focused assertions that fail fast if the helper drops required commands or starts treating the recovery SQL as routine automation

## Task Commits

Each task was committed atomically:

1. **Task 1: Create the read-only security hardening acceptance helper** - `eb63380` (feat)
2. **Task 2: Lock the acceptance helper contract with a focused regression test** - `7822840` (test)

## Files Created/Modified

- `tool/security_hardening_acceptance.ps1` — Phase 53 read-only acceptance helper with -CheckOnly and execute modes
- `test/phase53/security_hardening_acceptance_contract_test.dart` — Contract test guarding helper command surface

## Decisions Made

- Used `-CheckOnly` flag (matching `tool/release_build.ps1` convention) for safe operator preview without execution
- Helper fails fast on non-zero exit and prints the failing command explicitly — failures remain visible per constraint
- Recovery SQL (`repair_employee_portal_accounts_20260325.sql`) appears only in a `Write-Host` reminder block at the end, never inside an executable `Args` array

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 53-02 acceptance automation is complete
- `tool/security_hardening_acceptance.ps1 -CheckOnly` confirms the full command surface
- Phase 53-03 (closeout) can now proceed to close the milestone

---
*Phase: 53-security-rollout-acceptance*
*Completed: 2026-03-25*
