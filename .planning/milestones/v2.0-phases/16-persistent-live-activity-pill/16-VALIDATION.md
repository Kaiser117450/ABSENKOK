---
phase: 16
slug: persistent-live-activity-pill
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built into Flutter SDK) |
| **Config file** | `analysis_options.yaml` (existing) |
| **Quick run command** | `flutter test test/models/overlay_pill_state_test.dart test/services/live_content_provider_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/models/overlay_pill_state_test.dart test/services/live_content_provider_test.dart test/widgets/overlay_pill_widget_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 16-01-01 | 01 | 1 | LIVE-02, LIVE-03 | unit | `flutter test test/services/live_content_provider_test.dart` | ❌ W0 | ⬜ pending |
| 16-01-02 | 01 | 1 | LIVE-02 | unit | `flutter test test/models/overlay_pill_state_test.dart` | ✅ Extend | ⬜ pending |
| 16-02-01 | 02 | 2 | LIVE-04 | unit | `flutter test test/services/live_content_provider_test.dart` | ❌ W0 | ⬜ pending |
| 16-02-02 | 02 | 2 | LIVE-02 | widget | `flutter test test/widgets/overlay_pill_widget_test.dart` | ✅ Extend | ⬜ pending |
| 16-02-03 | 02 | 2 | LIVE-01 | manual | N/A (physical device overlay) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/live_content_provider_test.dart` — covers LIVE-02 (break detection), LIVE-03 (fun facts), LIVE-04 (rotation/polling)
- [ ] Extend `test/models/overlay_pill_state_test.dart` — covers displayLabel serialization round-trip
- [ ] Extend `test/widgets/overlay_pill_widget_test.dart` — covers displayLabel rendering in pill UI

*Existing infrastructure covers test framework — only test files need creation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Overlay visible outside app | LIVE-01 | Requires SYSTEM_ALERT_WINDOW on physical device | Start kiosk → press Home → verify pill visible on home screen |
| 24h stability | LIVE-04 | Requires long-running physical device test | Run kiosk overnight → check next morning for pill visibility + memory |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
