# Phase 28: Failure Surfaces & Crash Reporting - Research

**Researched:** 2026-03-20
**Domain:** Flutter Sentry integration, NFC exception filtering, background service crash reporting
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Sentry should send events in release builds only.
- Coverage should include the whole app plus kiosk background paths, using the existing global error hooks in `main.dart` and explicit capture in background services.
- Deliberate reporting should focus on infrastructure catches (for example heartbeat/background service failures), not every handled UI or validation exception.
- If Sentry cannot initialize or cannot reach the network, the app must fail open and continue running.
- Suppress the benign `Tag lost` family and equivalent short-lifecycle NFC session noise from Sentry.
- Filtered NFC noise should be ignored fully rather than turned into Sentry breadcrumbs or issues.
- Routine user/card errors such as unsupported cards or normal NFC session hiccups should stay out of Sentry.
- Any new NFC exception that is not covered by the benign filter should be reported until proven harmless.
- Report unexpected infrastructure failures from kiosk background/isolate paths such as heartbeat/service failures.
- Retryable background work should only be reported after final failure, not on every transient failed attempt.
- Repeated identical background failures should be throttled so one kiosk cannot spam Sentry every timer tick.
- Each background event should include outlet/device context, app version, and related heartbeat context so ops can identify the failing kiosk quickly.

### Claude's Discretion
- Exact Sentry initialization wiring and env/DSN loading, as long as it fits the existing config style and remains fail-open.
- Exact implementation of benign NFC filtering, including how message matching and platform exception metadata are combined.
- Exact duplicate-throttling window and fingerprint strategy for repeated background failures.

