# Phase 12 Research: Fix Kiosk Logout Not Working After App Restart

## Bug Description

**User report (Indonesian):** Tombol log out gerai tidak berfungsi setelah tutup aplikasi -- harus hapus data aplikasi dulu baru bisa log out. Login pertama masih bisa keluar (logout) lagi, namun setelah tutup dan buka lagi aplikasi malah tidak bisa log out.

**Translation:** The outlet logout button doesn't work after closing and reopening the app. On first login, logout works fine. But after closing the app and reopening it, the logout button no longer works. The user has to clear the app data to be able to log out.

**Key observation:** Logout works on first login, breaks only after app restart (cold start with persisted session).

---

## Full Logout Flow Trace

### 1. Logout Button Location
- **File:** `lib/screens/kiosk/kiosk_idle_screen.dart` line 792
- **Widget:** `GestureDetector` wrapping a circular red icon button in the header
- **Handler:** `onTap: _confirmLogoutGerai` (line 515)
- The button is **always visible** in the header -- no conditional rendering guards

### 2. `_confirmLogoutGerai()` Method (line 515-569)
```dart
void _confirmLogoutGerai() {
  showDialog<void>(
    context: context,        // <-- uses the SCREEN's context
    builder: (ctx) => AlertDialog(
      // ... dialog UI ...
      onPressed: () async {
        Navigator.pop(ctx);                                   // close dialog
        await KioskBackgroundService.stop();                  // stop services
        await ref.read(appProvider.notifier).clearKioskSession(); // clear SharedPrefs + state
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) context.go('/setup');                    // navigate to setup
      },
    ),
  );
}
```

### 3. `clearKioskSession()` in AppNotifier (line 119-123)
```dart
Future<void> clearKioskSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(AppConstants.kioskSessionKey);  // key = 'kiosk_session_v1'
  state = state.copyWith(clearKiosk: true);          // sets kioskSession = null
}
```

### 4. GoRouter Redirect (app.dart line 45-83)
After `clearKioskSession()`, `_AppStateListenable` fires `notifyListeners()`, and GoRouter re-evaluates:
- `hasKiosk` becomes `false`, `isAdmin` is `false`, `isKepalaGerai` is `false`
- Falls into the `else` branch (line 77-79): redirects everything to `/setup`

### 5. Session Restore on App Restart (app.dart line 147-148 + app_provider.dart line 86-111)
```dart
// app.dart initState:
ref.read(appProvider.notifier).loadSession();

// app_provider.dart loadSession():
Future<void> loadSession() async {
  state = state.copyWith(isLoading: true);
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.kioskSessionKey);
    if (raw != null) {
      final session = KioskSession.fromJsonString(raw);
      state = state.copyWith(kioskSession: session);  // restores kiosk mode
    }
  } finally {
    state = state.copyWith(isLoading: false);
  }
}
```

---

## Root Cause Analysis

### Primary Hypothesis: `context.go('/setup')` Failing After GoRouter Auto-Redirect

The sequence on app restart is:
1. App starts -> `loadSession()` -> `kioskSession` restored from SharedPreferences
2. GoRouter redirects from `/setup` to `/kiosk` (because `hasKiosk == true`)
3. `KioskIdleScreen` is built and displayed
4. User taps logout button -> `_confirmLogoutGerai()` is called
5. Dialog appears, user taps "Reset"
6. **The `onPressed` async handler runs:**
   - `Navigator.pop(ctx)` -- dismisses dialog
   - `KioskBackgroundService.stop()` -- stops foreground service
   - `clearKioskSession()` -- clears SharedPrefs AND sets state to `clearKiosk: true`
   - **At this point, GoRouter `refreshListenable` fires because state changed**
   - **GoRouter re-evaluates: `hasKiosk` is now `false` -> redirect to `/setup`**
   - **GoRouter navigates away from `/kiosk` to `/setup`**
   - **The `KioskIdleScreen` widget gets disposed -> `mounted` becomes `false`**
   - `await Future.delayed(100ms)` -- still waiting
   - `if (mounted) context.go('/setup')` -- **`mounted` is `false`, so this is SKIPPED**

Wait -- this actually seems like it should work. The GoRouter redirect should handle the navigation. The `context.go('/setup')` at line 561 is a redundant safety net.

### Deeper Hypothesis: The REAL problem is the dialog `Navigator.pop(ctx)` race condition

Let me reconsider. After `Navigator.pop(ctx)` dismisses the dialog:
- The dialog's overlay entry is removed
- The `onPressed` handler continues as an async function
- `clearKioskSession()` updates state -> GoRouter fires redirect
- GoRouter sees `hasKiosk == false`, loc is `/kiosk` -> redirects to `/setup`

