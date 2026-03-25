# Phase 50: Kiosk Device Boundary Hardening - Research

**Researched:** 2026-03-25
**Domain:** Supabase Postgres security hardening + Flutter device identity/UI safety
**Confidence:** HIGH

## Summary

This phase is a boundary-hardening pass, not a feature build. The repo already has the device identity and kiosk-device dashboard plumbing in place, but the current implementation still leaves three sharp edges: the heartbeat RPC can rebind `outlet_id` on conflict, the nickname/archive RPCs are callable without explicit caller checks, and the device label fallback can crash on malformed UUIDs.

The safest implementation path is SQL-first. Keep the authorization boundary in Postgres, using `SECURITY DEFINER` with explicit `search_path`, explicit `REVOKE`/`GRANT`, and JWT claim checks from `app_metadata`. The Flutter side should mostly consume safer data and render it defensively, not try to enforce security rules that the client can bypass.

**Primary recommendation:** split Phase 50 into a database-hardening plan and a Flutter safety/test plan. The SQL work should lock the device binding and RPC privileges; the Dart work should make kiosk labels impossible to crash.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| `SECDEV-01` | A kiosk device can only send heartbeat updates after successful outlet activation, and the heartbeat path cannot silently rebind that device to a different outlet. | Hardening `upsert_kiosk_heartbeat` to stop changing `outlet_id` on conflict, while keeping the existing persistent installation UUID flow in [heartbeat_service.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/services/heartbeat_service.dart) and [setup_screen.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/setup/setup_screen.dart). |
| `SECDEV-02` | Device rename and archive RPCs only execute for authenticated admin or kepala gerai callers whose outlet scope matches the target kiosk. | Add caller checks to `set_device_nickname` and `archive_device`, using the repo's JWT claim pattern from Phase 33 and the Supabase `app_metadata` pattern. |
| `SECSAFE-01` | Admin and kiosk device surfaces handle malformed or short kiosk UUID data without crashing the client. | Replace raw `substring(0, 8)` formatting in [kiosk_device.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/models/kiosk_device.dart) with a bounds-safe formatter and test it. |

## Standard Stack

### Core
| Library / System | Version | Purpose | Why Standard |
|---|---:|---|---|
| Supabase Postgres functions | current project SQL | Kiosk heartbeat, device rename/archive, and admin RPC authorization | The repo already uses SECURITY DEFINER RPCs for privileged flows. |
| Supabase Auth JWT claims | current project auth | Role and managed-outlet checks via `app_metadata` | Existing SQL already uses JWT-backed role checks, and Supabase docs recommend claim-based access control. |
| Flutter / Dart | SDK 3.3+ | Device label rendering and local safety checks | Keeps the UI boundary simple and testable. |
| `flutter_test` | SDK-bundled | Model and widget verification | Existing repo test structure already uses it. |

### Supporting
| Library / System | Version | Purpose | When to Use |
|---|---:|---|---|
| `supabase_flutter` | `^2.8.4` | Client calls from the dashboard and setup flow | Keep it for normal client calls, but do not move auth logic into the client. |
| `shared_preferences` | `^2.3.3` | Persistent installation UUID | Existing device identity flow already depends on it. |
| `uuid` | `^4.5.1` | UUIDv4 generation | Already present and used by `DeviceIdentityService`. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|---|---|---|
| SQL role checks | Flutter-side checks | Easier to bypass from the client and weaker for security boundaries. |
| Raw `substring(0, 8)` labels | Safe helper with length checks | Slightly more code, but no crash on malformed data. |
| Implicit function permissions | Explicit `REVOKE`/`GRANT` | More verbose, but matches Supabase guidance and the repo's own hardening pattern. |

**Installation:** no new packages are needed for the phase itself.

## Architecture Patterns

### Recommended Project Structure
```text
sql/
├── phase_50_kiosk_boundary_hardening_20260325.sql   # SQL hardening migration
test/
├── phase50/
│   └── kiosk_device_model_test.dart                  # safe label + UUID edge cases
lib/
├── models/
│   └── kiosk_device.dart                             # defensive display fallback
└── services/
    └── heartbeat_service.dart                        # persistent device UUID flow
```

