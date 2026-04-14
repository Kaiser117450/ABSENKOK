# Phase 51: Admin Session Trust Hardening - Research

**Researched:** 2026-03-25
**Domain:** Supabase auth-claim hardening + Flutter admin session trust boundaries
**Confidence:** HIGH

## Summary

Phase 51 is a trust-hardening phase, not a feature phase. The current project already separates kiosk and admin entry, but three privileged paths still trust data they should not: several dashboard/analytics RPCs treat a missing `app_role` claim as acceptable because SQL null comparison semantics fail open, Flutter admin login still falls back to writable `userMetadata`, and biometric re-entry restores admin UI state from remembered role strings in `SharedPreferences` instead of from the live Supabase session.

The safest implementation path is split cleanly across SQL and Flutter:

1. Add one additive SQL migration that redefines the affected dashboard and analytics RPCs to fail closed when `app_metadata.app_role` is missing, invalid, or out of scope.
2. Add one Flutter hardening pass that centralizes admin-session claim parsing around `app_metadata` only and makes biometric re-entry derive role/outlet access from the current Supabase session after biometric success.

**Primary recommendation:** plan Phase 51 as two wave-1 plans. The SQL plan closes the server-side privilege hole for dashboard/analytics reads. The Flutter plan removes client-side trust in writable metadata and stale remembered roles while preserving valid admin and `kepala_gerai` routing.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| `SECACC-01` | Dashboard and analytics SECURITY DEFINER RPCs reject missing or invalid role claims instead of allowing authenticated users with `NULL` app roles. | The affected SQL functions in [sql/phase23_rpc_functions.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase23_rpc_functions.sql), [sql/phase24_rpc_overtime_missing.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase24_rpc_overtime_missing.sql), and [sql/phase24_arrival_patterns.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase24_arrival_patterns.sql) currently use `NOT IN` / `<>` checks that do not reject `NULL` role claims. |
| `SECACC-02` | Flutter admin session handling derives admin or kepala gerai access only from server-controlled `app_metadata`, never from writable `userMetadata`. | [admin_login_screen.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/admin/admin_login_screen.dart) and [admin_shell.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/admin/admin_shell.dart) still fall back to `userMetadata` for `app_role` and `managed_outlet_id`. |
| `SECACC-03` | Biometric admin re-entry only restores privileged UI access when the current Supabase session is still valid and still carries the expected server-issued role claim. | [admin_login_screen.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/admin/admin_login_screen.dart) currently reads remembered role/outlet values from `SharedPreferences` after biometric success and sets admin mode without re-deriving claims from the live Supabase session. |

## Standard Stack

### Core
| Library / System | Version | Purpose | Why Standard |
|---|---:|---|---|
| Supabase Postgres functions | current project SQL | Dashboard and analytics privilege boundary | Existing privileged reads already use SECURITY DEFINER RPCs. |
| Supabase Auth JWT claims | current auth payload | Server-issued role and outlet scope | Existing admin/kepala flows already depend on `app_metadata.app_role` and `managed_outlet_id`. |
| Flutter / Dart | SDK 3.3+ | Admin routing, login, biometric re-entry | The current admin shell and router already carry the state gates Phase 51 must harden. |
| `flutter_test` | SDK-bundled | Targeted regression coverage | Existing repo tests already cover login helpers and provider persistence patterns. |

### Supporting
| Library / System | Version | Purpose | When to Use |
|---|---:|---|---|
| `supabase_flutter` | `^2.8.4` | Read the current session and user claims | Keep using it, but only trust `app_metadata` for privileged mode derivation. |
| `shared_preferences` | `^2.3.3` | Persist biometric preference only | Continue to store the biometric toggle, but stop using stored role/outlet data as the privilege source of truth. |
| `go_router` | current | Admin route redirect gating | Reuse the existing redirect surface once auth-state transitions are fed from a shared claim resolver. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|---|---|---|
| Replacing affected RPCs in one additive migration | Leaving old SQL and patching only Flutter | Leaves the server-side privilege gap intact; not acceptable for `SECACC-01`. |
| A shared Flutter claim resolver | Repeating `appMetadata` reads inline in every screen | Easier to drift and reintroduce `userMetadata` fallback later. |
| Live-session claim derivation after biometric success | Remembered role/outlet in `SharedPreferences` | Faster to code, but stale or tampered local data can restore privileged UI incorrectly. |

