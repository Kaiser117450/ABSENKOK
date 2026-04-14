# Phase 52: Portal Surface Minimization - Research

**Researched:** 2026-03-25
**Domain:** Astro portal auth gating, public chooser minimization, and Supabase portal recovery contracts
**Confidence:** HIGH for the current portal implementation and recovery risks, MEDIUM for the final query-throttling thresholds

## Summary

Phase 52 is a surface-minimization phase, not a portal redesign. The accepted passwordless portal flow stays in scope, but the current implementation still exposes three avoidable surfaces:

1. Protected `/portal` requests are verified in middleware, but [src/middleware.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/middleware.ts) still calls `next()` before the protected-route redirect runs, so protected route handlers begin execution before the auth gate is final.
2. The public chooser search returns more fields than the login UI renders and still permits broad 2-character, 8-result probing through the anon-accessible `search_portal_employees(...)` RPC.
3. The current repair SQL reconstructs `employee_portal_accounts` from hidden-email patterns alone and updates an existing mapping on conflict without proving that the auth user is a confirmed `employee_portal` identity with the same explicit employee binding.

The safest Phase 52 shape keeps passwordless entry but tightens the surface around it:

1. Make middleware finish the protected-route auth decision before downstream route handlers run and treat `Astro.locals.portalUser` as the only verified protected-route session source.
2. Shrink public search to the chooser's real data contract, lower query/result caps, and keep fuzzy matching behind stricter query thresholds.
3. Treat repair and recovery as fail-closed tools: only confirmed `employee_portal` users with explicit employee bindings are eligible, and existing mappings are never opportunistically re-pointed.

There is no phase-specific `CONTEXT.md` for Phase 52. This research is based on the approved roadmap, requirements, current state, and the shipped portal implementation in the website and app repos.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| `SECPORT-01` | Protected `/portal` requests complete the auth guard before route handlers execute any sensitive reads or mutations. | [src/middleware.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/middleware.ts) verifies the session but only redirects after `await next()`, while protected pages like [src/pages/portal/index.astro](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/index.astro) and [src/pages/portal/attendance.astro](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/attendance.astro) still start their loaders before the middleware decision is final. |
| `SECPORT-02` | Public employee search returns only the minimum data needed to let an employee choose their card and caps enumeration-friendly query behavior. | [src/pages/portal/auth/search.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/auth/search.ts) exposes `home_outlet_id` and `active_badge_id` even though [src/pages/portal/login.astro](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/login.astro) only renders name, outlet label, position, photo, and the hidden `employee_id`. The current constants in [src/lib/portal/auth.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/auth.ts) still allow 2-character public probing with up to 8 results. |
| `SECPORT-03` | Portal account repair and recovery logic only restores mappings for confirmed `employee_portal` auth users with an explicit employee binding and must not overwrite an existing mapping opportunistically. | [sql/repair_employee_portal_accounts_20260323.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/repair_employee_portal_accounts_20260323.sql) rebuilds mappings from hidden email patterns without checking `app_role`, explicit `employee_id` metadata, or confirmation state, and its `ON CONFLICT ... DO UPDATE` can repoint an existing mapping. [src/lib/portal/provision.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/provision.ts) also reuses an existing hidden-email auth user by email alone. |

## Current State Analysis

### 1. Middleware verifies the session, but protected-route enforcement happens too late

[src/middleware.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/middleware.ts) already uses `supabase.auth.getUser()` and caches the verified result in `context.locals.portalUser`. That part is correct. The remaining gap is order of operations:

1. middleware loads the verified user
2. middleware calls `await next()`
3. only after the route handler finishes does middleware redirect unauthenticated protected requests

That means a protected portal route can still run page-level code before the auth gate is final. The current pages mostly fail safely because [src/lib/portal/employee.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/employee.ts) returns `unauthenticated` when `portalUser` is `null`, but the contract is still backwards: the route starts first and the gate completes later. Phase 52 should make the middleware the decisive pre-handler gate for protected `/portal` requests.

### 2. The public chooser contract is broader than the UI actually needs

The current search path is split across:

- [sql/phase_39_portal_read_path_hardening_20260323.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase_39_portal_read_path_hardening_20260323.sql)
- [src/lib/portal/auth.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/auth.ts)
- [src/pages/portal/auth/search.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/auth/search.ts)
- [src/pages/portal/login.astro](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/login.astro)

The SQL and endpoint still return:

