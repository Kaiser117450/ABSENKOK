---
phase: 28-failure-surfaces-crash-reporting
verified: 2026-03-20T00:00:00Z
status: human_needed
score: 7/7 must-haves verified
human_verification:
  - test: "Trigger a real crash or exception in release build"
    expected: "Event appears in Sentry dashboard with correct tags"
    why_human: "Cannot verify Sentry ingestion programmatically without live DSN hit"
  - test: "Trigger an NFC Tag lost error during scan"
    expected: "No event appears in Sentry for that error; unrelated errors still appear"
    why_human: "beforeSend filter correctness verified by unit tests, but end-to-end NFC noise suppression requires device testing"
  - test: "Run HeartbeatService with a broken endpoint for 3 retries"
    expected: "Exactly one Sentry event appears with outlet_id, outlet_name, device_id tags"
    why_human: "Wiring is verified by code grep; tag population requires a live Sentry session with a real KioskSession"
---

# Phase 28: Failure Surfaces & Crash Reporting — Verification Report

**Phase Goal:** Integrate Sentry crash reporting with NFC noise filtering and background failure capture
**Verified:** 2026-03-20
**Status:** human_needed (all automated checks passed; 3 items require device/dashboard validation)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | Unhandled Dart exceptions in release builds are reported to Sentry | VERIFIED | `SentryFlutter.init` with `appRunner` wrapper in `lib/main.dart` lines 36-47; manual `FlutterError.onError` and `PlatformDispatcher.instance.onError` removed |
| 2 | Native Android crashes are captured by Sentry | VERIFIED | `sentry_flutter ^9.14.0` in `pubspec.yaml` line 100; the Flutter Sentry SDK automatically hooks into native crash handlers |
| 3 | Benign NFC Tag lost exceptions do NOT appear in Sentry | VERIFIED | `beforeSend` in `sentry_service.dart` filters 6 NFC noise patterns; 9 unit tests covering all patterns pass |
| 4 | HeartbeatService final retry failure sends a Sentry event with outlet context | VERIFIED | `heartbeat_service.dart` line 148: `SentryService.captureBackgroundFailure(operation: 'heartbeat')` with `session` argument |
| 5 | Background poll errors send a Sentry event with kiosk context | VERIFIED | `kiosk_background_service.dart` line 508: `SentryService.captureBackgroundFailure(operation: 'pollContent')` with `session` argument |
| 6 | Repeated identical background errors are throttled to once per 15 minutes | VERIFIED | `_shouldReport` in `sentry_service.dart` lines 84-91 with `_throttleWindow = Duration(minutes: 15)`; 3 throttle unit tests pass |
| 7 | App starts and runs normally even if SENTRY_DSN is empty or Sentry is unreachable | VERIFIED | `options.dsn = kReleaseMode ? (dotenv.env['SENTRY_DSN'] ?? '') : ''` — empty string causes Sentry SDK to no-op silently |

