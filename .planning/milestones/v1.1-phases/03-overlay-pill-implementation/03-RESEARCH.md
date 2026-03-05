# Phase 3: Overlay Pill Implementation - Research

**Researched:** 2026-03-01  
**Domain:** Flutter overlay isolate + Android lifecycle/permission flow  
**Confidence:** MEDIUM-HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Persistent Overlay Behavior
- Primary behavior is persistent overlay in background/minimized state, not scan-trigger-only overlay.
- Pill stays visible above other apps and can be toggled between expanded/minimized by tap.
- When scan-event presentation appears, it should return to persistent idle state (not fully disappear).
- Overlay visibility while app is foregrounded should be user-configurable (toggle setting).

### Visual Hierarchy and Content
- Use compact 2-line density for expanded presentation.
- Keep identity as text + brand micro-logo (no employee avatar requirement).
- Show attendance type with accent color and keep it visible in persistent state.
- Time format should remain local `HH:mm`.

### Motion and Transitions
- Keep slide-down + fade with subtle spring feel for event/state transitions.
- Existing event entrance implementation is considered already handled; do not re-scope heavily into scan animation redesign.
- Prioritize stable persistent behavior over adding new decorative continuous motion.

### Permission and Failure Handling
- If overlay permission is denied, show guided re-enable prompt (including OEM-specific guidance).
- Re-check overlay permission on each kiosk start for reliability on OEM-modified Android.
- Trigger persistent overlay when app goes to background/minimized state.
- If overlay rendering fails, show toast feedback (not silent).

### Claude's Discretion
- Exact typography/spacing tokens inside the compact pill.
- Exact implementation of foreground visibility toggle UI and storage.
- Exact fallback wording for permission/error messages.
- Internal state model for idle vs event overlay rendering, as long as it preserves persistent behavior.

### Deferred Ideas (OUT OF SCOPE)
- Detailed bug-fix list mentioned by user but not enumerated in this session should be captured as explicit TODO/phase backlog items.
- Any new capabilities beyond persistent live activity (outside this boundary) should be planned as separate future phases.
</user_constraints>

<phase_requirements>
## Phase Requirements (Mapped from REQUIREMENTS.md)

| ID | Description | Research Support |
|----|-------------|-----------------|
| REQ-M2-01 | Persistent live-activity overlay on background/minimize, state return to idle, permission/failure handling | Overlay state model, lifecycle wiring, permission hardening, fallback toast pattern |
| REQ-M2-02 | Premium compact dark pill with accent/type/time and expanded/minimized quality | Overlay UI layout/density, accent mapping from existing attendance model, animation pattern |
</phase_requirements>

## Summary

Phase 3 should be planned as an enhancement of an existing overlay foundation, not a greenfield feature. The project already has an overlay entrypoint (`lib/overlay_task.dart`), lifecycle triggers (`lib/app.dart`), and background orchestration (`lib/services/kiosk_background_service.dart`). The main gap is state architecture: current overlay payload is just `outlet|time`, so there is no explicit idle-vs-event model, no attendance type/accent pipeline, and no foreground visibility policy setting.

Current behavior also has stability risks that planning should address directly. `showOverlayPill()` closes any active overlay before re-showing it, which can create flicker and full-dismiss behavior during updates. On `resumed`, app lifecycle currently always hides overlay, so no user-configurable foreground policy exists yet. Overlay failures are swallowed with debug logs only, while phase acceptance requires explicit user feedback.

**Primary recommendation:** Plan this phase around a typed overlay state contract and a single overlay controller path that updates data in-place (without close/reopen), then wire lifecycle + settings + permission/fallback behavior around that contract.

## Standard Stack

### Core
| Library | Version (locked) | Purpose | Why Standard Here |
|---------|------------------|---------|-------------------|
| `flutter_overlay_window` | `0.5.0` | Floating overlay window + data channel | Already integrated (`overlayMain`, `showOverlay`, `overlayListener`) |
| `flutter_foreground_task` | `8.17.0` | Keep kiosk process alive in background | Already used in kiosk background service start/stop |
| `flutter_local_notifications` | `18.0.1` | Notification fallback when MethodChannel path fails | Existing fallback path already implemented |
| `shared_preferences` | `2.5.4` | Persist kiosk and simple device settings | Existing app session persistence pattern |
| `flutter_riverpod` | `2.6.1` | App-level state/lifecycle read access | Existing app architecture |
| `toastification` | `2.3.0` | Failure warning toasts | Already used in kiosk screens |