**Installation:** no new packages are needed for Phase 51.

## Architecture Patterns

### Recommended Project Structure
```text
sql/
├── phase_51_admin_session_trust_20260325.sql      # additive role-gate hardening migration

lib/
├── core/
│   └── admin_session_claims.dart                  # shared app_metadata-only claim resolver
├── app.dart                                       # auth listener + redirect state wiring
└── screens/admin/
    ├── admin_login_screen.dart                    # login + biometric re-entry hardening
    └── admin_shell.dart                           # biometric settings hardening

test/
├── phase51/
│   ├── sql_role_guard_contract_test.dart          # migration text contract
│   └── admin_session_claims_test.dart             # app_metadata-only claim parsing
└── screens/admin/admin_login_screen_test.dart     # biometric helper regression coverage
```

### Pattern 1: Fail-Closed SQL Role Gates
**What:** Reject missing or invalid role claims explicitly instead of relying on `NOT IN` or `<>` comparisons that treat `NULL` as unknown.
**When to use:** Any SECURITY DEFINER RPC that exposes dashboard or analytics data to `authenticated` callers.
**Example:**
```sql
DECLARE
  v_role text := auth.jwt() -> 'app_metadata' ->> 'app_role';
  v_managed_outlet_id uuid :=
      NULLIF(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id', '')::uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'Authenticated session required';
  END IF;

  IF v_role IS NULL OR v_role NOT IN ('admin', 'kepala_gerai') THEN
    RAISE EXCEPTION 'Not authorized to read dashboard aggregates';
  END IF;

  IF v_role = 'kepala_gerai' AND v_managed_outlet_id IS DISTINCT FROM p_outlet_id THEN
    RAISE EXCEPTION 'Kepala gerai can only read their managed outlet';
  END IF;
END;
```

### Pattern 2: App-Metadata-Only Admin Claim Resolver
**What:** One shared Dart helper turns a Supabase user into an admin-session claim object using `appMetadata` only.
**When to use:** Login success handling, auth-state listeners, biometric re-entry, and any routing state that depends on admin vs `kepala_gerai`.
**Example:**
```dart
class AdminSessionClaims {
  const AdminSessionClaims.admin() : role = 'admin', managedOutletId = null;
  const AdminSessionClaims.kepalaGerai(this.managedOutletId)
      : role = 'kepala_gerai';

  final String role;
  final String? managedOutletId;

  static AdminSessionClaims? fromAppMetadata(Map<String, dynamic>? metadata) {
    final role = metadata?['app_role'] as String?;
    if (role == 'admin') return const AdminSessionClaims.admin();
    if (role == 'kepala_gerai') {
      final outletId = metadata?['managed_outlet_id'] as String?;
      if (outletId == null || outletId.isEmpty) return null;
      return AdminSessionClaims.kepalaGerai(outletId);
    }
    return null;
  }
}
```

### Pattern 3: Biometric Re-Entry From Live Session Claims
**What:** Biometric success unlocks privileged UI only after the current Supabase session is re-read and parsed through the shared claim resolver.
**When to use:** Cold-start biometric auto-trigger and manual biometric re-entry from the login screen.
**Example:**
```dart
final session = Supabase.instance.client.auth.currentSession;
final claims = AdminSessionClaims.fromAppMetadata(
  session?.user.appMetadata.cast<String, dynamic>(),
);

if (claims == null) {
  setState(() => _showBiometricLoading = false);
  return;
}

if (claims.role == 'admin') {
  ref.read(appProvider.notifier).setAdminMode(true);
  ref.read(appProvider.notifier).setKepalaGeraiMode(null);
} else {
  ref.read(appProvider.notifier).setAdminMode(false);
  ref.read(appProvider.notifier).setKepalaGeraiMode(claims.managedOutletId);
}
```

### Anti-Patterns to Avoid
- **`NULL NOT IN (...)` authorization checks:** in Postgres, `NULL NOT IN (...)` is not `TRUE`, so the guard silently does nothing.
- **`userMetadata` fallback for privileged role decisions:** that metadata is writable and cannot be the source of truth for admin access.
- **Remembered role strings as biometric authority:** a valid local biometric unlock does not prove the current server session still carries the same role.
- **Multiple one-off role parsers:** duplicated auth parsing logic makes it easy for one path to remain weaker than the others.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| SQL privilege checks | `IF v_role NOT IN (...)` or `v_role <> 'admin'` without null handling | `IS DISTINCT FROM` or explicit `v_role IS NULL` rejection | Null-safe comparisons close the fail-open hole. |
| Admin role derivation | Mixed `userMetadata` + `appMetadata` reads in widgets | Shared helper built on `appMetadata` only | Keeps every privileged path on the same server-issued contract. |
| Biometric restore state | Persisted role/outlet strings as the route trigger | Current-session claim derivation after biometric success | Prevents stale or tampered prefs from granting UI access. |

**Key insight:** biometric hardware can confirm the local person, but only the current Supabase session can confirm the current server-issued admin role.

## Common Pitfalls

### Pitfall 1: SQL Three-Valued Logic
**What goes wrong:** A guard like `IF v_role NOT IN ('admin', 'kepala_gerai')` does not run for `NULL`, so a caller with no `app_role` slips through.
**Why it happens:** PostgreSQL treats `NULL` comparison results as unknown, not false or true.
**How to avoid:** Use `IS DISTINCT FROM`, `COALESCE`, or an explicit `v_role IS NULL` check before the allow-list test.
**Warning signs:** SECURITY DEFINER functions that say "authenticated users only" but do not explicitly reject missing claims.

### Pitfall 2: Writable Metadata Trust
**What goes wrong:** Flutter code accepts a role from `userMetadata`, which can drift from or be weaker than the server-issued `app_metadata`.
**Why it happens:** Supabase exposes both maps on the user object and older code sometimes checks both for compatibility.
**How to avoid:** Treat `app_metadata` as the only trusted role source for privileged admin/kepala flows.
**Warning signs:** Inline code that reads `user.userMetadata['app_role']`.

### Pitfall 3: Stale Biometric Role Restore
**What goes wrong:** A remembered role in prefs can restore dashboard state even if the current session was demoted, expired, or replaced.
**Why it happens:** The biometric path validates the person locally but not the live server claims.
**How to avoid:** Keep the biometric preference, but derive access from `currentSession.user.appMetadata` after biometric success.
**Warning signs:** `SharedPreferences` values being read immediately before `setAdminMode(...)`.

### Pitfall 4: Partial Hardening Drift
**What goes wrong:** Login is hardened, but the auth listener or settings dialog keeps weaker parsing logic.
**Why it happens:** Admin session logic currently exists in multiple files.
**How to avoid:** Centralize claim parsing and use it everywhere privileged state is set.
**Warning signs:** `app_role` parsing duplicated in more than one widget after Phase 51 lands.

## Code Examples

Verified patterns from current repo structure:

### Null-safe admin-only SQL gate
```sql
IF auth.role() IS DISTINCT FROM 'authenticated' THEN
  RAISE EXCEPTION 'Authenticated session required';
END IF;

IF v_role IS DISTINCT FROM 'admin' THEN
  RAISE EXCEPTION 'Only admin can read outlet comparison';
END IF;
```

