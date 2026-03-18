---
phase: 23-bug-fix-database-foundation
plan: 01
subsystem: nfc
tags: [nfc, crash-fix, flutter, admin]

requires: []
provides:
  - One-shot NFC registration listener that stops the session before handing the UID to the UI
  - NFC assignment dialog guards that ignore duplicate scan callbacks and clean up listeners before retry
affects: [employee-management, nfc-registration, phase-23]

tech-stack:
  added: []
  patterns:
    - one-shot registration listener separate from continuous kiosk scanning
    - UI-side processing guard for retryable NFC dialogs

key-files:
  created: []
  modified:
    - lib/services/nfc_service.dart
    - lib/screens/admin/admin_employees_screen.dart

key-decisions:
  - "Kept the existing continuous startListener untouched and introduced a dedicated startRegistrationListener for the employee assignment flow"
  - "Moved duplicate-scan protection into both the NFC service and the dialog state so retry buttons cannot create overlapping sessions"

patterns-established:
  - "Registration NFC flows should stop the session before mutating UI state"
  - "Retryable NFC dialogs should reset cleanup handles before starting a fresh session"

requirements-completed: [BUG-01]

duration: 32min
completed: 2026-03-18
---

# Phase 23 Plan 01: NFC Double-Scan Crash Fix Summary

**Employee NFC registration now uses a one-shot scan session with dialog-level retry guards, so rapid double taps no longer create overlapping registration flows**

## Performance

- **Duration:** 32 min
- **Started:** 2026-03-18T10:39:00Z
- **Completed:** 2026-03-18T11:11:29Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added a dedicated `startRegistrationListener` path in `NfcService` for one-card registration instead of reusing the continuous kiosk listener
- Reworked `_AssignNfcDialogState` to use async cleanup correctly and block reentrant scan starts while a tag is already being processed
- Ensured `Scan Ulang` and `Coba Lagi` both stop the previous listener before starting a new session

## Task Commits

Each task was committed atomically:

1. **Task 1: Add startRegistrationListener to NfcService with one-shot semantics** - `8081463` (fix)
2. **Task 2: Fix _AssignNfcDialog to use one-shot registration listener with proper state guards** - `9743cc9` (fix)

## Files Created/Modified
- `lib/services/nfc_service.dart` - Added the one-shot registration listener used only by employee card assignment
- `lib/screens/admin/admin_employees_screen.dart` - Updated the assign-card dialog to use async cleanup, `_isProcessing`, and safe retry behavior

## Decisions Made
- Added a dedicated registration listener instead of changing `startListener`, because kiosk idle scanning still needs continuous session behavior
- Kept the dialog cleanup fire-and-forget so retries remain responsive while the NFC plugin stops the previous session asynchronously

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `flutter analyze` needed to run outside the sandbox to complete reliably on this Windows workspace
- The file already contained unrelated info-level deprecation lints; the new NFC changes introduced no analyzer errors

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- The production NFC registration crash is addressed and no longer blocks downstream v4.0 feature work
- Phase 23 plan 02 can proceed to Supabase SQL deployment without the employee assignment flow remaining unstable

---
*Phase: 23-bug-fix-database-foundation*
*Completed: 2026-03-18*
