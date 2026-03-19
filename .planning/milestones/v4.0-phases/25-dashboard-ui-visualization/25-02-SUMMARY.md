---
phase: 25-dashboard-ui-visualization
plan: 02
subsystem: gamification
tags: [streak, badges, kiosk, gamification]

requires:
  - phase: 25-00
    provides: Wave 0 test stubs for GAME-02/GAME-03
  - phase: 23
    provides: update_employee_streak RPC, badges table
provides:
  - StreakBadgeService singleton for milestone detection and auto-badge award
  - Streak count display in kiosk scan success screen after masuk
  - Milestone celebration (7/30/90 days) with amber text and confetti
affects: [admin-dashboard, badge-management]

tech-stack:
  added: []
  patterns: [fire-and-forget streak update, lazy badge creation]

key-files:
  created:
    - lib/services/streak_badge_service.dart
  modified:
    - lib/screens/kiosk/kiosk_scan_screen.dart

key-decisions:
  - Exact match milestone check (== not >=) to avoid re-awarding badges
  - Lazy badge definition creation on first milestone hit (no migration needed)
  - Fire-and-forget streak update via unawaited to never block NFC scan

metrics:
  duration: ~3min
  completed: "2026-03-19"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 25 Plan 02: Kiosk Streak Display + Auto-Badge Summary

StreakBadgeService detects 7/30/90 day milestones and auto-awards badges via BadgeService; kiosk scan success screen shows streak count with fire icon after masuk.

## Task Results

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create StreakBadgeService | a3f6af1 | lib/services/streak_badge_service.dart |
| 2 | Add streak display to kiosk scan success | e2741a1 | lib/screens/kiosk/kiosk_scan_screen.dart |

## What Was Built

1. **StreakBadgeService** (`lib/services/streak_badge_service.dart`): Singleton service with `checkAndAwardMilestone()` that detects exact streak milestones (7, 30, 90 days) and auto-awards corresponding badges. Badge definitions created lazily via BadgeService on first hit. All errors caught and logged, never throws.

2. **Kiosk scan streak display**: After masuk scan, fire-and-forget call to `update_employee_streak` RPC fetches current streak. When streak >= 2, displays fire icon + "N hari berturut-turut!" text. At milestones (7/30/90), shows amber celebration text ("Streak N Hari!" / "Streak 90 Hari! Luar Biasa!") and fires confetti.

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED
