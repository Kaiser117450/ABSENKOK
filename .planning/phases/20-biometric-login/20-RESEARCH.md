# Phase 20: Biometric Login - Research

**Researched:** 2026-03-18
**Domain:** Flutter biometric authentication (Android-only)
**Confidence:** HIGH

## Summary

Phase 20 adds biometric fast-login for admin and kepala gerai users. The standard Flutter approach uses the official `local_auth` package (v3.0.1), which wraps Android's BiometricPrompt API. The current app authenticates via Supabase email/password with no session persistence for admin users -- after logout or app restart, users must re-type credentials. Biometric login stores a "remember me" flag and uses device-local biometrics to gate re-authentication using an existing Supabase session token.

The key architectural insight is that biometric auth does NOT replace Supabase auth. Instead: (1) user logs in with email/password normally, (2) if "Remember me" is enabled and biometrics are available, the app stores a flag indicating credentials are remembered, (3) on next app open, if the Supabase session token is still valid, the app prompts biometric verification before granting access, (4) if biometric fails/cancels, it falls back to the email/password form.

**Primary recommendation:** Use `local_auth` ^3.0.1 with SharedPreferences for the "remember me" flag. Store NO credentials locally -- rely on Supabase's persistent session token. Biometric prompt is a gatekeeper, not a credential store.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUTH-01 | Admin/kepala gerai can unlock using fingerprint or face after first login | `local_auth` authenticate() with BiometricPrompt; Supabase session persistence via `persistSession: true` (default) |
| AUTH-02 | Falls back to email/password if biometric fails, is cancelled, or unavailable | `authenticate()` returns false on cancel; catch PlatformException; router redirect to `/admin/login` |
| AUTH-03 | User can toggle "Remember me" to enable/disable biometric login | SharedPreferences bool flag `biometric_enabled_v1`; settings UI in admin shell |
| AUTH-04 | Auto-detects biometric capability, skips setup if no sensor | `canCheckBiometrics` + `getAvailableBiometrics()` check before offering toggle |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| local_auth | ^3.0.1 | Biometric prompt (fingerprint/face) | Official Flutter team plugin, wraps Android BiometricPrompt |
| shared_preferences | ^2.3.3 | Store "remember me" flag | Already in project, project decision #4 (no SecureStorage) |
| supabase_flutter | ^2.8.4 | Session persistence + auth | Already in project, handles token refresh automatically |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_riverpod | ^2.6.1 | State management for auth state | Already in project, extend AppProvider |
| go_router | ^14.8.1 | Route guards for biometric gate | Already in project, add biometric check redirect |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| local_auth | flutter_biometric_authentication | local_auth is official Flutter team, more maintained |
| SharedPreferences for flag | FlutterSecureStorage | REJECTED -- causes ANR per project decision #4 |
| Storing credentials locally | Just store flag + rely on Supabase session | Storing passwords is a security risk; Supabase handles token refresh |

**Installation:**
```bash
C:\flutter\bin\flutter.bat pub add local_auth
```

## Architecture Patterns

### Recommended Project Structure
```
lib/
  services/
    biometric_service.dart    # Wraps local_auth: check, authenticate, availability
  providers/
    app_provider.dart         # Extended: add biometricEnabled, hasBiometricHardware
  screens/
    admin/
      admin_login_screen.dart # Modified: biometric prompt before showing form
      admin_shell.dart        # Modified: settings toggle for "Remember me"
  core/
    constants.dart            # Add biometric SharedPreferences keys
```

### Pattern 1: Biometric Service (Singleton Wrapper)
**What:** A service class that wraps `local_auth` calls with error handling
**When to use:** Every biometric operation
**Example:**
```dart
// Source: pub.dev/packages/local_auth (official example)
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  /// Check if device has biometric hardware AND enrolled biometrics
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Prompt biometric auth. Returns true if authenticated.
  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Verifikasi identitas untuk masuk',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN fallback on device
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
```

### Pattern 2: Biometric Gate in Login Flow
**What:** On app resume/start, check if biometric is enabled, prompt before showing dashboard
**When to use:** When admin has "Remember me" enabled and Supabase session exists
**Example:**
```dart
// In app.dart router redirect logic:
// 1. Check if Supabase session exists (user previously logged in)
// 2. Check if biometric_enabled flag is true in SharedPreferences
// 3. If both true: show biometric prompt
//    - Success: set admin/kepalaGerai mode, redirect to dashboard
//    - Fail/cancel: redirect to /admin/login (email/password form)
// 4. If flag false or no session: normal login flow
```