### Centralized Flutter claim application
```dart
void applyAdminClaims(AppNotifier notifier, AdminSessionClaims? claims) {
  if (claims == null) {
    notifier.setAdminMode(false);
    notifier.setKepalaGeraiMode(null);
    return;
  }

  if (claims.role == 'admin') {
    notifier.setAdminMode(true);
    notifier.setKepalaGeraiMode(null);
  } else {
    notifier.setAdminMode(false);
    notifier.setKepalaGeraiMode(claims.managedOutletId);
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Mixed `userMetadata` / `appMetadata` role reads | `appMetadata` only for privileged admin session derivation | Phase 51 target | Removes trust in writable client-side metadata. |
| Remembered role/outlet strings drive biometric restore | Live session claims drive biometric restore; prefs keep only the opt-in flag | Phase 51 target | Prevents stale local state from reviving privileged UI. |
| Null-sensitive `NOT IN` / `<>` SQL guards | Null-safe fail-closed checks (`IS DISTINCT FROM` or explicit null rejection) | Phase 51 target | Stops authenticated users with missing role claims from reading privileged analytics. |

**Already compliant and worth preserving:**
- [lib/app.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/app.dart) already reads `user.appMetadata['app_role']` in the auth-state listener.
- [sql/phase_33_central_dashboard_20260322.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase_33_central_dashboard_20260322.sql) already uses `IS DISTINCT FROM 'admin'` for central dashboard RPCs, so Phase 51 should audit it but does not need to re-open working logic unnecessarily.

## Open Questions

1. **Should legacy remembered role/outlet keys be deleted immediately or just ignored?**
   - What we know: disabling biometric already clears them, but existing devices may still have stale values stored.
   - Recommendation: keep the constants long enough to clear legacy keys during the Phase 51 rollout, but stop using them as the privilege source of truth.

2. **Does `kepala_gerai` require an explicit non-empty `managed_outlet_id` to be considered valid?**
   - What we know: current login and SQL paths assume it does.
   - Recommendation: yes. Treat missing/empty `managed_outlet_id` as an invalid privileged claim and fall back to no admin access.

3. **Should Phase 51 add central-dashboard SQL changes anyway for consistency?**
   - What we know: the Phase 33 functions already fail closed on null role claims.
   - Recommendation: no migration churn without value. Cover Phase 33 in the audit/test contract, but keep the SQL patch focused on the actually vulnerable functions.

## Validation Architecture

### Test Framework
| Property | Value |
|---|---|
| Framework | `flutter_test` |
| Config file | none - uses Flutter defaults |
| Quick run command | `C:\flutter\bin\flutter.bat test test/phase51/sql_role_guard_contract_test.dart test/phase51/admin_session_claims_test.dart test/screens/admin/admin_login_screen_test.dart test/providers/app_provider_biometric_test.dart` |
| Full suite command | `C:\flutter\bin\flutter.bat test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| `SECACC-01` | Vulnerable dashboard/analytics RPCs fail closed on missing or invalid `app_role` claims | contract / text regression | `C:\flutter\bin\flutter.bat test test/phase51/sql_role_guard_contract_test.dart` | Wave 0 (new file) |
| `SECACC-02` | Privileged Flutter session parsing ignores `userMetadata` and accepts only valid `appMetadata` claims | unit | `C:\flutter\bin\flutter.bat test test/phase51/admin_session_claims_test.dart` | Wave 0 (new file) |
| `SECACC-03` | Biometric login helper and provider cleanup do not rely on remembered role data alone | unit | `C:\flutter\bin\flutter.bat test test/screens/admin/admin_login_screen_test.dart test/providers/app_provider_biometric_test.dart` | Existing files present; new assertions needed |

### Sampling Rate
- **Per task commit:** `C:\flutter\bin\flutter.bat test test/phase51/sql_role_guard_contract_test.dart test/phase51/admin_session_claims_test.dart test/screens/admin/admin_login_screen_test.dart test/providers/app_provider_biometric_test.dart`
- **Per wave merge:** `C:\flutter\bin\flutter.bat test`
- **Phase gate:** targeted login/biometric manual pass on a real device or emulator with a valid Supabase admin session