### Pattern 1: SQL Boundary Enforcement
**What:** Expose privileged behavior through `SECURITY DEFINER` functions that use explicit `search_path`, schema-qualified relations, and explicit permission grants.
**When to use:** Any RPC callable from `authenticated` clients that should still enforce admin or outlet scope.
**Example:**
```sql
-- Source guidance:
-- https://supabase.com/docs/guides/database/functions
-- https://www.postgresql.org/docs/current/sql-createfunction.html

CREATE OR REPLACE FUNCTION public.set_device_nickname(
  p_device_id uuid,
  p_nickname text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role text := auth.jwt() -> 'app_metadata' ->> 'app_role';
BEGIN
  IF v_role NOT IN ('admin', 'kepala_gerai') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.kiosk_devices
  SET nickname = p_nickname,
      updated_at = now()
  WHERE id = p_device_id;
END;
$$;

REVOKE ALL ON FUNCTION public.set_device_nickname(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_device_nickname(uuid, text) TO authenticated;
```

### Pattern 2: JWT Claim-Based Role Gate
**What:** Read role and managed-outlet data from `auth.jwt()->'app_metadata'`.
**When to use:** Admin/kepala gerai RPCs and any read path that should not trust client-supplied values.
**Example:**
```sql
-- Source guidance:
-- https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook
-- https://supabase.com/docs/learn/auth-deep-dive/auth-row-level-security

DECLARE
  v_role text := auth.jwt() -> 'app_metadata' ->> 'app_role';
  v_managed_outlet uuid := NULLIF(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id', '')::uuid;
BEGIN
  IF v_role = 'kepala_gerai' AND v_managed_outlet IS NULL THEN
    RAISE EXCEPTION 'missing outlet scope';
  END IF;
END;
```

### Pattern 3: Safe Device Labels
**What:** Separate identity storage from display formatting, and never assume a UUID string is long enough for slicing.
**When to use:** Any UI that renders device names, fallbacks, or IDs derived from stored strings.
**Example:**
```dart
String safeDeviceDisplayName(String deviceUuid, {String? nickname}) {
  final trimmed = nickname?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;

  final compact = deviceUuid.replaceAll('-', '');
  if (compact.length < 8) return 'Kiosk';
  return 'Kiosk ${compact.substring(0, 8)}';
}
```

### Anti-Patterns to Avoid
- **Heartbeat rebind on conflict:** Do not let `upsert_kiosk_heartbeat` overwrite `outlet_id` after activation.
- **Public SECURITY DEFINER exposure:** Do not rely on `authenticated` alone; explicit `REVOKE`/`GRANT` still matters.
- **Writable metadata trust:** Do not read role access from mutable user metadata.
- **Raw substring display:** Do not slice `deviceUuid.substring(0, 8)` without length checks.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| RPC authorization | Client-side checks in Flutter | Database function guards with JWT claim checks | Clients can be bypassed; DB rules cannot. |
| Device label fallback | Ad hoc string slicing in widgets | One safe helper in the model or widget layer | Keeps all short/invalid UUID handling consistent. |
| Privileged SQL access | Implicit function permissions | Explicit `REVOKE` and `GRANT` | Matches Supabase guidance and limits accidental exposure. |

**Key insight:** the client can display security state, but it should not be the security boundary.

## Common Pitfalls

### Pitfall 1: `SECURITY DEFINER` Without `search_path`
**What goes wrong:** The function resolves objects through a writable path and can be steered toward unexpected relations or functions.
**Why it happens:** Developers assume `SECURITY DEFINER` alone is enough.
**How to avoid:** Set `search_path` explicitly and schema-qualify the relations you touch.
**Warning signs:** Functions created without `SET search_path`, especially when they are exposed to `authenticated`.

### Pitfall 2: JWT Claim Staleness
**What goes wrong:** Role changes are not visible until the JWT is refreshed, so a function may still see an older claim.
**Why it happens:** Supabase JWT claims are embedded in the token at issue time.
**How to avoid:** Treat claim changes as session changes and plan for refresh/re-auth boundaries.
**Warning signs:** A role change in the dashboard does not immediately affect RPC behavior.