### Pattern 3: Remember Me Toggle in Settings
**What:** Switch in admin shell (drawer/dialog) to enable/disable biometric
**When to use:** User wants to control biometric behavior
**Example:**
```dart
// On toggle ON:
// 1. Check BiometricService.isAvailable()
// 2. If available: prompt authenticate() once to confirm
// 3. If confirmed: save flag to SharedPreferences
// On toggle OFF:
// 1. Clear flag from SharedPreferences
// 2. Next login will require email/password
```

### Anti-Patterns to Avoid
- **Storing email/password locally:** Never store credentials. Supabase session token handles re-auth. The biometric prompt is a gatekeeper to the existing session, not a credential vault.
- **Using FlutterSecureStorage:** Per project decision #4, this causes ANR. Use SharedPreferences for the boolean flag only.
- **Blocking app startup with biometric:** The biometric check must have a timeout/cancel path. Never block the loading flow -- use the existing 5s safety net pattern.
- **Skipping the initial email/password login:** Biometric is only available AFTER a successful first login. Never offer biometric to a user who has never logged in on this device.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Biometric prompt UI | Custom fingerprint dialog | `local_auth` authenticate() | OS provides native BiometricPrompt with proper security |
| Biometric hardware detection | Manual feature checks | `canCheckBiometrics` + `getAvailableBiometrics()` | Handles all Android versions and sensor types |
| Session token management | Custom token storage | Supabase's built-in `persistSession` | Handles refresh tokens, expiry, secure storage internally |
| Biometric cancellation handling | Manual state tracking | `authenticate()` return value + PlatformException | Library handles all edge cases (cancel, lockout, too many attempts) |

**Key insight:** The biometric prompt is purely a local gatekeeper. All actual authentication is handled by Supabase's existing session system. This keeps the implementation simple and secure.

## Common Pitfalls

### Pitfall 1: FlutterActivity vs FlutterFragmentActivity
**What goes wrong:** `local_auth` requires `FlutterFragmentActivity` on Android. The current `MainActivity.kt` extends `FlutterActivity`.
**Why it happens:** BiometricPrompt requires FragmentActivity for the dialog lifecycle.
**How to avoid:** Change `MainActivity.kt` to extend `FlutterFragmentActivity` instead of `FlutterActivity`. Import `io.flutter.embedding.android.FlutterFragmentActivity`.
**Warning signs:** Crash on biometric prompt with "FragmentActivity required" or similar error.

### Pitfall 2: Theme Compatibility
**What goes wrong:** BiometricPrompt dialog may crash if the activity theme does not extend AppCompat.
**Why it happens:** The current `LaunchTheme` parent is `@android:style/Theme.Light.NoTitleBar`, not AppCompat.
**How to avoid:** Change theme parent to `Theme.AppCompat.Light.NoActionBar` in `styles.xml`. Both `LaunchTheme` and `NormalTheme` need updating.
**Warning signs:** Runtime crash when biometric prompt is shown, theme-related exception.

### Pitfall 3: No Enrolled Biometrics
**What goes wrong:** Device has sensor but user has not enrolled any fingerprints/faces.
**Why it happens:** `canCheckBiometrics` returns true (hardware exists) but `getAvailableBiometrics()` returns empty list.
**How to avoid:** Always check BOTH `canCheckBiometrics` AND `getAvailableBiometrics().isNotEmpty` before offering biometric option.
**Warning signs:** "Remember me" toggle visible but biometric prompt fails silently.

### Pitfall 4: Supabase Session Expiry
**What goes wrong:** User enables "Remember me", but Supabase refresh token has expired (after long inactivity).
**Why it happens:** Supabase tokens expire. If the refresh fails, there is no valid session to gate.
**How to avoid:** Before biometric prompt, check `Supabase.instance.client.auth.currentSession != null`. If null, skip biometric and show login form. Also check `supabaseReady` global flag.
**Warning signs:** Biometric succeeds but API calls fail with 401.

### Pitfall 5: ANR from Biometric on Main Thread
**What goes wrong:** Biometric prompt blocks the UI thread if not handled properly.
**Why it happens:** `authenticate()` is async but the native dialog is shown synchronously on Android.
**How to avoid:** Call `authenticate()` with `stickyAuth: true` so the prompt persists through app lifecycle changes. Add a reasonable timeout wrapper (10s) to prevent indefinite blocking.
**Warning signs:** App becomes unresponsive during biometric prompt.