- `employee_id`
- `employee_name`
- `home_outlet_id`
- `home_outlet_name`
- `position`
- `photo_url`
- `active_badge_id`

The chooser only uses:

- `employee_id`
- `employee_name`
- `home_outlet_name`
- `position`
- `photo_url`

That makes `home_outlet_id` and `active_badge_id` unnecessary exposure. The public search path is also still generous for an unauthenticated endpoint:

- `SEARCH_MIN_LENGTH = 2`
- `SEARCH_MAX_RESULTS = 8`
- trigram fallback starts at 3 characters

Phase 52 does not need to remove public chooser search entirely, because the product explicitly keeps passwordless entry. It does need to reduce the searchable surface to the minimum chooser DTO and tighten query/result behavior so the endpoint is less useful for broad employee enumeration.

### 3. Repair SQL is pattern-driven instead of binding-driven

[sql/repair_employee_portal_accounts_20260323.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/repair_employee_portal_accounts_20260323.sql) derives `employee_id` from the hidden email format alone, then inserts or updates `employee_portal_accounts`. The current script does not require:

- a confirmed portal auth identity
- `app_metadata.app_role = 'employee_portal'`
- `app_metadata.employee_id` to exist and match the hidden-email-derived UUID
- an existing mapping conflict to stay untouched when it points at a different auth user

That is exactly the kind of recovery shortcut Phase 52 is meant to close. Repair should be explicit and conservative. If the auth user does not already prove that it is the right `employee_portal` identity for that employee, the script should skip it rather than reconstruct a mapping optimistically.

### 4. Passwordless convenience is an accepted boundary, not a bug to remove

The active requirements and project notes are explicit:

- [REQUIREMENTS.md](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/.planning/REQUIREMENTS.md) marks removing passwordless sign-in as out of scope.
- [PROJECT.md](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/.planning/PROJECT.md) keeps "portal public search and repair flows expose only the minimum data needed while keeping passwordless employee entry" as the live objective.
- [src/pages/portal/login.astro](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/login.astro) auto-submits as soon as the employee card is selected.
- [src/pages/portal/auth/sign-in.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/auth/sign-in.ts) signs in using the hidden email/password derived from `employee_id`.

So Phase 52 must not reintroduce a manual password field, a portal-only whitelist, or a different employee-facing login credential. The correct move is to minimize what the public surface reveals and harden the recovery paths around the accepted passwordless model.

## Standard Stack

### Core

| Library / System | Version | Purpose | Why Standard |
|---|---:|---|---|
| Astro middleware + SSR routes | current website stack | Pre-handler auth gating for protected portal routes | The website already protects `/portal` through middleware and server-rendered routes. |
| `@supabase/ssr` | current website stack | Verified server-side auth user retrieval and cookie refresh | The current middleware and server client helpers already use the official SSR flow. |
| Supabase Postgres functions | current SQL stack | Public search RPC and portal-identity repair scripts | The portal chooser and employee resolution are already defined as SQL contracts. |
| Flutter `flutter_test` | SDK bundled | Lightweight SQL contract coverage in this repo | Existing security phases already use focused Dart tests to guard SQL hardening files. |

### Supporting

| Library / System | Version | Purpose | When to Use |
|---|---:|---|---|
| Website `npm run check` | existing website validation | Typecheck Astro/TypeScript portal changes | Use after middleware, endpoint, or portal helper updates. |
| Website `npm run build` | existing website validation | End-to-end SSR/build sanity for the portal repo | Use as the main automated gate for website-side hardening. |
| PowerShell `Select-String` source checks | local tooling | Cheap contract smoke for SQL and endpoint fields | Use where no dedicated frontend/unit harness exists yet. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Early middleware redirect before `next()` | Rely on page-level redirects only | Safer than nothing, but still lets protected route handlers start before the gate is final. |
| Minimal chooser DTO | Keep returning internal IDs the UI does not render | Faster to leave alone, but increases public data exposure without product value. |
| Stricter query/result caps | Leave the 2-char / 8-result public search contract intact | Better convenience, but too friendly for broad probing on a public endpoint. |
| Fail-closed repair script with explicit binding proof | Repair by hidden-email pattern alone | Easier recovery, but can reconstruct or repoint mappings the auth record has not actually proved. |

## Architecture Patterns

### Pattern 1: Middleware-first protected route gate