**But wait -- there's a subtle GoRouter + Navigator conflict.** The dialog was pushed via `Navigator.pop()` (imperative navigation). Meanwhile GoRouter's redirect replaces the route. If GoRouter's redirect fires *while* the dialog pop animation is still in progress, the GoRouter navigation could fail silently or get absorbed.

### Most Likely Root Cause: `KioskBackgroundService.stop()` Throws on Restart

On first login:
- `KioskBackgroundService.start()` is called in `_startBackgroundService()` (line 64-75)
- This sets `_session`, starts foreground task, etc.
- Later, `stop()` works because the service is properly initialized

On **app restart**:
- `loadSession()` restores `kioskSession` from SharedPreferences
- GoRouter redirects to `/kiosk`
- `KioskIdleScreen.initState()` calls `_startBackgroundService()` which calls `KioskBackgroundService.start(session)`
- **But if `start()` fails silently** (e.g., overlay permission dialog blocks, or foreground service fails), `stop()` might throw

Actually looking at the code more carefully, `stop()` has no try-catch protection for `FlutterForegroundTask.stopService()`. But all the methods inside have their own error handling.

### Most Likely Root Cause: `_confirmLogoutGerai` Captures a Stale `ref`

**CRITICAL FINDING:** The `_confirmLogoutGerai()` method is called from within the widget. But after app restart, the GoRouter may have reconstructed the widget tree in a way where:

1. GoRouter redirect creates a **new** `KioskIdleScreen` instance (not the same one)
2. The `ref` from the **dialog's onPressed closure** may reference the old widget's Riverpod ref

Actually, since `_confirmLogoutGerai` is a method on `_KioskIdleScreenState`, and the dialog captures `ref` from that state, this should be fine as long as the widget is still mounted.

### ACTUAL Most Likely Root Cause: `GestureDetector` is Not Receiving Taps

Let me reconsider the user report: "tombol log out gerai **tidak berfungsi**" -- the button doesn't FUNCTION. This could mean:

1. **The button doesn't respond to taps at all** (no dialog appears)
2. **The dialog appears but the Reset button doesn't work**
3. **The Reset works but the navigation to /setup fails**

Given the user says "harus hapus data aplikasi dulu baru bisa log out" -- clearing app data removes the SharedPrefs, which removes the kiosk session, effectively doing the logout. This confirms the issue is in the runtime logout flow, not data persistence.

### Critical Path: NFC Listener and GestureDetector Conflict

On `initState()`, the screen calls `_checkNfcThenListen()` which starts NFC discovery. When NFC is active, it sets `_kioskState = _KioskState.detecting` on tag discovery. But looking at the code:

```dart
Future<void> _onNfcTag(String uid) async {
  if (_kioskState != _KioskState.idle) return;  // debounce
```

The NFC listener runs continuously. However, this shouldn't block gesture recognition.

### Most Compelling Root Cause: `Navigator.pop(ctx)` After GoRouter Redirect Race

Here's the **most compelling theory** for the bug:

After app restart, when the user taps "Reset" in the dialog:

1. `Navigator.pop(ctx)` -- pops the dialog
2. `KioskBackgroundService.stop()` -- async, may take time
3. `clearKioskSession()` -- clears state, triggers GoRouter refresh
4. **GoRouter redirect fires: navigates from `/kiosk` to `/setup`**
5. **`KioskIdleScreen` is disposed** -- `mounted = false`
6. The async handler continues: `await Future.delayed(100ms)`
7. `if (mounted) context.go('/setup')` -- skipped because not mounted

This should work because GoRouter handles the navigation in step 4. **But what if GoRouter's redirect fails because the dialog's Navigator pop hasn't fully completed?**

Actually, I think the real issue may be **even simpler**. Let me re-read the redirect logic:

```dart
} else if (hasKiosk) {
  if (!loc.startsWith('/kiosk')) return '/kiosk';
}
```

After `clearKioskSession()`, `hasKiosk = false`. The redirect should send to `/setup`. This is correct.

### **MOST LIKELY ROOT CAUSE: The `mounted` Check Fails Because GoRouter Already Navigated Away**

Actually, here's a revised theory. The flow on first login:
1. User navigates to `/kiosk` via GoRouter (from setup screen after successful activation)
2. `KioskIdleScreen` widget is created and mounted
3. User taps logout -> dialog -> Reset -> `clearKioskSession()` -> state change -> GoRouter redirect to `/setup` -> **works**

The flow on app restart:
1. App starts at `/setup` (initialLocation)
2. `loadSession()` runs -> restores kioskSession -> state changes
3. GoRouter `refreshListenable` fires -> redirect evaluates -> `hasKiosk == true` -> redirect to `/kiosk`
4. `KioskIdleScreen` widget is created and mounted
5. User taps logout -> `_confirmLogoutGerai()` called
6. **But does the dialog actually show?**