### Pitfall 6: USE_BIOMETRIC Permission Missing
**What goes wrong:** Biometric prompt fails silently or throws PlatformException.
**Why it happens:** `android.permission.USE_BIOMETRIC` is not in AndroidManifest.xml.
**How to avoid:** Add `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>` to AndroidManifest.xml.
**Warning signs:** `canCheckBiometrics` returns false on devices that have biometric hardware.

## Code Examples

### BiometricService Complete Implementation
```dart
// Source: pub.dev/packages/local_auth + pub.dev/packages/local_auth_android
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  /// Returns true if device has biometric hardware AND user has enrolled biometrics.
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Returns list of available biometric types (for UI display).
  static Future<List<BiometricType>> getAvailableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Prompts biometric authentication. Returns true on success.
  /// Returns false on cancel, failure, or error.
  static Future<bool> authenticate({
    String reason = 'Verifikasi identitas untuk masuk',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,       // Keep prompt through lifecycle changes
          biometricOnly: false,   // Allow device PIN as fallback
        ),
      );
    } on PlatformException catch (e) {
      // PlatformException codes: NotAvailable, NotEnrolled, LockedOut,
      // PermanentlyLockedOut, OtherOperatingSystem
      debugPrint('[BiometricService] authenticate error: ${e.code} ${e.message}');
      return false;
    }
  }
}
```

### SharedPreferences Keys (constants.dart additions)
```dart
// Add to AppConstants class:
static const String biometricEnabledKey = 'biometric_enabled_v1';
static const String rememberedUserEmailKey = 'remembered_user_email_v1';
static const String rememberedUserRoleKey = 'remembered_user_role_v1';
static const String rememberedManagedOutletKey = 'remembered_managed_outlet_v1';
```

### AppProvider Extensions
```dart
// Add to AppState:
final bool biometricEnabled;    // from SharedPreferences
final bool hasBiometricHardware; // from BiometricService.isAvailable()

// Add to AppNotifier:
Future<void> loadBiometricPreference() async {
  final prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getBool(AppConstants.biometricEnabledKey) ?? false;
  final hasHardware = await BiometricService.isAvailable();
  state = state.copyWith(
    biometricEnabled: enabled,
    hasBiometricHardware: hasHardware,
  );
}

Future<void> setBiometricEnabled(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(AppConstants.biometricEnabledKey, value);
  state = state.copyWith(biometricEnabled: value);
}
```

### MainActivity.kt Change (Critical)
```kotlin
// BEFORE:
import io.flutter.embedding.android.FlutterActivity
class MainActivity : FlutterActivity() {

// AFTER:
import io.flutter.embedding.android.FlutterFragmentActivity
class MainActivity : FlutterFragmentActivity() {
```

### styles.xml Theme Change (Critical)
```xml
<!-- BEFORE: -->
<style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
<style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">

<!-- AFTER: -->
<style name="LaunchTheme" parent="Theme.AppCompat.Light.NoActionBar">
<style name="NormalTheme" parent="Theme.AppCompat.Light.NoActionBar">
```