### Wave 0 Gaps
- `sql/phase_51_admin_session_trust_20260325.sql` - additive SQL migration for the vulnerable dashboard/analytics role guards.
- `test/phase51/sql_role_guard_contract_test.dart` - regression check that the migration contains the required fail-closed patterns for every affected RPC.
- `lib/core/admin_session_claims.dart` - shared `appMetadata` claim parser so login, auth listener, and biometric flows stop drifting.
- `test/phase51/admin_session_claims_test.dart` - unit coverage for valid admin, valid `kepala_gerai`, missing outlet scope, invalid roles, and ignored `userMetadata`.

### Manual-Only Verifications
| Behavior | Requirement | Why Manual | Test Instructions |
|---|---|---|---|
| Biometric re-entry still routes valid admin and `kepala_gerai` users into the correct privileged UI after app restart | `SECACC-02`, `SECACC-03` | Requires a real Supabase session plus biometric prompt behavior | 1. Sign in as admin. 2. Enable biometric login. 3. Restart the app. 4. Approve biometric prompt. 5. Verify `/admin/dashboard` opens and the correct scope is shown. Repeat for a `kepala_gerai` account with a managed outlet. |
| A session with no valid privileged `app_metadata` claim can no longer use biometric re-entry to restore dashboard access | `SECACC-03` | Requires live auth-state mutation or a demoted test account | 1. Enable biometric on a privileged account. 2. Remove or invalidate the server-side role claim for that account. 3. Restart the app and approve biometric. 4. Verify the login form remains and privileged routing does not occur. |

## Sources

### Primary (HIGH confidence)
- [Supabase Docs - Database Functions](https://supabase.com/docs/guides/database/functions) - SECURITY DEFINER, privilege, and function-hardening guidance.
- [Supabase Docs - Custom Access Token Hook](https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook) - `app_metadata` vs `user_metadata` claim shape.
- [Supabase Docs - Row Level Security Deep Dive](https://supabase.com/docs/learn/auth-deep-dive/auth-row-level-security) - `auth.jwt()` role access patterns.
- [sql/phase23_rpc_functions.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase23_rpc_functions.sql) - vulnerable dashboard analytics functions using null-sensitive role checks.
- [sql/phase24_rpc_overtime_missing.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase24_rpc_overtime_missing.sql) - vulnerable overtime and missing-clockout role checks.
- [sql/phase24_arrival_patterns.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase24_arrival_patterns.sql) - vulnerable arrival-pattern role check.
- [sql/phase_33_central_dashboard_20260322.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase_33_central_dashboard_20260322.sql) - already-safe `IS DISTINCT FROM` central-dashboard pattern.
- [lib/app.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/app.dart) - current auth listener and redirect surface.
- [lib/screens/admin/admin_login_screen.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/admin/admin_login_screen.dart) - login and biometric trust boundary.
- [lib/screens/admin/admin_shell.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/admin/admin_shell.dart) - biometric settings flow and current role persistence.
- [lib/providers/app_provider.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/providers/app_provider.dart) - biometric preference and legacy remembered-role storage helpers.

### Secondary (MEDIUM confidence)
- [test/screens/admin/admin_login_screen_test.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/test/screens/admin/admin_login_screen_test.dart) - current biometric helper coverage.
- [test/providers/app_provider_biometric_test.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/test/providers/app_provider_biometric_test.dart) - current SharedPreferences cleanup coverage.
- [.planning/codebase/CONCERNS.md](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/.planning/codebase/CONCERNS.md) - existing note that admin role detection is fragile.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - the phase uses existing Supabase auth/RPC and Flutter routing patterns already present in the repo.
- Architecture: HIGH - the vulnerable files and the safer central-dashboard pattern are directly visible in source.
- Pitfalls: HIGH - SQL null-comparison behavior and the client-side metadata split explain the current gap clearly.

**Research date:** 2026-03-25
**Valid until:** 2026-04-08