### Deferred Ideas (OUT OF SCOPE)
- Alert routing from Sentry into chat/email or other ops workflows is a separate capability.
- Richer user/employee identity capture in crash reports beyond outlet/device context can be revisited later if privacy and support needs justify it.
- User-facing diagnostics and force-recovery actions remain in Phase 29.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FAIL-01 | App integrates `sentry_flutter` to automatically capture and report unhandled Dart and native exceptions | `sentry_flutter: ^9.14.0` wraps `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and native Android crash handler in a single `SentryFlutter.init()` call that replaces current `main.dart` error hooks |
| FAIL-02 | Sentry configuration explicitly filters out/ignores benign NFC `Tag lost` exceptions to prevent log spam | `options.beforeSend` callback inspects `event.exceptions` for known NFC noise patterns (message contains "Tag was lost", "tag was lost", "TagLostException"); returns `null` to silently drop |
| FAIL-03 | The `KioskBackgroundService` isolate wraps its periodic task in a try/catch that reports directly to Sentry if a background failure occurs | `Sentry.captureException(exception, stackTrace: stackTrace)` called inside `HeartbeatService._sendHeartbeat()` and `KioskBackgroundService._pollContent()` catch blocks after final retry exhaustion, with Sentry scope tags for outlet/device context |
</phase_requirements>

---

## Summary

Phase 28 adds `sentry_flutter` to the existing app bootstrap so that real failures — native crashes, unhandled Dart exceptions, and background infrastructure errors — are automatically reported to Sentry, while benign NFC session noise is suppressed. The integration touches three files: `main.dart` (initialization + global error hooks), `nfc_service.dart` (benign filter list), and `heartbeat_service.dart` / `kiosk_background_service.dart` (explicit background capture after final failure).

`sentry_flutter` version 9.14.0 is the current stable release and provides `SentryFlutter.init()` which automatically installs a `FlutterError.onError` handler, a `PlatformDispatcher.instance.onError` handler, and an Android native crash reporter. It wraps the entire `runApp()` call inside its `appRunner` callback, giving it full control of the error boundary. The current `main.dart` already has these hooks manually wired (lines 31–38), so the migration replaces them with Sentry's managed equivalents. The DSN is loaded from `.env` via `flutter_dotenv` (already the runtime config pattern), and `options.environmentAttributesFromOs` is left at default. Setting `options.debug = false` and checking `kReleaseMode` before providing the DSN ensures no events are sent during development.

The NFC filter uses `options.beforeSend` — the standard Sentry callback that runs immediately before an event is dispatched. The callback inspects the exception message string for known benign patterns (`Tag was lost`, `tag was lost`, Android's `TagLostException`, `NFC session invalidated`). Returning `null` from `beforeSend` drops the event completely without generating a breadcrumb or issue.

**Primary recommendation:** Add `sentry_flutter: ^9.14.0`. Wire into `main.dart` as the outermost wrapper. Use `beforeSend` for NFC filtering. Use `Sentry.captureException()` with scope tags for background-only explicit captures after final retry failure.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| sentry_flutter | ^9.14.0 | Automatic unhandled exception capture, native crash reporting, `beforeSend` filtering, scope tags | Official Sentry Flutter SDK; 99% coverage on pub.dev scores; wraps both Dart and Android/iOS native layers |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_dotenv | already ^5.2.1 | Load `SENTRY_DSN` from `.env` at runtime | Already used for Supabase config; same pattern for Sentry DSN |
| package_info_plus | already ^8.1.0 | Provide app version to Sentry `release` tag | Already a dependency from Phase 27 heartbeat |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| sentry_flutter | Firebase Crashlytics | Crashlytics requires Firebase project setup, Google account linking, and `google-services.json`; Sentry is standalone and simpler for this project |
| sentry_flutter | Custom crash logging to Supabase table | Misses native crashes, has no deduplication/grouping, no alerting infrastructure |
| beforeSend filter | Sentry inbound filters (server-side) | Server-side filters require Sentry dashboard config per project; client-side `beforeSend` is version-controlled and doesn't waste Sentry quota on dropped events |

**Installation (add to pubspec.yaml dependencies):**
```yaml
# Crash reporting (Phase 28)
sentry_flutter: ^9.14.0
```

**Version verification (confirmed 2026-03-20):**
- `sentry_flutter` 9.14.0: latest stable on pub.dev; no Kotlin 2.x requirement
- No new dependencies introduced besides `sentry_flutter` (which pulls `sentry` core as a transitive dependency)

---

## Architecture Patterns

### Recommended File Changes
```
lib/
├── main.dart                                    # Wrap bootstrap in SentryFlutter.init()
├── services/sentry_service.dart                 # NEW: NFC filter, background capture helpers, throttle logic
├── services/nfc_service.dart                    # No changes (filter lives in sentry_service)
├── services/heartbeat_service.dart              # Add Sentry.captureException after final retry failure
├── services/kiosk_background_service.dart       # Add Sentry.captureException in _pollContent catch
.env                                             # Add SENTRY_DSN key
```

### Pattern 1: SentryFlutter.init as Outermost Wrapper
**What:** Replace current manual error hooks with Sentry's managed `appRunner` callback.
**When to use:** App bootstrap — must be the first thing after `WidgetsFlutterBinding.ensureInitialized()`.

```dart
// Source: https://docs.sentry.io/platforms/flutter/#configure
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: '.env');
  
  await SentryFlutter.init(
    (options) {
      options.dsn = kReleaseMode ? dotenv.env['SENTRY_DSN'] ?? '' : '';
      options.tracesSampleRate = 0; // no performance tracing (error-only)
      options.beforeSend = _beforeSend; // NFC filter
      options.environment = kReleaseMode ? 'production' : 'development';
      options.debug = false;
      // Sentry reads version from native metadata automatically
    },
    appRunner: () async {
      // ... existing initialization (locale, Supabase, SQLite, NFC) ...
      runApp(const ProviderScope(child: AbsensiEnakkoApp()));
    },
  );
}
```

**Key behavior:** When `dsn` is empty string, `SentryFlutter.init` completes without error but sends nothing — this is the official "disable" pattern for debug builds. The `appRunner` callback replaces the outer `runApp()` call.

### Pattern 2: beforeSend NFC Filter
**What:** Drop benign NFC exceptions before they reach Sentry.
**When to use:** In `options.beforeSend` during `SentryFlutter.init`.

```dart
// Source: https://docs.sentry.io/platforms/flutter/configuration/filtering/
FutureOr<SentryEvent?> _beforeSend(SentryEvent event, Hint hint) {
  final exceptions = event.exceptions ?? [];
  for (final ex in exceptions) {
    final msg = (ex.value ?? '').toLowerCase();
    if (_isNfcNoise(msg)) return null; // drop silently
  }
  return event;
}

