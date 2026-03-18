---
phase: 25
slug: dashboard-ui-visualization
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-19
---

# Phase 25 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (flutter_test) |
| **Config file** | `pubspec.yaml` (dev_dependencies: flutter_test) |
| **Quick run command** | `flutter test test/unit/ --no-pub` |
| **Full suite command** | `flutter test --no-pub` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/ --no-pub`
- **After every plan wave:** Run `flutter test --no-pub`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 25-01-01 | 01 | 0 | DASH-01 | unit | `flutter test test/unit/analytics_service_test.dart --no-pub` | ❌ W0 | ⬜ pending |
| 25-01-02 | 01 | 1 | DASH-01 | widget | `flutter test test/widget/chart_dashboard_screen_test.dart --no-pub` | ❌ W0 | ⬜ pending |
| 25-01-03 | 01 | 1 | DASH-02 | widget | `flutter test test/widget/chart_dashboard_screen_test.dart --no-pub` | ❌ W0 | ⬜ pending |
| 25-02-01 | 02 | 1 | DASH-03 | unit | `flutter test test/unit/analytics_service_test.dart --no-pub` | ❌ W0 | ⬜ pending |
| 25-02-02 | 02 | 2 | DASH-03 | widget | `flutter test test/widget/chart_dashboard_screen_test.dart --no-pub` | ❌ W0 | ⬜ pending |
| 25-03-01 | 03 | 1 | DASH-04 | widget | `flutter test test/widget/chart_dashboard_screen_test.dart --no-pub` | ❌ W0 | ⬜ pending |
| 25-04-01 | 04 | 1 | GAME-02 | unit | `flutter test test/unit/streak_service_test.dart --no-pub` | ❌ W0 | ⬜ pending |
| 25-04-02 | 04 | 2 | GAME-03 | unit | `flutter test test/unit/streak_service_test.dart --no-pub` | ❌ W0 | ⬜ pending |
| 25-04-03 | 04 | 2 | GAME-04 | widget | `flutter test test/widget/kiosk_scan_result_test.dart --no-pub` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/analytics_service_test.dart` — stubs for DASH-01, DASH-02, DASH-03 (attendance rate, weekly trend, outlet comparison data loading)
- [ ] `test/unit/streak_service_test.dart` — stubs for GAME-02, GAME-03, GAME-04 (streak milestone detection and badge award)
- [ ] `test/widget/chart_dashboard_screen_test.dart` — stub for DASH-01 through DASH-04 (screen renders, sections visible, role filtering)
- [ ] `test/widget/kiosk_scan_result_test.dart` — stub for GAME-04 (streak count visible after masuk scan)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Dashboard navigated 100+ times without memory leak | DASH-01 | Requires 4-hour stress test, no automated leak detector in Flutter test | Run app in profile mode, navigate to/from chart-dashboard 100+ times, verify memory stays stable in DevTools |
| fl_chart donut animation renders correctly | DASH-01 | Visual animation requires human review | Open chart-dashboard on device, verify donut chart animates on load |
| Cross-outlet bar chart shows correct outlet colors | DASH-03 | Color correctness requires visual verification | Open on device with 2+ outlets, verify each outlet bar uses distinct color from palette |
| Badge confetti fires on streak milestone | GAME-03 | Requires live NFC scan hitting milestone | Scan employee at 7-day, 30-day, or 90-day streak, verify confetti animation plays |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
