---
phase: 06-nfc-idle-screen-visual-enhancement
plan: 01
subsystem: ui
tags: [flutter, custompainter, animation, dark-theme, kiosk]

# Dependency graph
requires: []
provides:
  - "Dark kiosk idle screen with 3-layer ambient background animation"
  - "18 kiosk dark palette color constants in AppColors"
  - "Pre-defined opacity variants for NFC ring (avoids withOpacity in paint)"
  - "3 animation timing constants in AppConstants"
  - "_AmbientBackgroundPainter CustomPainter class"
affects: [06-nfc-idle-screen-visual-enhancement]

# Tech tracking
tech-stack:
  added: []
  patterns: [CustomPainter with multiple animation layers, pre-cached Color constants for paint methods]

key-files:
  created: []
  modified:
    - lib/core/theme.dart
    - lib/core/constants.dart
    - lib/screens/kiosk/kiosk_idle_screen.dart

key-decisions:
  - "Used withValues() instead of withOpacity() in CustomPainter for Flutter deprecation compliance"
  - "Pre-defined all static opacity Color variants as AppColors constants to avoid allocations in paint()"
  - "Dialogs kept with light/white backgrounds while idle screen converted to dark"

patterns-established:
  - "Kiosk dark palette pattern: kioskDark* / kioskText* / kioskNfc* prefixes in AppColors"
  - "AnimatedBuilder + Listenable.merge for multi-controller CustomPainter repaint"

requirements-completed: [REQ-M4-01]

# Metrics
duration: 9min
completed: 2026-03-01
---

# Phase 6 Plan 01: NFC Idle Screen Visual Enhancement Summary

**3-layer ambient background (gradient shift, breathing glow, diagonal shimmer) with dark kiosk palette using CustomPainter and 3 AnimationControllers**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-01T21:10:08Z
- **Completed:** 2026-03-01T21:18:48Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added 18 kiosk dark color constants and 5 pre-defined opacity variants to AppColors
- Implemented _AmbientBackgroundPainter with 3 animated layers: slow gradient shift, breathing radial glow, diagonal shimmer sweep
- Converted entire kiosk idle screen from white to dark premium theme while keeping dialogs light
- Updated all text, icon, ring, banner, and bar colors for dark background visibility

## Task Commits

Each task was committed atomically:

1. **Task 1: Add kiosk dark palette to theme.dart and animation timing constants** - `6fbbfa0` (feat)
2. **Task 2: Implement AmbientBackgroundPainter and convert idle screen to dark theme** - `fa1a2b2` (feat)

## Files Created/Modified
- `lib/core/theme.dart` - Added 18 kiosk dark palette colors + 5 NFC ring opacity variants to AppColors
- `lib/core/constants.dart` - Added 3 animation timing constants (gradient=20s, breathe=8s, shimmer=15s)
- `lib/screens/kiosk/kiosk_idle_screen.dart` - Dark background, _AmbientBackgroundPainter, 3 AnimationControllers, all UI colors updated

## Decisions Made
- Used `withValues(alpha:)` instead of deprecated `withOpacity()` in the CustomPainter breathing glow layer where opacity varies with animation value
- Pre-defined all static opacity colors as AppColors constants to avoid per-frame allocations in paint methods
- Kept all dialog backgrounds white (logout, admin, overlay permission, outlet confirmation) since they appear as overlays

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Dark kiosk idle screen complete with animated background
- Ready for Plan 02 (additional NFC idle screen visual enhancements if any)
- AnimationControllers properly disposed, no memory leak risk for 24/7 kiosk operation

---
*Phase: 06-nfc-idle-screen-visual-enhancement*
*Completed: 2026-03-01*
