---
phase: 21
slug: badge-color-picker
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | pubspec.yaml (dev_dependencies) |
| **Quick run command** | `C:\flutter\bin\flutter.bat test --name "badge"` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `C:\flutter\bin\flutter.bat test --name "badge"`
- **After every plan wave:** Run `C:\flutter\bin\flutter.bat test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 21-01-01 | 01 | 1 | BADGE-01 | widget | `flutter test test/widgets/color_picker_field_test.dart` | No - W0 | pending |
| 21-01-02 | 01 | 1 | BADGE-02 | widget | `flutter test test/widgets/color_picker_field_test.dart` | No - W0 | pending |
| 21-01-03 | 01 | 1 | BADGE-03 | widget | `flutter test test/widgets/color_picker_field_test.dart` | No - W0 | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `test/widgets/color_picker_field_test.dart` — stubs for BADGE-01, BADGE-02, BADGE-03 (including live preview test)

*Note: Widget tests for dialogs with flutter_colorpicker may require pumpAndSettle and finding picker by type*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Color wheel touch interaction feels responsive | BADGE-03 | Touch gesture performance cannot be tested in widget tests | Open badge form, tap color swatch, drag around color wheel — preview should update without lag |
| Dialog-on-dialog dismissal works correctly | BADGE-01 | Navigator behavior with nested dialogs | Open badge form → tap color → pick color → tap OK → verify badge form is still showing |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
