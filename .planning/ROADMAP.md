# Roadmap: Absensi Enakko

## Shipped Milestones

- ✅ **v7.0 Android Release Hardening** — Phases 46-49 plus 48.1, shipped 2026-03-25 ([roadmap archive](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/milestones/v7.0-ROADMAP.md), [requirements archive](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/milestones/v7.0-REQUIREMENTS.md))

## Active Milestone

### v7.1 Security Hardening

**Goal:** Close the non-passwordless security findings from the 2026-03-25 Codex Security review while preserving the intentionally passwordless employee portal flow.
**Phases:** 50-53
**Requirements:** 10 mapped / 10 total

## Current Position

- Active milestone is now **v7.1 Security Hardening**.
- The accepted risk boundary for this milestone is explicit: passwordless portal sign-in remains in place by product decision, so only the non-passwordless findings are in scope.
- The final published v7.0 asset remains the obfuscated smoke-verified `ABSENKOK-v7.0.0+8013.apk` on GitHub Release `v7.0.0`.

## Proposed Roadmap

**4 phases** | **10 requirements mapped** | All covered

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 50 | Kiosk Device Boundary Hardening | Complete 2026-03-25 — stop kiosk spoofing and public device-mutation abuse without breaking current setup UX | `SECDEV-01`, `SECDEV-02`, `SECSAFE-01` | 4 |
| 51 | Admin Session Trust Hardening | Complete 2026-03-25 — remove privileged access paths that trust writable metadata or stale remembered roles | `SECACC-01`, `SECACC-02`, `SECACC-03` | 4 |
| 52 | Portal Surface Minimization | Complete 2026-03-25 — reduce portal leakage and recovery abuse while preserving passwordless entry | `SECPORT-01`, `SECPORT-02`, `SECPORT-03` | 4 |
| 53 | Security Rollout & Acceptance | Capture additive deployment steps and verify accepted-risk boundaries before closeout | `SECOPS-01` | 4 |

### Phase 50: Kiosk Device Boundary Hardening

**Status:** Complete (2026-03-25)
**Goal:** Stop kiosk spoofing and public device-mutation abuse without breaking current setup UX.
**Depends on:** v7.0 closeout baseline
**Requirements:** `SECDEV-01`, `SECDEV-02`, `SECSAFE-01`
**Plans:** 2/2 plans complete

Plans:

- [x] 50-01: Activation-bound heartbeat contract and scoped device-management RPC hardening
- [x] 50-02: Safe kiosk device parsing and UUID fallback regression coverage

Success criteria:
1. Kiosk activation binds one physical device UUID to the verified outlet before heartbeat writes are accepted.
2. Heartbeat writes can no longer create or reassign kiosk rows from an unauthenticated or unbound path.
3. Device nickname/archive RPCs enforce authenticated admin or kepala gerai scope instead of remaining callable by `PUBLIC`.
4. Malformed kiosk UUID data does not crash the device-card or dashboard UI.

### Phase 51: Admin Session Trust Hardening

**Status:** Complete (2026-03-25)
**Goal:** Remove privileged access paths that trust writable metadata or stale remembered roles.
**Depends on:** Phase 50
**Requirements:** `SECACC-01`, `SECACC-02`, `SECACC-03`
**Plans:** 2/2 plans complete

Plans:

- [x] 51-01: Fail-closed SQL role hardening for privileged analytics RPCs and contract coverage
- [x] 51-02: Trusted admin-session claim parsing and biometric re-entry hardening for Flutter admin flows

Success criteria:
1. Dashboard and analytics RPCs fail closed when `app_role` is missing, invalid, or outside the allowed admin roles.
2. Flutter auth-state handling derives admin and kepala gerai mode from `app_metadata` only.
3. Biometric login no longer restores privileged UI state from remembered role data alone.
4. Privileged UI routing still works for valid admin and kepala gerai sessions after the hardening changes.

### Phase 52: Portal Surface Minimization

**Status:** Complete (2026-03-25)
**Goal:** Reduce portal leakage and recovery abuse while preserving passwordless entry.
**Depends on:** Phase 51
**Requirements:** `SECPORT-01`, `SECPORT-02`, `SECPORT-03`
**Plans:** 3/3 plans complete

Plans:

- [x] 52-01: Protected-route middleware gating and middleware-trusted portal employee resolution
- [x] 52-02: Public chooser SQL minimization and aligned Astro search boundary hardening
- [x] 52-03: Fail-closed portal-account recovery and passwordless hidden-user reuse hardening

Success criteria:
1. Protected `/portal` route handlers no longer execute sensitive logic before the middleware auth gate resolves.
2. Public search returns only the minimum chooser data and applies tighter query/result limits suitable for the current UX.
3. Portal repair SQL only restores confirmed `employee_portal` users with explicit employee bindings and never opportunistically overwrites an existing mapping.
4. The passwordless portal chooser flow still works for the accepted in-scope behavior after the hardening pass.

### Phase 53: Security Rollout & Acceptance

**Goal:** Capture additive deployment steps and verify accepted-risk boundaries before closeout.
**Depends on:** Phase 52
**Requirements:** `SECOPS-01`

Success criteria:
1. The SQL rollout order is documented clearly for a live production Supabase project with additive migrations only.
2. The acceptance checklist distinguishes fixed findings from explicitly accepted passwordless findings.
3. Verification covers Flutter admin login, kiosk heartbeat/device management, and portal search/middleware behavior.
4. The milestone closeout packet names any remaining accepted risks and the PRs or follow-up work tied to them.

---
_For current project status, see `.planning/PROJECT.md`_
