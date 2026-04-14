---
phase: 56
slug: server-time-scan-authority
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-26
---

# Phase 56 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (built-in, plus SQL contract file assertions) |
| **Config file** | `analysis_options.yaml` |
| **Quick run command** | `C:\flutter\bin\flutter.bat test test/services/live_content_provider_test.dart test/services/pattern_detection_service_test.dart` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run the touched target tests plus `C:\flutter\bin\flutter.bat test test/services/live_content_provider_test.dart test/services/pattern_detection_service_test.dart`
- **After every plan wave:** Run `C:\flutter\bin\flutter.bat test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 56-00-01 | 00 | 0 | `SCAN-01` | widget | `C:\flutter\bin\flutter.bat test test/phase56/kiosk_scan_authority_flow_test.dart` | ❌ W0 | ⬜ pending |
| 56-00-02 | 00 | 0 | `SCAN-01` | unit | `C:\flutter\bin\flutter.bat test test/services/sqlite_service_phase56_test.dart` | ❌ W0 | ⬜ pending |
| 56-00-03 | 00 | 0 | `SCAN-01` | unit | `C:\flutter\bin\flutter.bat test test/services/sync_service_phase56_test.dart` | ❌ W0 | ⬜ pending |
| 56-00-04 | 00 | 0 | `SCAN-02` | unit | `C:\flutter\bin\flutter.bat test test/services/pattern_detection_service_test.dart` | ❌ W0 | ⬜ pending |
| 56-00-05 | 00 | 0 | `SCAN-01`, `SCAN-02` | contract | `C:\flutter\bin\flutter.bat test test/phase56/attendance_authority_sql_contract_test.dart` | ❌ W0 | ⬜ pending |
| 56-00-06 | 00 | 0 | `SCAN-01` | unit | `C:\flutter\bin\flutter.bat test test/services/live_content_provider_test.dart` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/phase56/kiosk_scan_authority_flow_test.dart` - eligible first-scan UI, break-first confirmation, and live-vs-queued success-state coverage
- [ ] `test/services/sqlite_service_phase56_test.dart` - queue metadata and deterministic ordering coverage
- [ ] `test/services/sync_service_phase56_test.dart` - ordered upload and idempotent retry coverage
- [ ] `test/services/pattern_detection_service_test.dart` - authoritative-vs-provisional timestamp usage coverage
- [ ] `test/phase56/attendance_authority_sql_contract_test.dart` - authoritative field / reconciliation SQL contract coverage

*Existing infrastructure already covers the idle live-content reader baseline via `test/services/live_content_provider_test.dart`.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live scan shows authoritative WITA time with the existing fast auto-close rhythm | `SCAN-01` | Visual timing and copy clarity are hard to prove from unit tests alone | Run one online kiosk scan and confirm the success state shows a WITA timestamp and returns quickly to idle |
| Cached employee can still scan while offline and sees a clearly queued success treatment | `SCAN-01` | Requires connectivity changes and end-to-end queue behavior | Disable connectivity, scan a cached employee, and confirm the result is accepted, visually distinct from live success, and followed by the idle pending signal |
| Uncached employee is blocked gracefully while offline | `SCAN-01` | Depends on cache state and operator messaging | Disable connectivity, try an uncached employee, and confirm the flow asks the operator to retry later instead of creating a pending event |
| Eligible first scan can choose `Istirahat Dulu`, confirm it, and get the next-step hint | `SCAN-02` | Confirmation pacing and copy are UX semantics | Use an employee inside the break-first eligibility window, select `Istirahat Dulu`, confirm it, and verify the success state hints `Selesai Istirahat` |
| Queued events preserve event order after connectivity returns | `SCAN-01`, `SCAN-02` | Requires multi-step offline capture plus later reconciliation | Queue a sequence such as `Istirahat` then `Kembali`, reconnect, and confirm backend/admin history preserves the original order |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
