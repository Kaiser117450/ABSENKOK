---
phase: 24
slug: core-services-analytics
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (built-in) + manual Supabase RPC verification |
| **Config file** | `pubspec.yaml` (test dependency already present) |
| **Quick run command** | `flutter test test/services/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/services/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 24-01-01 | 01 | 1 | ANLYT-01 | integration | RPC call returns valid JSON | ❌ W0 | ⬜ pending |
| 24-01-02 | 01 | 1 | ANLYT-02 | integration | Overtime flag logic | ❌ W0 | ⬜ pending |
| 24-02-01 | 02 | 1 | ANLYT-03 | manual | Missing clockout notification fires | ❌ W0 | ⬜ pending |
| 24-02-02 | 02 | 1 | ANLYT-04 | manual | Notification batched per outlet | ❌ W0 | ⬜ pending |
| 24-03-01 | 03 | 2 | SMART-01 | unit | Median computation correct | ❌ W0 | ⬜ pending |
| 24-03-02 | 03 | 2 | SMART-02 | manual | Late notification triggers | ❌ W0 | ⬜ pending |
| 24-03-03 | 03 | 2 | SMART-03 | unit | compute() doesn't block main | ❌ W0 | ⬜ pending |
| 24-03-04 | 03 | 2 | SMART-04 | unit | Skip rule < 5 data points | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/analytics_service_test.dart` — stubs for ANLYT-01, ANLYT-02
- [ ] `test/services/pattern_detection_test.dart` — stubs for SMART-01, SMART-03, SMART-04
- [ ] Test helpers for mock Supabase RPC responses

*Note: Flutter test framework already installed. No new test dependencies needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Missing clock-out notification appears | ANLYT-03 | Requires real foreground service + timer | Start kiosk, scan masuk, wait threshold, verify notification |
| Notification batched per outlet | ANLYT-04 | Requires multiple employees without pulang | Multiple masuk scans, no pulang, verify single batched notification |
| Late pattern notification | SMART-02 | Requires NFC scan + pattern comparison | Scan employee who is late vs median, verify notification |
| NFC scan stays under 2 seconds | SMART-03 | Requires real device timing | Scan with pattern detection active, measure response time |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