Wait -- I need to consider: **is the logout button visible but not tappable?** Could there be an overlay or absorbing pointer sitting on top?

Looking at the build method (line 641-693), the layout uses a `Stack`:
- Layer 0: `_AmbientGlowPainter` (Positioned.fill CustomPaint)
- Layer 1: `FadeTransition` containing the main UI (SafeArea > Column)

The `CustomPaint` in Layer 0 is `Positioned.fill` but `CustomPaint` doesn't absorb gestures by default unless it has a `hitTest` override. So this shouldn't block taps.

**However**, there's an `AbsorbPointer` or similar widget possibility. Let me check if there's anything else in the Stack...

The Stack only has 2 children. Both are clean. The header buttons are in the Column inside Layer 1. They should be tappable.

### **REVISED MOST LIKELY ROOT CAUSE: `showDialog` Fails Because GoRouter Just Completed Navigation**

After extensive analysis, here's my best theory:

When the app restarts and GoRouter redirects from `/setup` to `/kiosk`, the KioskIdleScreen is built. But there could be a **timing issue where GoRouter's redirect is still "in flight" when the user taps the logout button.**

However, this is unlikely because the user would have to interact with the screen for a while before tapping logout.

### **ALTERNATIVE HYPOTHESIS: The Button Works But `clearKioskSession` Doesn't Navigate**

After `clearKioskSession()`:
- `state = state.copyWith(clearKiosk: true)` sets `kioskSession = null`
- `_AppStateListenable` calls `notifyListeners()`
- GoRouter re-evaluates redirect
- Current location is `/kiosk`
- `hasKiosk = false`, `isAdmin = false` -> falls to `else` branch -> redirects to `/setup`

**But wait -- what if `_AppStateListenable` doesn't fire?**

Looking at the code:
```dart
class _AppStateListenable extends ChangeNotifier {
  _AppStateListenable(this._ref) {
    _ref.listen<AppState>(appProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
```

`_ref.listen` should fire whenever `appProvider` state changes. And `clearKioskSession()` does change state. So this should work.

**Unless... the `Ref` becomes invalid.** If the `Provider<GoRouter>` is somehow recreated or the ref is stale, the listener might not fire. But `routerProvider` is a `Provider` (not `.autoDispose`), so it should persist.

### **FINAL MOST LIKELY ROOT CAUSE: `context.go('/setup')` Uses Wrong Context After Dialog Pop**

Here's the smoking gun:

```dart
onPressed: () async {
  Navigator.pop(ctx);                    // Pop dialog using dialog context
  await KioskBackgroundService.stop();
  await ref.read(appProvider.notifier).clearKioskSession();
  await Future.delayed(const Duration(milliseconds: 100));
  if (mounted) context.go('/setup');     // Navigate using SCREEN context
},
```