### Pitfall 3: UI Assumes UUID Shape
**What goes wrong:** `substring(0, 8)` throws when the string is shorter than expected or malformed.
**Why it happens:** The fallback path is written for the happy path only.
**How to avoid:** Normalize the string first and guard the length before slicing.
**Warning signs:** Device cards crash or blank out for malformed rows.

### Pitfall 4: Silent Outlet Rebinding
**What goes wrong:** A heartbeat upsert can move a device from one outlet to another without a deliberate activation flow.
**Why it happens:** The conflict path updates all mutable columns instead of preserving the binding boundary.
**How to avoid:** Keep telemetry mutable, but make binding changes explicit and controlled.
**Warning signs:** A device starts reporting against a different outlet after a routine heartbeat.

## Code Examples

Verified patterns from official sources and current repo structure:

### Device-boundary RPC hardening
```sql
-- Source:
-- https://supabase.com/docs/guides/database/functions
-- https://supabase.com/docs/learn/auth-deep-dive/auth-row-level-security

CREATE OR REPLACE FUNCTION public.archive_device(p_device_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role text := auth.jwt() -> 'app_metadata' ->> 'app_role';
  v_managed_outlet uuid := NULLIF(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id', '')::uuid;
BEGIN
  IF v_role NOT IN ('admin', 'kepala_gerai') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.kiosk_devices
  SET is_active = false,
      updated_at = now()
  WHERE id = p_device_id
    AND (
      v_role = 'admin'
      OR outlet_id = v_managed_outlet
    );
END;
$$;
```

### Safe kiosk display fallback
```dart
String kioskLabel(String deviceUuid, {String? nickname}) {
  final custom = nickname?.trim();
  if (custom != null && custom.isNotEmpty) return custom;

  final compact = deviceUuid.replaceAll('-', '');
  return compact.length >= 8 ? 'Kiosk ${compact.substring(0, 8)}' : 'Kiosk';
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| `substring(0, 8)` directly in the model | Bounds-safe display helper | Phase 50 | Prevents crashes on malformed kiosk UUID values. |
| `SECURITY DEFINER` without explicit privilege review | `SECURITY DEFINER` + explicit `REVOKE`/`GRANT` + claim checks | Phase 50 | Stops public mutation abuse through exposed RPCs. |
| Heartbeat upsert that can move `outlet_id` on conflict | Heartbeat upsert that preserves binding after activation | Phase 50 | Prevents silent kiosk spoofing or rebinds. |

**Deprecated/outdated:**
- Blind trust in client-side role filtering: not sufficient for privileged RPCs.
- Raw UUID slicing in display code: safe only if the string is guaranteed long enough, which this code does not guarantee.
- Privileged functions with no `search_path`: Supabase docs explicitly warn to set it.

## Open Questions

1. **Should Phase 50 use `get_app_role()` or direct `auth.jwt()->'app_metadata'` checks?**
   - What we know: both patterns already exist in the repo.
   - What's unclear: whether `get_app_role()` is defined in a central SQL file outside the current scan.
   - Recommendation: confirm the canonical helper before writing new SQL; if it is not clearly defined, use direct `auth.jwt()` checks to keep the phase self-contained.

2. **Is outlet rebind ever allowed after first activation?**
   - What we know: setup currently captures a persistent device UUID before the first heartbeat, and the current heartbeat RPC can overwrite `outlet_id`.
   - What's unclear: whether a deliberate reactivation flow should exist for device transfer between outlets.
   - Recommendation: treat first activation as the binding boundary and require a separate explicit admin flow if rebind is ever needed.

3. **How should short or malformed UUIDs appear in the UI?**
   - What we know: the current model fallback can crash on short strings.
   - What's unclear: whether the product wants a generic label or a shortened normalized token.
   - Recommendation: show a generic `Kiosk` fallback rather than guessing a short hash.

## Validation Architecture

> Skip this section entirely if workflow.nyquist_validation is false in `.planning/config.json`

### Test Framework
| Property | Value |
|---|---|
| Framework | `flutter_test` |
| Config file | none - uses Flutter defaults |
| Quick run command | `flutter test test/device_identity_service_test.dart test/phase32/kiosk_device_model_test.dart test/phase50/kiosk_device_model_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| `SECDEV-01` | Heartbeat keeps telemetry up to date but never silently rebinds a device to a different outlet | SQL smoke + text review | `Select-String -Path sql/phase_50_kiosk_boundary_hardening_20260325.sql -Pattern 'outlet_id = EXCLUDED.outlet_id|SET search_path|REVOKE ALL|GRANT EXECUTE'` | Wave 0 (migration file missing) |
| `SECDEV-02` | Nickname and archive RPCs reject callers without the right role or outlet scope | SQL smoke + text review | `Select-String -Path sql/phase_50_kiosk_boundary_hardening_20260325.sql -Pattern 'auth.jwt\\(|app_metadata|managed_outlet_id|REVOKE ALL|GRANT EXECUTE'` | Wave 0 (migration file missing) |
| `SECSAFE-01` | Device cards never crash on malformed or short UUID data | unit | `flutter test test/phase50/kiosk_device_model_test.dart` | Wave 0 (new test file needed) |