bool _isNfcNoise(String message) {
  const patterns = [
    'tag was lost',
    'tag connection lost',
    'taglostexception',
    'nfc session invalidated',
    'transceive fail',
    'tipe kartu nfc tidak didukung', // app's own unsupported-card message
  ];
  return patterns.any((p) => message.contains(p));
}
```

**Design rationale:** The filter matches on lowercase message substrings rather than exception types because Android's NFC errors arrive as `PlatformException` with the real cause in the message field, not in the exception type. The list errs on the side of suppression for known-benign messages. Any NFC exception whose message does NOT match any pattern will pass through — honoring CONTEXT.md's "report until proven harmless" requirement.

### Pattern 3: Explicit Background Capture with Scope Tags
**What:** After final retry failure in background services, explicitly send to Sentry with kiosk context.
**When to use:** In catch blocks where retries are exhausted and the error should be reported.

```dart
// Source: Sentry docs + CONTEXT.md background failure decisions
static Future<void> _captureBackgroundFailure(
  Object exception,
  StackTrace stackTrace,
  String operation,
  KioskSession? session,
) async {
  if (!SentryService.shouldReport(operation)) return;  // throttle check
  
  await Sentry.captureException(
    exception,
    stackTrace: stackTrace,
    withScope: (scope) {
      scope.setTag('source', 'background');
      scope.setTag('operation', operation);
      if (session != null) {
        scope.setTag('outlet_id', session.outletId);
        scope.setTag('outlet_name', session.outletName);
        scope.setTag('device_id', session.deviceId);
      }
      scope.setContexts('kiosk', {
        'outlet_id': session?.outletId,
        'outlet_name': session?.outletName,
        'device_id': session?.deviceId,
      });
    },
  );
}
```

### Pattern 4: Duplicate Throttle for Background Reports
**What:** Prevent one kiosk from spamming Sentry with repeated identical errors every timer tick.
**When to use:** Before any `Sentry.captureException` call from background paths.

```dart
// In SentryService
static final _lastReportedAt = <String, DateTime>{};
static const _throttleWindow = Duration(minutes: 15);