### Supporting Existing Assets
| Asset | Location | Use in Phase 3 |
|------|----------|----------------|
| Attendance accent mapping | `lib/models/attendance_log.dart` (`AttendanceTypeExt.color`) | Direct source for pill accent color |
| Guided overlay permission dialog + MIUI bridge | `lib/screens/kiosk/kiosk_idle_screen.dart` + `MainActivity.kt` (`openMiuiPermissions`) | Reuse, do not duplicate flow |
| Live notification fallback architecture | `lib/services/kiosk_background_service.dart` + `KioskNotificationHelper.kt` | Reference pattern for result-based fallback |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing `flutter_overlay_window` | Build native custom overlay service from scratch | Higher complexity, unnecessary for this phase |
| Riverpod + SharedPreferences setting | SQL/local DB backed setting | Overkill for single kiosk visibility toggle |

## Architecture Patterns

### Recommended Project Structure (within existing files)
```
lib/
|-- overlay_task.dart                        # Overlay isolate UI + state transitions
|-- services/kiosk_background_service.dart   # Overlay controller + lifecycle-safe show/update/hide API
|-- app.dart                                 # AppLifecycleState policy wiring
|-- providers/app_provider.dart              # Foreground visibility preference state
`-- screens/kiosk/kiosk_idle_screen.dart     # Guided permission UX reuse + settings entrypoint
```

### Pattern 1: Versioned Overlay Payload Contract
**What:** Replace delimiter payload (`outlet|time`) with JSON payload carrying `mode`, `outlet`, `time`, `attendanceType`, `accent`, and transition metadata.  
**When to use:** Every overlay data push from app/service to isolate.  
**Why:** Prevents schema drift and enables explicit idle/event transitions.

```dart
// Recommended payload shape (Dart-side contract)
{
  "v": 1,
  "mode": "idle" | "event",
  "outlet": "Outlet Name",
  "time": "HH:mm",
  "attendanceType": "masuk|break|kembali|pulang|sakit|izin",
  "accentHex": "#22C55E",
  "eventUntilEpochMs": 0,
  "expanded": true
}
```

Implementation note: keep a parser fallback for legacy `outlet|time` during migration to avoid breaking old callers.

### Pattern 2: Single Overlay Controller API (No Recreate on Update)
**What:** In `KioskBackgroundService`, split overlay operations into:
- `ensureOverlayVisible(...)`
- `updateOverlayState(...)`
- `hideOverlay(...)`

**When to use:** App lifecycle events, scan success events, periodic clock updates.  
**Why:** Current close-then-show strategy causes flicker and can violate "return to idle, not dismiss".

Planner guidance:
- Only call `showOverlay()` if overlay is not active.
- If active, push new payload via `shareData` only.
- Reserve `closeOverlay()` for explicit hide policy or kiosk stop.

### Pattern 3: Idle/Event State Machine Inside `overlay_task.dart`
**What:** Add explicit render state with timed event reversion.
- `idle` is persistent baseline.
- `event` overlays temporary attendance update.
- Event timeout returns to idle without closing overlay.

**When to use:** Attendance submission success, state transition highlights.  
**Why:** Matches locked decision that event state must return to persistent idle.

### Pattern 4: Foreground Visibility Policy as Persisted Setting
**What:** Add boolean setting (e.g. `overlay_keep_when_foreground`) in SharedPreferences and app state.  
**When to use:** In `didChangeAppLifecycleState` on `resumed` and background transitions.  
**Why:** Requirement explicitly needs configurable behavior while app is active.

Recommended default: `false` (hide in foreground) to preserve current behavior until user opts in.

### Pattern 5: Permission-Oriented Overlay Result Model
**What:** Make `showOverlayPill` return a result enum (`shown`, `permissionDenied`, `showFailed`).  
**When to use:** Every overlay show attempt (kiosk start, app minimize/background, event show).  
**Why:** Enables deterministic fallback UX (toast) instead of silent failures.

### Pattern 6: Lifecycle Handling Beyond Only `paused/resumed`
**What:** Handle `inactive/hidden/paused` as background candidates; apply policy once per transition with debounce/guard.  
**When to use:** `WidgetsBindingObserver.didChangeAppLifecycleState`.  
**Why:** Flutter lifecycle docs note states can be synthesized/skipped, and Android mapping is not 1:1 with activity callbacks.

## Do Not Hand-Roll

| Problem | Do Not Build | Use Instead | Why |
|--------|---------------|-------------|-----|
| Floating window platform plumbing | Custom Android overlay service | `flutter_overlay_window` existing integration | Already integrated, lower risk |
| Attendance accent mapping | Duplicate color map | `AttendanceTypeExt.color` | Single source of truth |
| Permission OEM deep-links | New native bridge | Existing `miui_perms` MethodChannel in `MainActivity.kt` | Already shipped path |
| Failure notification styling | Raw SnackBars in services | Existing `toastification` UI entrypoints | Consistent UX pattern |
| Foreground setting storage | New table/migration | SharedPreferences + app provider | Small, device-local setting |

## Common Pitfalls

### Pitfall 1: Overlay Flicker from Recreate-on-Update
**Current risk:** `showOverlayPill()` closes active overlay then re-opens it.  
**Impact:** visual flicker/full dismiss, opposite of persistent idle requirement.  
**Avoidance:** in-place `shareData` updates while active.

### Pitfall 2: Lifecycle Gaps if Planning Only for `paused/resumed`
**Current risk:** lifecycle events can be skipped/synthesized; Android mapping is not strictly 1:1 with Flutter names.  
**Impact:** overlay show/hide mismatches on split-screen, interruption, or quick transitions.  
**Avoidance:** include `inactive/hidden` policy and idempotent controller operations.

### Pitfall 3: `SYSTEM_ALERT_WINDOW` Cannot Be Granted on Android 10 Go Devices
**Fact from Android docs:** on Android 10 Go edition, overlay permission requests are denied and `canDrawOverlays` stays false.  
**Impact:** permission flow can loop forever if not handled as unsupported-case UX.  
**Avoidance:** detect persistent denial and show clear unsupported/fallback message path.

### Pitfall 4: Silent Overlay Failures
**Current risk:** `showOverlayPill` catches exceptions and only logs.  
**Impact:** user gets no signal although requirement needs warning toast on failure.  
**Avoidance:** return explicit status and surface toast from UI layer.

### Pitfall 5: Kiosk Reset Does Not Stop Background Service/Overlay
**Current risk:** logout path clears session but does not call `KioskBackgroundService.stop()`.  
**Impact:** stale notification/overlay may remain after reset.  
**Avoidance:** ensure reset flow includes stop and overlay hide before route change.

### Pitfall 6: Payload Evolution Breaks Overlay Isolate
**Current risk:** isolate parser expects `outlet|time` with 2 fields.  
**Impact:** introducing attendance state without migration can break UI updates silently.  
**Avoidance:** add backward-compatible parser and versioned schema.

### Pitfall 7: Overlay Touch Behavior
**Current risk:** wrong overlay flag can block underlying app interaction.  
**Impact:** violates acceptance criterion "does not block interactions in foreground app".  
**Avoidance:** keep non-blocking behavior verified with real-device tap-through tests.

## Code Examples

### 1. Backward-Compatible Payload Decode in Overlay Isolate
```dart
OverlayState decodeOverlayPayload(String raw) {
  // New format: JSON
  if (raw.startsWith('{')) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return OverlayState.fromMap(map);
  }

  // Legacy fallback: "outlet|HH:mm"
  final parts = raw.split('|');
  return OverlayState(
    mode: OverlayMode.idle,
    outlet: parts.isNotEmpty ? parts[0] : 'Absensi Enakko',
    time: parts.length > 1 ? parts[1] : '--:--',
  );
}
```

### 2. Idempotent Overlay Visibility Controller
```dart
Future<OverlayShowResult> ensureOverlayVisible(OverlayState state) async {
  final granted = await FlutterOverlayWindow.isPermissionGranted();
  if (!granted) return OverlayShowResult.permissionDenied;

  final isActive = await FlutterOverlayWindow.isActive();
  if (!isActive) {
    await FlutterOverlayWindow.showOverlay(
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.topCenter,
      flag: OverlayFlag.focusPointer,
      enableDrag: false,
      positionGravity: PositionGravity.none,
      startPosition: const OverlayPosition(0, 0),
    );
  }

  await FlutterOverlayWindow.shareData(jsonEncode(state.toMap()));
  return OverlayShowResult.shown;
}
```

### 3. Foreground Policy Application
```dart
void onLifecycleChanged(AppLifecycleState state) async {
  final keepInForeground = ref.read(appProvider).keepOverlayInForeground;
  final session = ref.read(appProvider).kioskSession;
  if (session == null) return;

  if (state == AppLifecycleState.inactive ||
      state == AppLifecycleState.hidden ||
      state == AppLifecycleState.paused) {
    await service.ensureOverlayVisible(service.buildIdleState(session));
    return;
  }

  if (state == AppLifecycleState.resumed && !keepInForeground) {
    await service.hideOverlayPill();
  }
}
```

## State of the Art

| Current (Codebase) | Target for Phase 3 | Impact |
|--------------------|--------------------|--------|
| Delimiter payload (`outlet|time`) | Typed JSON state payload | Supports idle/event/accent expansion |
| Overlay recreated on each show path | Persistent instance + in-place updates | Removes flicker/full-dismiss artifacts |
| Resume always hides overlay | Configurable foreground policy | Meets new setting requirement |
| Permission failures mostly silent | Guided prompt + explicit failure toast | Better reliability and user recovery |
| Overlay UI shows outlet/time only | Adds attendance type + accent + premium compact layout | Satisfies live-activity visual spec |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` + manual device validation |
| Quick command | `flutter test` |
| Static checks | `flutter analyze` |
| Hardware checks | Required (overlay behavior differs by OEM; emulator not sufficient) |