### Sampling Rate
- **Per task commit:** `flutter test test/device_identity_service_test.dart test/phase32/kiosk_device_model_test.dart test/phase50/kiosk_device_model_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** confirm the SQL migration text and Supabase privileges before `$gsd-verify-work`

### Wave 0 Gaps
- `sql/phase_50_kiosk_boundary_hardening_20260325.sql` - new SQL migration for one-way heartbeat binding and caller-guarded nickname/archive RPCs.
- `test/phase50/kiosk_device_model_test.dart` - safe display-name tests for short UUIDs, empty UUIDs, and nickname precedence.
- `lib/models/kiosk_device.dart` - if the safe label helper is added here, the model test should cover the helper directly.

*(If the final implementation keeps the safety helper inside the widget instead of the model, move the unit tests there and keep the same behaviors.)*

## Sources

### Primary (HIGH confidence)
- [Supabase Docs - Database Functions](https://supabase.com/docs/guides/database/functions) - `SECURITY DEFINER`, explicit `search_path`, and function privilege guidance.
- [Supabase Docs - Custom Access Token Hook](https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook) - JWT claim shape including `app_metadata` and `user_metadata`.
- [Supabase Docs - Row Level Security Deep Dive](https://supabase.com/docs/learn/auth-deep-dive/auth-row-level-security) - example `auth.jwt()` claim access patterns.
- [Supabase Docs - Securing your data](https://supabase.com/docs/guides/database/secure-data) - RLS basics and service-role cautions.
- [PostgreSQL Docs - CREATE FUNCTION / search_path](https://www.postgresql.org/docs/current/sql-createfunction.html) - function security and search-path behavior.

### Secondary (MEDIUM confidence)
- [Repository: heartbeat service](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/services/heartbeat_service.dart) - current heartbeat path and persistent installation UUID flow.
- [Repository: kiosk device model](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/models/kiosk_device.dart) - current crash-prone display fallback.
- [Repository: admin dashboard](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/admin/admin_dashboard_screen.dart) - current kiosk-device RPC wiring and realtime subscription path.
- [Repository: phase 31 SQL](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase_31_kiosk_devices_20260320.sql) - current heartbeat upsert contract.
- [Repository: phase 32 SQL](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase_32_device_mgmt_20260322.sql) - current nickname/archive RPC contract.

### Tertiary (LOW confidence)
- None - this research used official docs and direct repository evidence only.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - the repo already uses Supabase Postgres RPCs, JWT claims, and `flutter_test`.
- Architecture: HIGH - current code paths and prior phase summaries make the hardening boundary clear.
- Pitfalls: HIGH - official Supabase/Postgres docs directly cover the relevant security footguns.

**Research date:** 2026-03-25
**Valid until:** 2026-04-01