static bool shouldReport(String fingerprint) {
  final now = DateTime.now();
  final last = _lastReportedAt[fingerprint];
  if (last != null && now.difference(last) < _throttleWindow) {
    return false; // throttled
  }
  _lastReportedAt[fingerprint] = now;
  return true;
}
```

**Fingerprint strategy:** Use `'$operation:${exception.runtimeType}'` as the key — this groups by operation (e.g. `heartbeat`, `pollContent`) and exception type, so different errors from the same operation are reported independently, but the same error repeating every tick is throttled.

### Anti-Patterns to Avoid
- **Wrapping every catch block with Sentry.captureException:** Only infrastructure failures should be reported. Validation errors, UI state issues, and handled business logic exceptions should NOT be sent to Sentry.
- **Setting `tracesSampleRate > 0` without explicit need:** Performance tracing generates significant data volume. This phase is error-only.
- **Using `Sentry.captureMessage` for exceptions:** Use `captureException` to preserve exception type and stack trace for proper grouping.
- **Matching NFC filter by exception type only:** Android NFC errors arrive as generic `PlatformException` — the real signal is in the message, not the type.
- **Forgetting `kReleaseMode` guard on DSN:** Debug builds would pollute the Sentry project with developer errors.
- **Initializing Sentry inside a try-catch that blocks app startup:** If `.env` has no DSN or Sentry servers are unreachable, the app must still start normally (fail-open).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Global unhandled exception capture | Manual `FlutterError.onError` + `PlatformDispatcher.onError` | `SentryFlutter.init(appRunner:)` | Sentry's wrapper handles both Dart and native crashes, plus manages breadcrumbs automatically |
| Native Android crash reporting | Custom `Thread.setDefaultUncaughtExceptionHandler` in Kotlin | `sentry_flutter` native integration | Sentry installs its own NDK handler and Java handler; custom code would conflict |
| Event deduplication/grouping | Custom fingerprint logic per error | Sentry server-side grouping | Sentry groups by stack trace and exception type by default; no client-side logic needed beyond throttle |
| Crash reporting dashboard | Custom Supabase table + admin screen | Sentry web dashboard | Sentry provides search, charts, alerts, release tracking, and source map support |

**Key insight:** The entire value of integrating Sentry is that it handles the hard problems (native crash capture, event grouping, rate limiting, alerting) that are not feasible to replicate in app code.

---

## Common Pitfalls

### Pitfall 1: Empty DSN vs No Init
**What goes wrong:** Passing an empty string to `options.dsn` is the official way to disable Sentry. Omitting `SentryFlutter.init` entirely means `Sentry.captureException` calls elsewhere throw or no-op silently depending on SDK version.
**Why it happens:** Developers sometimes skip init in debug builds instead of passing empty DSN.
**How to avoid:** Always call `SentryFlutter.init`. Use `kReleaseMode ? dsn : ''` to disable in debug.
**Warning signs:** `Sentry.captureException` logs "Sentry SDK is disabled" in debug console.

### Pitfall 2: dotenv Load Order
**What goes wrong:** `dotenv.env['SENTRY_DSN']` returns null because `.env` hasn't been loaded yet.
**Why it happens:** The current `main.dart` loads dotenv at line 54, but `SentryFlutter.init` must wrap the entire bootstrap.
**How to avoid:** Move `await dotenv.load()` BEFORE `SentryFlutter.init()`, outside the `appRunner` callback.
**Warning signs:** Sentry reports no events in production despite DSN being in `.env`.

### Pitfall 3: Sentry init Blocking App Startup
**What goes wrong:** If Sentry's HTTP transport times out on first init (e.g., device offline), the app appears frozen.
**Why it happens:** `SentryFlutter.init` does minimal network I/O internally but developer might add awaited network calls inside it.
**How to avoid:** `SentryFlutter.init` itself is fail-safe. Do NOT add custom network validation inside options. Let init complete; if offline, events queue locally.
**Warning signs:** App startup takes >5 seconds in airplane mode.

### Pitfall 4: beforeSend Returns null for Wanted Exceptions
**What goes wrong:** NFC filter is too broad and drops real exceptions that happen to contain substring matches.
**Why it happens:** Overly aggressive substring matching (e.g., matching "lost" catches "data lost during migration").
**How to avoid:** Match on specific phrases: "tag was lost", "tag connection lost", "taglostexception", "nfc session invalidated", "transceive fail". Not single words.
**Warning signs:** Real crashes disappear from Sentry dashboard.

### Pitfall 5: Sentry in Background Isolates
**What goes wrong:** `Sentry.captureException` does nothing in `_KioskTaskHandler.onRepeatEvent` (runs in a separate isolate).
**Why it happens:** Sentry's Dart SDK maintains state in the main isolate. Background isolates don't share the Sentry hub.
**How to avoid:** All explicit Sentry capture calls should be in the main isolate. The codebase already follows this pattern — heartbeat and polling run in the main isolate via `Timer.periodic`, NOT in the foreground task isolate. `_KioskTaskHandler.onRepeatEvent` is a no-op.
**Warning signs:** Background errors logged via debugPrint but never appear in Sentry.

### Pitfall 6: Reporting Every Transient Retry
**What goes wrong:** A heartbeat that fails 3 times sends 3 Sentry events instead of 1.
**Why it happens:** Capturing exception inside the retry loop instead of after the final failure.
**How to avoid:** Only call `Sentry.captureException` after the last retry is exhausted (attempt == 2 in the current 3-attempt loop).
**Warning signs:** Sentry event count spikes 3x during network outages.

---

## Code Examples

### main.dart Rewrite (Full Bootstrap)
```dart
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'overlay_task.dart';
import 'services/nfc_service.dart';
import 'services/sentry_service.dart';
import 'services/sqlite_service.dart';

bool supabaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env BEFORE SentryFlutter.init (need SENTRY_DSN)
  await dotenv.load(fileName: '.env');

  await SentryFlutter.init(
    (options) {
      // Only send events in release builds
      options.dsn = kReleaseMode ? (dotenv.env['SENTRY_DSN'] ?? '') : '';
      options.environment = kReleaseMode ? 'production' : 'development';
      options.tracesSampleRate = 0; // error monitoring only
      options.debug = false;
      options.beforeSend = SentryService.beforeSend;
    },
    appRunner: () async {
      // Date locale
      await initializeDateFormatting('id_ID', null);
      Intl.defaultLocale = 'id_ID';

      // Lock portrait
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      // Status bar
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      );

      // Supabase init
      try {
        await Supabase.initialize(
          url: dotenv.env['SUPABASE_URL']!,
          anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );
        supabaseReady = true;
      } catch (e) {
        debugPrint('[main] Supabase.initialize error: $e');
      }

      // SQLite
      await SqliteService.getDatabase();

      // NFC (3s timeout)
      await NfcService.init().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('[main] NfcService.init() timed out');
          return false;
        },
      );

      runApp(const ProviderScope(child: AbsensiEnakkoApp()));
    },
  );
}
```

### SentryService Helper
```dart
// lib/services/sentry_service.dart
import 'dart:async';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../models/kiosk_session.dart';