### Biometric Login Flow (router integration)
```dart
// In app.dart, during loadSession():
// After loading kiosk session, also load biometric preference.
// Then in redirect logic:
//
// Case: Supabase has valid session + biometric enabled + no admin mode set yet
//   → Navigate to a biometric gate screen or inline prompt
//   → On success: read stored role from SharedPreferences, set admin/kepalaGerai mode
//   → On fail/cancel: clear biometric flag optionally, show /admin/login
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `fingerprintAuth` plugin | `local_auth` with BiometricPrompt | 2020+ | Unified API, supports face + fingerprint |
| Storing passwords for re-login | Session token + biometric gate | Current best practice | No credentials stored locally |
| `FlutterSecureStorage` for secrets | SharedPreferences for flags only | Project decision #4 | Eliminates ANR risk |
| `biometricOnly: true` | `biometricOnly: false` | Best practice | Allows device PIN fallback for accessibility |

**Deprecated/outdated:**
- `FingerprintAuthentication` API: replaced by BiometricPrompt (Android 9+)
- `canCheckBiometrics` alone: must also check `getAvailableBiometrics()` for enrolled biometrics

## Open Questions

1. **What to store when "Remember me" is toggled on?**
   - What we know: We need the user's role (admin/kepala_gerai) and managed_outlet_id to restore state without re-querying Supabase
   - What's unclear: Whether Supabase session auto-restores role metadata on app restart
   - Recommendation: Store role + managed_outlet_id in SharedPreferences alongside the biometric flag. On biometric success, read these to set AppProvider state. Verify by checking `Supabase.instance.client.auth.currentUser` metadata.

2. **Should biometric prompt appear on every app open or only after session expiry?**
   - What we know: Requirements say "re-authenticate quickly" suggesting every app open
   - What's unclear: Whether prompting on every resume (background->foreground) is desired
   - Recommendation: Prompt only on cold start (app killed and reopened), not on resume from background. This matches the "unlock" metaphor without being annoying.

3. **Where to place the "Remember me" toggle in UI?**
   - What we know: Currently there is no settings screen. Admin shell has only a logout button.
   - What's unclear: Whether to add a settings screen or put toggle on login screen
   - Recommendation: Add a "Remember me" checkbox on the login screen (most intuitive). Additionally, add a gear icon in admin shell appbar that opens a simple settings dialog with the toggle.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | none (uses default pubspec.yaml) |
| Quick run command | `C:\flutter\bin\flutter.bat test test/services/biometric_service_test.dart` |
| Full suite command | `C:\flutter\bin\flutter.bat test` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTH-01 | Biometric unlock after first login | unit (mock local_auth) | `C:\flutter\bin\flutter.bat test test/services/biometric_service_test.dart -x` | No - Wave 0 |
| AUTH-02 | Fallback to email/password on failure | unit (mock authenticate returning false) | `C:\flutter\bin\flutter.bat test test/services/biometric_service_test.dart -x` | No - Wave 0 |
| AUTH-03 | Remember me toggle persists preference | unit (mock SharedPreferences) | `C:\flutter\bin\flutter.bat test test/providers/app_provider_biometric_test.dart -x` | No - Wave 0 |
| AUTH-04 | Skip biometric if no sensor | unit (mock canCheckBiometrics=false) | `C:\flutter\bin\flutter.bat test test/services/biometric_service_test.dart -x` | No - Wave 0 |

### Sampling Rate
- **Per task commit:** `C:\flutter\bin\flutter.bat test test/services/biometric_service_test.dart`
- **Per wave merge:** `C:\flutter\bin\flutter.bat test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/services/biometric_service_test.dart` -- covers AUTH-01, AUTH-02, AUTH-04
- [ ] `test/providers/app_provider_biometric_test.dart` -- covers AUTH-03

## Sources

### Primary (HIGH confidence)
- [pub.dev/packages/local_auth](https://pub.dev/packages/local_auth) - API, version 3.0.1, usage patterns
- [pub.dev/packages/local_auth_android](https://pub.dev/packages/local_auth_android) - Android-specific setup (FlutterFragmentActivity, USE_BIOMETRIC permission, theme requirements)
- [pub.dev/packages/local_auth/example](https://pub.dev/packages/local_auth/example) - Official example code

### Secondary (MEDIUM confidence)
- [Flutter biometric auth guide (Medium, Jan 2026)](https://medium.com/@ravipatel84184/i-added-biometric-authentication-to-flutter-heres-the-complete-guide-6c119d62f34a) - Implementation patterns verified against official docs
- [Mobisoft biometric guide](https://mobisoftinfotech.com/resources/blog/flutter-development/secure-flutter-biometric-authentication-fingerprint-face-id) - Architecture pattern (gate vs credential store)

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - `local_auth` is the official Flutter team plugin, v3.0.1 verified on pub.dev
- Architecture: HIGH - Biometric-as-gatekeeper pattern is well-established, matches project constraints (no SecureStorage)
- Pitfalls: HIGH - FlutterFragmentActivity and theme requirements are documented in official Android setup, verified against current codebase

**Codebase-specific findings:**
- `MainActivity.kt` currently extends `FlutterActivity` -- MUST change to `FlutterFragmentActivity`
- `styles.xml` uses `@android:style/Theme.Light.NoTitleBar` -- MUST change to AppCompat theme
- `AndroidManifest.xml` missing `USE_BIOMETRIC` permission -- MUST add
- `minSdk = 24` is compatible (BiometricPrompt requires API 28+ but local_auth handles fallback)
- `SharedPreferences` is already used for session persistence -- extend for biometric flag
- No settings screen exists -- need to add toggle location
- Kotlin 1.9.25 constraint is compatible with local_auth

**Research date:** 2026-03-18
**Valid until:** 2026-04-18 (stable domain, local_auth changes slowly)
