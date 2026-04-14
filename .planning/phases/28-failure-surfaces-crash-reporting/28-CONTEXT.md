# Phase 28: Failure Surfaces & Crash Reporting - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Integrate Sentry into the existing app bootstrap and kiosk background paths so real Dart/native failures are reported, benign NFC session noise is suppressed, and kiosk background failures stop disappearing into local logs. This phase is about capture/filter/reporting behavior only; user-facing recovery tools and admin warning surfaces stay in later phases.

</domain>

<decisions>
## Implementation Decisions

### Reporting scope
- Sentry should send events in release builds only.
- Coverage should include the whole app plus kiosk background paths, using the existing global error hooks in `main.dart` and explicit capture in background services.
- Deliberate reporting should focus on infrastructure catches (for example heartbeat/background service failures), not every handled UI or validation exception.
- If Sentry cannot initialize or cannot reach the network, the app must fail open and continue running.

### NFC filtering
- Suppress the benign `Tag lost` family and equivalent short-lifecycle NFC session noise from Sentry.
- Filtered NFC noise should be ignored fully rather than turned into Sentry breadcrumbs or issues.
- Routine user/card errors such as unsupported cards or normal NFC session hiccups should stay out of Sentry.
- Any new NFC exception that is not covered by the benign filter should be reported until proven harmless.

### Background failure reporting
- Report unexpected infrastructure failures from kiosk background/isolate paths such as heartbeat/service failures.
- Retryable background work should only be reported after final failure, not on every transient failed attempt.
- Repeated identical background failures should be throttled so one kiosk cannot spam Sentry every timer tick.
- Each background event should include outlet/device context, app version, and related heartbeat context so ops can identify the failing kiosk quickly.

### Claude's Discretion
- Exact Sentry initialization wiring and env/DSN loading, as long as it fits the existing config style and remains fail-open.
- Exact implementation of benign NFC filtering, including how message matching and platform exception metadata are combined.
- Exact duplicate-throttling window and fingerprint strategy for repeated background failures.

</decisions>

<specifics>
## Specific Ideas

- Crash reporting should surface real unattended-kiosk failures without drowning in normal scan-noise.
- Background reports must be actionable enough that someone can tell which outlet/device is unstable from the event itself.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/main.dart`: Already centralizes app bootstrap, `flutter_dotenv`, `FlutterError.onError`, and `PlatformDispatcher.instance.onError`.
- `lib/services/nfc_service.dart`: Single choke point for NFC processing errors and session errors, making it the right place for benign-noise filtering.
- `lib/services/kiosk_background_service.dart`: Existing foreground-task shell with task-handler lifecycle hooks that currently only log.
- `lib/services/heartbeat_service.dart`: Background reliability path that already retries locally and logs failures, making it a natural explicit-capture point.
- `lib/models/kiosk_session.dart`: Already carries `outletId`, `outletName`, and `deviceId` for kiosk-specific event context.

### Established Patterns
- Runtime configuration is loaded through `flutter_dotenv` in `main.dart`.
- Global uncaught errors are already intercepted at app startup, but today they only go to `debugPrint`.
- Services generally swallow handled exceptions after local logging instead of escalating them to a reporting backend.
- Phase 27 already introduced heartbeat/device metadata that can enrich background crash reports.

### Integration Points
- `pubspec.yaml` currently has no Sentry dependency or config.
- `lib/main.dart` is the integration point for Sentry initialization and top-level error hooks.
- `lib/services/nfc_service.dart` is the integration point for benign NFC filtering.
- `lib/services/kiosk_background_service.dart` and `lib/services/heartbeat_service.dart` are the integration points for explicit background/isolate capture and deduped reporting.

</code_context>

<deferred>
## Deferred Ideas

- Alert routing from Sentry into chat/email or other ops workflows is a separate capability.
- Richer user/employee identity capture in crash reports beyond outlet/device context can be revisited later if privacy and support needs justify it.
- User-facing diagnostics and force-recovery actions remain in Phase 29.

</deferred>

---

*Phase: 28-failure-surfaces-crash-reporting*
*Context gathered: 2026-03-20*