### Requirement to Test Map
| Req ID | Behavior | Test Type | Command/Method | File Exists? |
|--------|----------|-----------|----------------|--------------|
| REQ-M2-01 | Background/minimize shows persistent idle overlay | Manual integration | Real device lifecycle test runbook | No - add test checklist doc |
| REQ-M2-01 | Event state returns to idle without full dismiss | Widget/unit + manual | Overlay state-machine tests + device test | No - Wave 0 |
| REQ-M2-01 | Permission denied path shows guided flow + failure toast | Manual integration | Deny permission then trigger overlay show | No - Wave 0 |
| REQ-M2-02 | Pill style, density, accent visibility, expanded/minimized quality | Widget/golden + manual | Golden baselines + OEM visual check | No - Wave 0 |

### Suggested Device Matrix (Manual Gate)
- Xiaomi/HyperOS (MIUI-style permission stack)
- Realme/ColorOS (aggressive background restrictions)
- Samsung One UI (baseline mainstream behavior)
- One Android Go device if available (negative-case permission handling)

### Wave 0 Gaps
- [ ] Add pure Dart tests for payload parser (legacy + v1 JSON).
- [ ] Add overlay state-machine tests (idle/event timeout reversion).
- [ ] Add lifecycle policy tests for foreground toggle behavior.
- [ ] Add manual validation checklist for OEM permission and minimize/resume flows.

