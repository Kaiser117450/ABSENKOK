---
phase: 28-failure-surfaces-crash-reporting
plan: "01"
subsystem: crash-reporting
tags: [sentry, crash-reporting, nfc-filter, background-services]
dependency_graph:
  requires: []
  provides: [sentry-integration, nfc-noise-filter, background-failure-capture]
  affects: [lib/main.dart, lib/services/heartbeat_service.dart, lib/services/kiosk_background_service.dart]
tech_stack:
  added: [sentry_flutter ^9.14.0]
  patterns: [SentryFlutter.init appRunner wrapper, beforeSend NFC filter, throttled background capture]
key_files:
  created:
    - lib/services/sentry_service.dart
    - test/services/sentry_service_test.dart
  modified:
    - pubspec.yaml
    - lib/main.dart
    - lib/services/heartbeat_service.dart
    - lib/services/kiosk_background_service.dart
decisions:
  - "Release-only DSN: kReleaseMode guard ensures no Sentry traffic in dev/test builds"
  - "Throttle fingerprint is operation:exceptionType — prevents 15-min alert floods from retry storms"
  - "beforeSend drops entire event if any exception matches NFC noise — conservative filter"
metrics:
  duration_seconds: 385
  completed_date: "2026-03-20"
  tasks_completed: 2
  files_changed: 6
---

# Phase 28 Plan 01: Sentry Integration — Crash Reporting with NFC Filter Summary

**One-liner:** sentry_flutter ^9.14.0 integrated with release-only DSN, 6-pattern NFC noise filter in beforeSend, and throttled background failure capture (15-min window) wired into HeartbeatService and KioskBackgroundService.

## What Was Built

### SentryService (`lib/services/sentry_service.dart`)
- `beforeSend` hook filtering 6 NFC noise patterns: `tag was lost`, `tag connection lost`, `taglostexception`, `nfc session invalidated`, `transceive fail`, `tipe kartu nfc tidak didukung`
- `captureBackgroundFailure` with 15-minute per-fingerprint throttle (fingerprint = `operation:exceptionType`)
- Scope tags: `source=background`, `operation`, `outlet_id`, `outlet_name`, `device_id`
- `@visibleForTesting` helpers `resetThrottleForTesting()` and `shouldReportForTesting()` for unit test access

### main.dart bootstrap
- `SentryFlutter.init` wraps all bootstrap code in `appRunner` callback
- DSN only loaded in `kReleaseMode` — dev builds use empty DSN (Sentry SDK no-ops)
- Removed manual `FlutterError.onError` and `PlatformDispatcher.instance.onError` — Sentry manages these
- `dotenv.load` moved before `SentryFlutter.init` so DSN is available at init time

### Background service wiring
- `HeartbeatService._sendWithRetry`: `catch (e, stack)` added, `SentryService.captureBackgroundFailure(operation: 'heartbeat')` called after 3rd retry failure
- `KioskBackgroundService._pollContent`: `catch (e, stack)` added, `SentryService.captureBackgroundFailure(operation: 'pollContent')` called with session context

## Tests

12 unit tests in `test/services/sentry_service_test.dart`:
- 9 `beforeSend` NFC filter tests (all 6 noise patterns + 3 pass-through cases)
- 3 throttle tests (first call, throttled second call, different fingerprint passes)

All 193 existing tests continue passing (25 pre-existing failures in streak_service_test stubs unchanged).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SentryEvent() constructor is not const**
- **Found during:** Task 1, GREEN phase
- **Issue:** Test file used `const event = SentryEvent()` which fails compilation since SentryEvent has no const constructor
- **Fix:** Changed to `final event = SentryEvent()`
- **Files modified:** test/services/sentry_service_test.dart

None of architectural significance — plan executed as written.

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Release-only DSN via kReleaseMode | No Sentry traffic during development or test runs |
| Throttle fingerprint = operation:exceptionType | Prevents 15-min floods from retry storms without losing distinct failure types |
| beforeSend drops event if any exception is NFC noise | Conservative — avoids partial NFC noise leaking through multi-exception events |

## Self-Check: PASSED

- lib/services/sentry_service.dart: FOUND
- test/services/sentry_service_test.dart: FOUND
- commit 6d8e799 (Task 1): FOUND
- commit d691dce (Task 2): FOUND