class SentryService {
  // ── NFC noise patterns (lowercase) ──
  static const _nfcNoisePatterns = [
    'tag was lost',
    'tag connection lost',
    'taglostexception',
    'nfc session invalidated',
    'transceive fail',
    'tipe kartu nfc tidak didukung',
  ];

  // ── Throttle state ──
  static final _lastReportedAt = <String, DateTime>{};
  static const _throttleWindow = Duration(minutes: 15);

  /// beforeSend callback — drop benign NFC noise
  static FutureOr<SentryEvent?> beforeSend(
    SentryEvent event,
    Hint hint,
  ) {
    final exceptions = event.exceptions ?? [];
    for (final ex in exceptions) {
      final msg = (ex.value ?? '').toLowerCase();
      if (_isNfcNoise(msg)) return null;
    }
    return event;
  }

  static bool _isNfcNoise(String message) {
    return _nfcNoisePatterns.any((p) => message.contains(p));
  }

  /// Report background infrastructure failure with kiosk context.
  /// Throttled per operation+exceptionType to prevent spam.
  static Future<void> captureBackgroundFailure({
    required Object exception,
    required StackTrace stackTrace,
    required String operation,
    KioskSession? session,
  }) async {
    final fingerprint = '$operation:${exception.runtimeType}';
    if (!_shouldReport(fingerprint)) return;

    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('source', 'background');
        scope.setTag('operation', operation);
        if (session != null) {
          scope.setTag('outlet_id', session.outletId);
          scope.setTag('outlet_name', session.outletName);
          scope.setTag('device_id', session.deviceId);
        }
      },
    );
  }

  static bool _shouldReport(String fingerprint) {
    final now = DateTime.now();
    final last = _lastReportedAt[fingerprint];
    if (last != null && now.difference(last) < _throttleWindow) {
      return false;
    }
    _lastReportedAt[fingerprint] = now;
    return true;
  }
}
```

### HeartbeatService Integration Point
```dart
// In HeartbeatService._sendWithRetry(), after final failure:
static Future<void> _sendWithRetry(
  Map<String, dynamic> payload,
  String outletId,
) async {
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      await Supabase.instance.client
          .from('outlets')
          .update(payload)
          .eq('id', outletId);
      return; // success
    } catch (e, stack) {
      if (attempt == 2) {
        debugPrint('[Heartbeat] _sendWithRetry failed after 3 attempts: $e');
        // Report to Sentry only after final failure
        await SentryService.captureBackgroundFailure(
          exception: e,
          stackTrace: stack,
          operation: 'heartbeat',
          session: _session,
        );
        return;
      }
      final delaySeconds = 2 * (attempt + 1);
      debugPrint('[Heartbeat] retry ${attempt + 1} in ${delaySeconds}s: $e');
      await Future.delayed(Duration(seconds: delaySeconds));
    }
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `sentry` (Dart-only) | `sentry_flutter` (Dart + native) | sentry_flutter 4.0+ | `sentry_flutter` captures native Android/iOS crashes that pure-Dart `sentry` misses |
| Manual `runZonedGuarded` + `FlutterError.onError` | `SentryFlutter.init(appRunner:)` wraps both automatically | sentry_flutter 6.0+ | Eliminates boilerplate; Sentry manages the error boundary |
| `options.beforeSend` was `BeforeSendCallback` | Now `FutureOr<SentryEvent?>` (sync or async) | sentry_flutter 7.0+ | Allows async operations in filter if needed |
| Separate `sentry_dart_plugin` for debug symbols | Still separate but optional | Current | Not needed for this phase (error reporting only, no ProGuard obfuscation mapping) |

**Deprecated/outdated:**
- `sentry` (non-flutter): Does not capture native crashes. Always use `sentry_flutter` in Flutter projects.
- `runZonedGuarded` wrapping: Sentry's `appRunner` handles this internally; adding a manual zone guard causes double-reporting.

---

## Open Questions