## Open Questions

1. **Foreground toggle default**
   - Recommendation: default `hide overlay while app active` to avoid immediate behavior change for existing kiosks.

2. **Event dwell duration**
   - Recommendation: start with 1800-2500ms event window, then revert to idle.

3. **Settings entrypoint location**
   - Recommendation: place toggle near kiosk controls (`kiosk_idle_screen`) where operators already manage kiosk behavior.

4. **Kiosk reset policy**
   - Recommendation: confirm that reset must always stop foreground service and force-hide overlay before clearing session.

## Sources

### Primary (HIGH confidence)
- Local source code:
  - `lib/overlay_task.dart` (overlay UI state, expand/collapse, payload listener)
  - `lib/services/kiosk_background_service.dart` (overlay show/hide/update paths)
  - `lib/app.dart` (lifecycle hooks)
  - `lib/screens/kiosk/kiosk_idle_screen.dart` (guided overlay permission dialog + MIUI bridge usage)
  - `lib/providers/app_provider.dart` (current persisted app state shape)
  - `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/MainActivity.kt` (MethodChannels)
  - `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/KioskNotificationHelper.kt` (result-based notification flow)
  - `android/app/src/main/AndroidManifest.xml` (overlay and service permissions)
  - `pubspec.lock` (actual resolved package versions)
- Planning context:
  - `.planning/phases/03-overlay-pill-implementation/03-CONTEXT.md`
  - `.planning/REQUIREMENTS.md`
  - `.planning/STATE.md`

### Secondary (MEDIUM confidence)
- Flutter lifecycle API docs:
  - https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html
- `flutter_overlay_window` package docs:
  - https://pub.dev/packages/flutter_overlay_window
- Android behavior change docs (`SYSTEM_ALERT_WINDOW` on Go devices):
  - https://developer.android.com/about/versions/10/behavior-changes-all
- Grab engineering reference (product direction):
  - https://engineering.grab.com/live-activity-2

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH (all dependencies and integrations exist in codebase)
- Architecture patterns: HIGH (directly derived from current file responsibilities)
- Permission/OEM pitfalls: MEDIUM (official docs + known platform constraints, but OEM behavior still varies by firmware)

**Research date:** 2026-03-01  
**Valid until:** 2026-03-31 (re-check package and OEM behavior monthly)