**What:** Middleware verifies the session, caches `portalUser`, and returns the unauthenticated redirect before `next()` for protected `/portal` routes.
**When to use:** Any route under `/portal` that is not explicitly public.
**Why:** The auth decision should complete before downstream loaders like `loadPortalHome()` or `loadPortalAttendanceRecap()` can begin.

### Pattern 2: One public chooser DTO

**What:** Public search returns only `employee_id`, `employee_name`, `home_outlet_name`, `position`, and `photo_url`.
**When to use:** The `/portal/auth/search` endpoint and the `search_portal_employees(...)` SQL contract.
**Why:** That is the exact data the chooser renders today. Extra fields increase exposure without improving the employee flow.

### Pattern 3: Tight public search caps on both layers

**What:** Keep the cap in both SQL and Astro helpers. Recommended Phase 52 direction:

- minimum normalized length: 3 characters
- result cap: 5
- delayed trigram fallback: 4+ characters
- explicit maximum normalized input length

**Why:** The endpoint is intentionally public, so the limit must not depend on the browser behaving nicely.

### Pattern 4: Recovery requires explicit proof, not inference

**What:** Repair and recovery only reuse an auth identity when all of the following are already true:

- the auth user is confirmed
- `app_metadata.app_role = 'employee_portal'`
- `app_metadata.employee_id` exists and matches the hidden-email-derived employee id
- the target employee is still active and not archived

**Why:** Hidden email format alone is not a strong enough recovery proof once the system is already in a damaged state.

### Pattern 5: Existing mappings are stable unless they already agree

**What:** Repair scripts may refresh timestamps or reinsert missing rows, but they must not swap `employee_portal_accounts.employee_id` to a different `auth_user_id` on conflict.
**When to use:** Any `INSERT ... ON CONFLICT` recovery path that touches `employee_portal_accounts`.
**Why:** Recovery should restore known-good mappings, not silently change identity bindings.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Protected route auth sequencing | Page-local fallback auth checks as the primary guard | Middleware pre-handler redirect plus request-local verified user | Keeps one place responsible for the protected-route boundary. |
| Chooser payload shaping | UI-only field filtering after the RPC returns extra columns | A minimal SQL + endpoint DTO | Prevents unnecessary public data from leaving the server at all. |
| Search throttling | Client-only debounce as the real cap | Server-enforced min length and result limit | Browser behavior is not a reliable security control. |
| Portal mapping repair | Hidden-email parsing alone | Confirmed `employee_portal` metadata plus stable conflict handling | Recovery should prove identity rather than infer it. |

## Common Pitfalls

### Pitfall 1: Redirecting after `next()`

**What goes wrong:** The portal page loader starts anyway, even though the final response becomes a redirect.
**How to avoid:** For protected routes, redirect before `next()` and only call `next()` after the verified user is accepted.

### Pitfall 2: Letting the chooser contract drift away from the rendered UI

**What goes wrong:** Public search starts returning internal identifiers or profile data the employee never actually needs to see.
**How to avoid:** Keep one explicit endpoint DTO and make the SQL function return exactly that shape.

### Pitfall 3: Treating convenience provisioning and recovery as the same thing

**What goes wrong:** A helper that is allowed to create a missing hidden auth user is also allowed to "recover" or overwrite identities that it has not actually verified.
**How to avoid:** Keep passwordless auto-provisioning for new hidden auth users, but fail closed when an existing hidden-email user has conflicting metadata or identity.

### Pitfall 4: Overwriting a damaged mapping because it looks repairable