After `Navigator.pop(ctx)`:
- The dialog is removed from the widget tree
- The `KioskIdleScreen` is still mounted (it's the parent)
- `clearKioskSession()` updates state
- GoRouter redirect fires -> navigates to `/setup`
- KioskIdleScreen gets **unmounted** because the route changes
- `mounted` becomes `false` -> `context.go('/setup')` is skipped

**This means GoRouter's redirect is the actual navigation mechanism.** The explicit `context.go('/setup')` at line 561 is redundant.

So the question becomes: **Why does GoRouter's redirect NOT work after app restart?**

### **THE ACTUAL BUG: GoRouter Redirect Creates Infinite Loop or Fails Silently**

After deep analysis, I believe the most probable cause is a **race condition between `Navigator.pop()` and GoRouter's redirect**:

1. `Navigator.pop(ctx)` pops the dialog
2. During the pop animation, `clearKioskSession()` fires
3. GoRouter's `refreshListenable` fires `notifyListeners()`
4. GoRouter tries to evaluate redirect while the Navigator's pop is still being processed
5. **GoRouter's `state.uri.path` may still reflect an intermediate state** (e.g., the dialog route)
6. The redirect evaluation may produce `null` (no redirect needed) because the path doesn't match expected patterns

Actually, `showDialog` uses an overlay, not a GoRouter route. So `state.uri.path` should still be `/kiosk`. This theory doesn't hold.

### **REVISED: The Real Bug is Likely in the KioskBackgroundService.stop() Hanging**

If `KioskBackgroundService.stop()` hangs or takes a very long time:
- `FlutterForegroundTask.stopService()` could block
- `FlutterOverlayWindow.closeOverlay()` could block
- `_notifPlugin.cancel()` could fail

If `stop()` never completes, `clearKioskSession()` never runs, and the navigation never happens.

**On first login:** The background service may not have fully started yet (race with NFC init), so `stop()` completes quickly.
**After restart:** The background service is fully running (started in `_startBackgroundService()`), and `stop()` may hang on `FlutterForegroundTask.stopService()`.

This would explain the behavior perfectly.

---

## Summary of Hypotheses (Ranked by Likelihood)

### Hypothesis 1: `KioskBackgroundService.stop()` Hangs or Throws (HIGH)
- `stop()` calls `FlutterForegroundTask.stopService()`, `_notifPlugin.cancel()`, `dismissLiveNotification()`, and `hideOverlayPill()` sequentially
- If any of these hangs, `clearKioskSession()` never executes
- No try-catch around the entire logout async chain -- an exception in `stop()` would abort the remaining steps
- **After restart, services are fully initialized, making hang/error more likely**

### Hypothesis 2: `context.go('/setup')` Uses Unmounted Context (MEDIUM)
- After `clearKioskSession()`, GoRouter redirect fires and navigates away
- KioskIdleScreen gets disposed, `mounted = false`
- `context.go('/setup')` is skipped
- But GoRouter's own redirect should handle this -- **unless the redirect fails**

### Hypothesis 3: GoRouter Redirect Race with Dialog Pop (MEDIUM-LOW)
- `Navigator.pop()` and GoRouter redirect competing for Navigator control
- Could cause silent navigation failure

### Hypothesis 4: SharedPreferences.remove() Fails Silently (LOW)
- `prefs.remove(AppConstants.kioskSessionKey)` might not actually remove the key
- On next `loadSession()`, the old session would be restored
- Very unlikely but worth verifying

---

## Files That Need Changes

| File | What to Investigate/Fix |
|------|------------------------|
| `lib/screens/kiosk/kiosk_idle_screen.dart` | `_confirmLogoutGerai()` -- add try-catch, add debug logging to every step |
| `lib/providers/app_provider.dart` | `clearKioskSession()` -- add logging, verify SharedPreferences.remove() success |
| `lib/services/kiosk_background_service.dart` | `stop()` -- add try-catch around each step, add timeout guards |
| `lib/app.dart` | GoRouter redirect -- add logging for redirect decisions |

---

## Recommended Fix Strategy

### 1. Wrap the Entire Logout Chain in Try-Catch with Individual Step Protection
```dart
onPressed: () async {
  Navigator.pop(ctx);
  try {
    await KioskBackgroundService.stop().timeout(Duration(seconds: 3));
  } catch (e) {
    debugPrint('[Logout] stop() failed: $e');
  }
  await ref.read(appProvider.notifier).clearKioskSession();
  if (mounted) context.go('/setup');
},
```

### 2. Make `KioskBackgroundService.stop()` Resilient
Each step in `stop()` should be individually wrapped in try-catch so one failure doesn't block the rest:
```dart
static Future<void> stop() async {
  _rotateTimer?.cancel();
  _rotateTimer = null;
  _session = null;
  try { await FlutterForegroundTask.stopService(); } catch (e) { ... }
  try { await _notifPlugin.cancel(_kNotifIdPersistent); } catch (e) { ... }
  try { await dismissLiveNotification(); } catch (e) { ... }
  try { await hideOverlayPill(); } catch (e) { ... }
}
```

### 3. Add Timeout to `stop()` Call in Logout Handler
Ensure the logout flow can't be blocked indefinitely by a service that won't stop.

### 4. Don't Rely Solely on GoRouter Redirect for Navigation
After `clearKioskSession()`, explicitly call `context.go('/setup')` as a belt-and-suspenders approach, but also verify the GoRouter redirect works independently.

### 5. Add Debug Logging
Add `debugPrint` statements at every step of the logout flow to diagnose the exact failure point.

---

## Testing Plan

1. **First login logout:** Activate device -> tap logout -> verify navigates to setup (BASELINE)
2. **Restart logout:** Activate device -> close app -> reopen -> tap logout -> verify navigates to setup (THE BUG)
3. **Restart with services:** Activate -> close -> reopen -> wait for NFC + foreground service to fully start -> tap logout
4. **Restart without NFC:** Disable NFC -> close -> reopen -> tap logout (isolates NFC from the issue)
5. **Verify SharedPreferences:** After successful logout, verify `kiosk_session_v1` key is actually removed
6. **Verify state:** After `clearKioskSession()`, log `appProvider` state to confirm `kioskSession == null`

---

## Key Constraints (from CLAUDE.md)
- SharedPreferences for session persistence (NOT FlutterSecureStorage)
- Kotlin 1.9.25 -- `catch (e: Exception)` not `catch (_: Exception)`
- `loadSession()` must always set `isLoading: false` in `finally` block
- GoRouter `/admin/login` must ALWAYS be accessible before kiosk check
