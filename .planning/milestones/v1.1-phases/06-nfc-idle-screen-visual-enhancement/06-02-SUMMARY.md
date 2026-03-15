---
phase: 06-nfc-idle-screen-visual-enhancement
plan: 02
subsystem: ui
tags: [flutter, custompainter, gradient, typography, monospace, kiosk]

# Dependency graph
requires:
  - "06-01: Dark kiosk idle screen with ambient background"
provides:
  - "Gradient NFC ring with SweepGradient and pulse-linked inner glow"
  - "Monospace clock using GoogleFonts.robotoMono with light weight"
  - "Premium light-weight instruction typography (w300)"
  - "Brand logo in header with errorBuilder fallback"
affects: [06-nfc-idle-screen-visual-enhancement]

# Tech tracking
tech-stack:
  added: []
  patterns: [SweepGradient CustomPainter for ring effects, GoogleFonts.robotoMono for monospace display]

key-files:
  created: []
  modified:
    - lib/screens/kiosk/kiosk_idle_screen.dart

key-decisions:
  - "Used Color.fromRGBO for dynamic opacity in _GradientRingPainter glow to avoid withOpacity deprecation"
  - "Pulse value normalized from 1.0-1.16 range to 0.0-0.16 by subtracting 1.0 for painter compatibility"
  - "Kept white inner circle fill (not kioskSurfaceDim) to maintain contrast on current white/light background"
  - "Instruction text changed from 'Tempelkan Kartu' to 'Tempelkan Kartu NFC' for clarity"

patterns-established:
  - "_GradientRingPainter: SweepGradient ring + pulse-modulated inner glow via CustomPainter"
  - "Monospace clock pattern: GoogleFonts.robotoMono(w300) for time display"

requirements-completed: [REQ-M4-02]

# Metrics
duration: 5min
completed: 2026-03-05
---

# Phase 6 Plan 02: Brand Logo, Gradient NFC Ring, and Monospace Clock

**Gradient SweepGradient NFC ring painter, monospace Roboto Mono clock, light-weight premium instruction typography**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-05
- **Completed:** 2026-03-05
- **Tasks:** 1 auto + 1 checkpoint (pending human verification)
- **Files modified:** 1

## Accomplishments
- Created `_GradientRingPainter` CustomPainter with SweepGradient stroke (brand red gradient) and pulse-linked inner glow
- Updated `_DigitalClock` to use `GoogleFonts.robotoMono` with w300 light weight, letterSpacing 2.0 for premium monospace display
- Changed instruction text to "Tempelkan Kartu NFC" (w300 light weight) with muted subtitle
- Date text updated to use `kioskTextSecondary` color for better dark-theme contrast
- Brand logo with errorBuilder fallback was already in place from prior work

## Task Commits

Each task was committed atomically:

1. **Task 1: Add gradient NFC ring, monospace clock, and premium typography** - `613b39f` (feat)
2. **Task 2: Visual verification** - Human checkpoint (blocking gate)

## Files Created/Modified
- `lib/screens/kiosk/kiosk_idle_screen.dart` - Added `_GradientRingPainter`, `GoogleFonts.robotoMono` clock, light-weight instruction text, google_fonts import

## Deviations from Plan

- **pubspec.yaml already had `assets/images/`** - No change needed (done in prior session)
- **Header logo already had Image.asset with errorBuilder** - No change needed (done in prior session)
- **Used `Colors.white` instead of `AppColors.kioskSurfaceDim`** for inner circle fill to match the existing white background (Plan 01 added dark background as a separate layer, but the NFC ring inner fill should remain white for contrast on the current layout)

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Steps
- Human visual verification on device (Task 2 - blocking gate)
- After approval: Phase 6 is complete, ready for next phase

---
*Phase: 06-nfc-idle-screen-visual-enhancement*
*Completed: 2026-03-05*