**What goes wrong:** The repair script silently repoints an employee to a different auth user, making the data look healthy while the identity contract is now ambiguous.
**How to avoid:** Skip conflicts that do not already agree. Repair should surface a manual exception instead of changing identity ownership.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | Astro `npm run check` / `npm run build`, PowerShell source-contract checks, focused `flutter_test` SQL contract |
| Config file | none beyond existing repo defaults |
| Quick run command | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` |
| Full suite command | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` plus `C:\flutter\bin\flutter.bat test test/phase52/portal_recovery_contract_test.dart` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| `SECPORT-01` | Protected portal routes redirect before protected loaders execute | source review + build | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` | Existing |
| `SECPORT-02` | Public search returns only chooser-safe fields under stricter query/result caps | source smoke + check | `powershell -Command "Select-String -Path 'sql/phase_52_portal_search_minimization_20260325.sql','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/auth.ts','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/auth/search.ts','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/login.astro' -Pattern 'SEARCH_MIN_LENGTH','SEARCH_MAX_RESULTS','SEARCH_MAX_QUERY_LENGTH','employee_name','home_outlet_name','photo_url' | Measure-Object"` | Missing in Phase 52 |
| `SECPORT-03` | Recovery paths only restore confirmed employee-portal bindings and never repoint existing mappings | unit / contract | `C:\flutter\bin\flutter.bat test test/phase52/portal_recovery_contract_test.dart` | Missing in Phase 52 |

### Sampling Rate

- **Per task commit:** run the smallest relevant command (`npm run check`, source smoke, or the focused Phase 52 Flutter contract test)
- **Per wave merge:** `npm run build` in the website repo plus the focused Phase 52 Flutter contract test
- **Phase gate:** protected-route redirect behavior, chooser flow, and repair script safety all need one final manual pass

### Wave 0 Gaps

- `sql/phase_52_portal_search_minimization_20260325.sql` - additive search hardening patch
- `sql/repair_employee_portal_accounts_20260325.sql` - fail-closed recovery script
- `test/phase52/portal_recovery_contract_test.dart` - focused contract test for the new recovery script

### Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|---|---|---|---|
| Unauthenticated navigation to `/portal` and `/portal/attendance` never flashes protected content and immediately redirects to `/portal/login` | `SECPORT-01` | Needs a real browser request lifecycle, not just static code checks | Open the portal in a clean browser with no Supabase cookies, request `/portal` and `/portal/attendance`, and confirm the browser lands on `/portal/login` without protected shell content rendering first. |
| A valid employee can still use the public chooser and auto-submit into the passwordless portal flow after the tighter caps | `SECPORT-02` | Needs browser typing and live endpoint behavior | On `/portal/login`, type a valid employee name using the new minimum-character threshold, pick the correct card, and confirm the form auto-submits into the portal as before. |
| Damaged portal mappings recover only for explicitly confirmed employee-portal identities, while conflicting bindings are skipped for manual review | `SECPORT-03` | Requires a prepared Supabase recovery scenario | In a staging or safe recovery environment, remove or rename `employee_portal_accounts`, run the new repair script, and confirm that only confirmed `employee_portal` identities with matching `employee_id` metadata are restored and that conflicting rows remain untouched. |

## Sources

### Primary (HIGH confidence)

- [ROADMAP.md](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/.planning/ROADMAP.md)
- [REQUIREMENTS.md](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/.planning/REQUIREMENTS.md)
- [STATE.md](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/.planning/STATE.md)
- [PROJECT.md](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/.planning/PROJECT.md)
- [src/middleware.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/middleware.ts)
- [src/lib/portal/auth.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/auth.ts)
- [src/lib/portal/employee.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/employee.ts)
- [src/lib/portal/provision.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/provision.ts)
- [src/pages/portal/auth/search.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/auth/search.ts)
- [src/pages/portal/auth/sign-in.ts](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/auth/sign-in.ts)
- [src/pages/portal/login.astro](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/login.astro)
- [src/pages/portal/index.astro](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/index.astro)
- [src/pages/portal/attendance.astro](C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/attendance.astro)
- [sql/phase_39_portal_read_path_hardening_20260323.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase_39_portal_read_path_hardening_20260323.sql)
- [sql/repair_employee_portal_accounts_20260323.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/repair_employee_portal_accounts_20260323.sql)
- [sql/phase_37_employee_portal_foundation_20260322.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase_37_employee_portal_foundation_20260322.sql)

### Secondary (MEDIUM confidence)

- [37-RESEARCH.md](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/.planning/phases/37-portal-foundation-employee-auth/37-RESEARCH.md)
- [39-RESEARCH.md](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/.planning/phases/39-employee-portal-schedule-ux/39-RESEARCH.md)
- [44-RESEARCH.md](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/.planning/phases/44-portal-exception-states-hardening/44-RESEARCH.md)

## Metadata

**Confidence breakdown:**

- Auth-gate sequencing: HIGH - the ordering bug is directly visible in `middleware.ts`.
- Public search surface: HIGH - the endpoint, SQL contract, and chooser UI are all visible locally.
- Recovery hardening: HIGH - the existing repair SQL and hidden-email provisioning helper show the exact current recovery assumptions.
- Final cap thresholds: MEDIUM - the direction is clear, but the exact minimum-length/result-count tuning is still a product-security tradeoff to validate during execution.

**Research date:** 2026-03-25
**Valid until:** 2026-04-08