1. **SENTRY_DSN provisioning**
   - What we know: A Sentry project needs to be created at sentry.io to obtain a DSN.
   - What's unclear: Whether the user already has a Sentry account/project set up.
   - Recommendation: Planner should include a task for adding `SENTRY_DSN=` to `.env` with a placeholder, and document that the user must create a Sentry project and paste the real DSN. The app works fine (sends nothing) with an empty DSN.

2. **`sentry_flutter` interaction with `flutter_foreground_task` isolate**
   - What we know: `_KioskTaskHandler.onRepeatEvent` runs in a separate isolate. Sentry hub is NOT available there.
   - What's unclear: Whether `sentry_flutter` 9.x has improved isolate support.
   - Recommendation: Keep all Sentry calls in the main isolate. The codebase already runs heartbeat and polling logic in the main isolate. The foreground task isolate's `onRepeatEvent` is a no-op used only for keep-alive.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK built-in, already in dev_dependencies) |
| Config file | none — standard `flutter test` invocation |
| Quick run command | `flutter test test/services/sentry_service_test.dart` |
| Full suite command | `flutter test test/` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FAIL-01 | SentryFlutter.init wiring in main.dart (release-only DSN, appRunner wrapping) | manual-only | Manual: verify main.dart structure matches pattern | N/A — structural verification |
| FAIL-02 | SentryService.beforeSend returns null for NFC noise patterns, returns event for non-NFC | unit | `flutter test test/services/sentry_service_test.dart` | ❌ Wave 0 |
| FAIL-03 | SentryService.captureBackgroundFailure calls Sentry.captureException with correct scope tags; throttle prevents duplicate reports within 15 min | unit | `flutter test test/services/sentry_service_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/services/sentry_service_test.dart`
- **Per wave merge:** `flutter test test/`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/services/sentry_service_test.dart` — covers FAIL-02 (beforeSend filtering) and FAIL-03 (captureBackgroundFailure throttle + scope tags)

*(Note: FAIL-01 is a structural wiring task in `main.dart` — best verified by code review + release build test, not unit test. The `SentryFlutter.init` call itself is a framework entry point that cannot be unit-tested without mocking the entire Sentry SDK.)*

---

## Sources

### Primary (HIGH confidence)
- [sentry_flutter pub.dev](https://pub.dev/packages/sentry_flutter) — version 9.14.0 confirmed as latest stable
- [Sentry Flutter docs — Configure](https://docs.sentry.io/platforms/flutter/#configure) — `SentryFlutter.init` with `appRunner`, DSN, options
- [Sentry Flutter docs — Filtering](https://docs.sentry.io/platforms/flutter/configuration/filtering/) — `options.beforeSend` callback signature and behavior
- Codebase: `lib/main.dart` — current error hooks at lines 31-38, dotenv load at line 54
- Codebase: `lib/services/nfc_service.dart` — NFC error handling in `startListener` and `startRegistrationListener`
- Codebase: `lib/services/heartbeat_service.dart` — retry loop in `_sendWithRetry` (3 attempts, final failure at attempt==2)
- Codebase: `lib/services/kiosk_background_service.dart` — `_pollContent` catch block, `_KioskTaskHandler` isolate structure
- Codebase: `lib/models/kiosk_session.dart` — `outletId`, `outletName`, `deviceId` fields for scope tags

### Secondary (MEDIUM confidence)
- [Sentry Flutter GitHub](https://github.com/getsentry/sentry-dart) — isolate support limitations confirmed in issues
- Web search: `sentry_flutter` beforeSend NFC filtering patterns — confirmed `PlatformException` message matching is standard approach

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — `sentry_flutter` 9.14.0 confirmed on pub.dev, no Kotlin 2.x requirement
- Architecture: HIGH — `SentryFlutter.init(appRunner:)` pattern is official and well-documented; `beforeSend` signature verified from Sentry docs
- NFC filter: HIGH — based on direct codebase analysis of NFC error messages in `nfc_service.dart` + known Android `TagLostException` pattern
- Background capture: HIGH — `Sentry.captureException` with `withScope` is standard API; throttle pattern is straightforward
- Pitfalls: HIGH — isolate limitation confirmed by both Sentry docs and codebase structure (heartbeat runs in main isolate)

**Research date:** 2026-03-20
**Valid until:** 2026-06-20 (stable SDK; re-check if sentry_flutter major version changes)
