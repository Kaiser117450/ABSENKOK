---
phase: 53-security-rollout-acceptance
type: accepted-risk-ledger
created: 2026-03-25
---

# Phase 53 — Accepted Risk and Follow-Up Ledger

This ledger records the retained-risk boundary for the v7.1 Security Hardening milestone. It exists so the closeout packet (`53-ACCEPTANCE.md`) can delegate retained-risk detail here rather than burying it in summary prose.

**Acceptance packet:** `.planning/phases/53-security-rollout-acceptance/53-ACCEPTANCE.md`

---

## Accepted Risks

### AR-01: Passwordless Employee Portal Sign-In

**Description:** Employees access the portal by selecting their name card from the public chooser. No password is required. The chooser is public (no auth needed to load it).

**Why it remains in scope:**
This is a deliberate product decision made before the v7.1 milestone. The primary user population (restaurant workers checking their own schedule and attendance) has no reliable mechanism for managing passwords. Requiring a password would break the portal's core UX contract.

**Current guardrails from shipped hardening work (Phases 50-52):**

| Guardrail | Description | Shipped in |
|-----------|-------------|------------|
| Chooser returns minimal DTO only | `search_portal_employees` returns only the display name and card token — no PII, no email, no UUID | Phase 52 SQL |
| Chooser 3-character minimum | Inputs under 3 normalized characters return no results, reducing enumeration exposure | Phase 52 SQL |
| Chooser 5-result cap | At most 5 results returned per query | Phase 52 SQL |
| Chooser 64-character input limit | Inputs over 64 characters are rejected | Phase 52 SQL |
| Chooser no-store responses | Astro chooser endpoint sends `Cache-Control: no-store` headers | Phase 52 Astro |
| Middleware auth boundary enforced | After portal sign-in, all protected routes verify auth before calling `next()` | Phase 52 Astro |
| `resolvePortalEmployee()` trusts middleware boundary | No downstream re-fetch of auth state on authenticated pages | Phase 52 Astro |
| Portal provisioning fails closed | `employee_portal_accounts` provisioning skips any hidden auth user with conflicting `employee_portal` metadata | Phase 52 Flutter + SQL |

**Evidence path back to acceptance packet:** AR-01 is listed as Accepted Finding A-01 in `53-ACCEPTANCE.md`.

---

### AR-02: Local-Only Portal Logout

**Description:** Portal sign-out calls `supabase.auth.signOut({ scope: 'local' })`, which ends the portal session without invalidating the global Supabase auth session. If the employee is also authenticated to another Supabase surface (admin, etc.) from the same browser, that session persists.

**Why it remains in scope:**
This behavior was explicitly locked in the Phase 39 architecture decision (Decision 39-02 in STATE.md). Portal logout is intentionally scoped to the portal session only. Invalidating the global session could have unintended consequences on admin sessions sharing the same browser context. The accepted boundary is: portal logout = portal session end only.

**Current guardrails from shipped hardening work (Phases 50-52):**

| Guardrail | Description | Shipped in |
|-----------|-------------|------------|
| Middleware re-validates on every protected route | Even after a lingering global session, the middleware verifies the portal-specific auth state for each request | Phase 52 Astro |
| Portal session is browser-local | `scope: 'local'` means the token is cleared from this browser; no cross-device persistence | Phase 39 |

**Evidence path back to acceptance packet:** AR-02 is listed as Accepted Finding A-02 in `53-ACCEPTANCE.md`.

---

## Follow-Up Work / PRs

### Tied to AR-01 (Passwordless Portal Sign-In)

None yet. No tracked PR, issue, or follow-up phase exists today for adding password or OTP-based portal authentication. If this becomes a future requirement, a new milestone or phase should be created with explicit scope for changing the portal auth model.

### Tied to AR-02 (Local-Only Portal Logout)

None yet. No tracked PR or follow-up exists for changing the logout scope. If the product decision is revisited, the Phase 39 architecture decision (STATE.md Decision 39-02) must be explicitly superseded in planning.

---

## Operator-Only Appendix: Recovery Script

**Script:** `sql/repair_employee_portal_accounts_20260325.sql`

This script is NOT part of the normal rollout path. It is an operator-only repair tool.

**When it may be used (all conditions must be true):**
1. An `employee_portal_accounts` row exists with a broken or missing `auth_user_id` link.
2. The affected employee's hidden auth user (`employee+<uuid>@portal.absenkok.internal`) has confirmed `employee_portal` app metadata that matches the expected `employee_id`.
3. A human operator with production approval has reviewed the script and confirmed it addresses the identified broken rows.

**What it does:** Restores confirmed `employee_portal` identities with matching `employee_id` metadata. Skips any row where there is a metadata conflict — it does not repoint `auth_user_id` to an unconfirmed account. This fail-closed behavior was introduced in Phase 52 (Fix F-07 in `53-ACCEPTANCE.md`).

**Evidence required if applied:** Record which rows were repaired, the script output, and the approval reference in the Operator Sign-Off section of `53-ACCEPTANCE.md`.

**Current status:** Not applied. No broken rows have been identified that meet the application conditions as of the Phase 53 planning date (2026-03-25).