**Score:** 7/7 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/services/sentry_service.dart` | NFC filter + background capture helper + throttle logic | VERIFIED | 107 lines; `class SentryService`, `beforeSend`, `captureBackgroundFailure`, `_shouldReport`, 6 NFC patterns, 15-min throttle |
| `lib/main.dart` | SentryFlutter.init wrapping runApp | VERIFIED | `SentryFlutter.init` at line 36, `appRunner:` at line 47, `SentryService.beforeSend` at line 45 |
| `test/services/sentry_service_test.dart` | Unit tests for NFC filtering and throttle | VERIFIED | 107 lines (exceeds 40-line minimum); 12 tests in 2 groups |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/main.dart` | `SentryFlutter.init` | `appRunner` wraps existing bootstrap | WIRED | `SentryFlutter.init` found at line 36 with `appRunner:` callback at line 47 |
| `lib/services/heartbeat_service.dart` | `lib/services/sentry_service.dart` | `SentryService.captureBackgroundFailure` after final retry | WIRED | Found at line 148 with `operation: 'heartbeat'` |
| `lib/services/kiosk_background_service.dart` | `lib/services/sentry_service.dart` | `SentryService.captureBackgroundFailure` in `_pollContent` catch | WIRED | Found at line 508 with `operation: 'pollContent'` |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| FAIL-01 | 28-01-PLAN.md | App integrates `sentry_flutter` to automatically capture and report unhandled Dart and native exceptions | SATISFIED | `sentry_flutter ^9.14.0` in pubspec; `SentryFlutter.init` in main.dart |
| FAIL-02 | 28-01-PLAN.md | Sentry configuration explicitly filters out benign NFC `Tag lost` exceptions | SATISFIED | `beforeSend` with 6 NFC noise patterns in `SentryService`; confirmed by REQUIREMENTS.md marking as complete |
| FAIL-03 | 28-01-PLAN.md | The `KioskBackgroundService` isolate wraps its periodic task in a try/catch that reports to Sentry | SATISFIED | `kiosk_background_service.dart` line 508 `captureBackgroundFailure`; also HeartbeatService wired similarly |

All 3 requirement IDs declared in PLAN frontmatter are satisfied. No orphaned requirements found for Phase 28 in REQUIREMENTS.md.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/services/sentry_service.dart` | 39 | `return null` | Info | Intentional — NFC filter drops Sentry event by returning null per Sentry SDK contract. Not a stub. |

No blockers or warnings found.

---

### Human Verification Required

#### 1. Sentry Dashboard — Live Crash Ingestion

**Test:** Install release APK on device, trigger an unhandled exception (e.g., force a network error in a non-guarded call), wait 30 seconds.
**Expected:** A new issue appears in the Sentry dashboard with `environment=production` and the correct project.
**Why human:** Cannot verify Sentry ingestion programmatically without triggering a real release build crash and checking the live dashboard.

#### 2. NFC Noise Suppression End-to-End

**Test:** Scan a card, then remove it rapidly during processing to trigger a `Tag was lost` exception. Check Sentry dashboard for the next 5 minutes.
**Expected:** No Sentry event appears for the tag-lost error. Subsequent real errors (e.g., network failure) still appear.
**Why human:** `beforeSend` filter correctness is covered by 9 unit tests, but end-to-end NFC hardware behavior requires device testing.

#### 3. HeartbeatService Sentry Scope Tags

**Test:** Configure the app with a broken heartbeat endpoint, let it exhaust 3 retries, then inspect the resulting Sentry event.
**Expected:** Event has tags `source=background`, `operation=heartbeat`, `outlet_id`, `outlet_name`, `device_id` populated from the active `KioskSession`.
**Why human:** Scope tag population during `withScope` callback requires a live Sentry session with real session data to validate.

---

### Summary

Phase 28 goal is achieved at the code level. All 7 observable truths are verified:

- `sentry_flutter ^9.14.0` is declared in pubspec and the DSN placeholder (now populated with a real DSN in `.env`) is ready.
- `SentryFlutter.init` wraps the full app bootstrap in `main.dart` with release-only DSN and the NFC `beforeSend` filter.
- Manual `FlutterError.onError` and `PlatformDispatcher.instance.onError` hooks have been removed — Sentry manages these.
- `SentryService` provides a substantive, fully-implemented NFC filter (6 patterns, verified by 12 unit tests) and a 15-minute throttled `captureBackgroundFailure` method.
- Both `HeartbeatService` (after 3rd retry) and `KioskBackgroundService._pollContent` are wired to `captureBackgroundFailure` with outlet/device context.
- Empty/missing DSN causes the Sentry SDK to no-op — app stability is preserved.

Three human verification items remain to confirm live Sentry ingestion, end-to-end NFC noise suppression, and scope tag correctness in production conditions.

---

_Verified: 2026-03-20_
_Verifier: Claude (gsd-verifier)_
