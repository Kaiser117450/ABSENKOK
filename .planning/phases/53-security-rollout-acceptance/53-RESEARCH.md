# Phase 53: Security Rollout & Acceptance - Research

**Researched:** 2026-03-25  
**Domain:** Live security rollout, additive Supabase migration sequencing, and cross-surface acceptance verification  
**Confidence:** HIGH

## Summary

This phase is not about adding new product behavior. It is the closeout layer for the security hardening already implemented in Phases 50-52: document the rollout order, prove the live production database can absorb the additive migrations safely, and capture acceptance evidence that separates fixed findings from the passwordless portal behavior that is intentionally retained.

No Phase 53 `CONTEXT.md` exists in this workspace. This research therefore relies on `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/RETROSPECTIVE.md`, the Phase 50-52 summaries/user setup docs, the SQL migrations, the existing tests, and the Android release runbook. The planner should treat those files as the source of truth for scope and acceptance framing.

Primary recommendation: use one additive rollout checklist in this exact order - Phase 50 SQL, Phase 51 SQL, Phase 52 SQL, then the Phase 52 recovery script only if an approved repair scenario exists - and verify the result with existing Flutter and Astro checks before writing closeout evidence.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SECOPS-01 | Operators have one additive rollout checklist for the SQL, Astro, and Flutter hardening changes that is safe to apply against the live production database. | Phase 50-52 summaries show the shipped security boundaries; the SQL scripts define the additive order; `docs/android-release-runbook.md` provides the operator-style sequencing; the existing tests cover the hardening contracts that must remain green after rollout. |
</phase_requirements>

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|---|---:|---|---|
| Supabase PostgreSQL migrations | Live production project `tmapxdftdhxovthgbhww` | Apply additive SECURITY DEFINER hardening in the live database | The security work is database-first; the production rollout must stay additive and reversible by re-run, not by destructive edits. |
| Astro SSR portal stack | `astro@^5.18.1`, `@supabase/ssr@^0.9.0`, `@supabase/supabase-js@^2.99.3` | Enforce portal middleware, chooser minimization, and recovery behavior | The portal hardening already lives in SSR middleware and server-side loaders, so acceptance must include Astro checks. |
| Flutter app stack | Flutter 3.41.1 app (`pubspec.yaml` version `7.0.0+8013`), `supabase_flutter@^2.8.4`, `flutter_test` | Validate kiosk/admin trust boundaries and existing hardening regressions | The kiosk and admin surfaces are part of the security boundary, so acceptance must include Flutter test evidence. |

### Supporting
| Library / Tool | Version | Purpose | When to Use |
|---|---:|---|---|
| `docs/android-release-runbook.md` | current | Operator sequencing for the release lane | Use as the template for a concrete, ordered checklist. |
| `npm run check` / `npm run build` | `astro check` / `astro build` | Portal surface verification | Use to confirm the Astro surface still compiles and the portal hardening remains valid. |
| `flutter test` | `flutter_test` | Regression verification for phase contracts | Use for the targeted phase tests and the full suite after acceptance gating. |
| Supabase SQL Editor | current | Production application of additive migrations | Use only for approved live rollout and recovery steps. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|---|---|---|
| One ordered rollout checklist | Ad hoc operator decisions per file | Faster in the moment, but it makes acceptance evidence inconsistent and raises the risk of skipping a prerequisite migration. |
| Live destructive repair | A conflict-skipping repair script | Destructive repair is simpler to reason about locally, but it is not safe for a live production database with active users. |
| Code-only verification | A mix of SQL, Astro, and Flutter checks | Code-only proof misses the production rollout step and would not satisfy SECOPS-01. |

**Installation / rollout baseline:**
```powershell
flutter test
npm run check
npm run build
```

## Architecture Patterns

### Recommended Project Structure
```text
sql/
├── phase_50_kiosk_boundary_hardening_20260325.sql
├── phase_51_admin_session_trust_20260325.sql
├── phase_52_portal_search_minimization_20260325.sql
└── repair_employee_portal_accounts_20260325.sql

.planning/phases/53-security-rollout-acceptance/
└── 53-RESEARCH.md

test/
├── phase50/kiosk_device_model_test.dart
├── phase51/admin_session_claims_test.dart
├── phase51/sql_role_guard_contract_test.dart
└── phase52/portal_recovery_contract_test.dart

docs/
└── android-release-runbook.md
```

### Pattern 1: Additive Rollout Ledger
**What:** Document the rollout in the same order the system depends on it: Phase 50 SQL first, Phase 51 SQL second, Phase 52 SQL third, then the recovery script only when there is an approved portal-account repair scenario.  
**When to use:** Any live production Supabase change on this milestone.  
**Example:**
```text
1. Apply sql/phase_50_kiosk_boundary_hardening_20260325.sql
2. Apply sql/phase_51_admin_session_trust_20260325.sql
3. Apply sql/phase_52_portal_search_minimization_20260325.sql
4. Run sql/repair_employee_portal_accounts_20260325.sql only for an approved repair case
5. Re-run Flutter and Astro checks
```

### Pattern 2: Acceptance Split by Finding Class
**What:** Separate closeout evidence into three buckets: fixed findings, intentionally accepted passwordless findings, and operator-only follow-ups.  
**When to use:** Milestone acceptance, release notes, or any final security closeout packet.  
**Example:**
```text
Fixed findings:
- kiosk spoofing / heartbeat rebinding
- stale-role admin trust
- portal surface leakage and unsafe recovery

Accepted by product decision:
- passwordless employee portal sign-in remains
- local-only portal logout remains
```

### Pattern 3: Surface-Specific Regression Proof
**What:** Verify each surface with the narrowest command that exercises its security contract.  
**When to use:** After rollout and before closeout.  
**Example:**
```powershell
flutter test test/phase50/kiosk_device_model_test.dart test/phase51/admin_session_claims_test.dart test/phase51/sql_role_guard_contract_test.dart test/phase52/portal_recovery_contract_test.dart
npm run check
npm run build
```

### Anti-Patterns to Avoid
- **Routine recovery execution:** Do not run `sql/repair_employee_portal_accounts_20260325.sql` as part of the normal rollout; it is an operator repair tool only.
- **Single-surface verification:** Do not verify only Flutter or only Astro; SECOPS-01 spans SQL, Astro, and Flutter together.
- **Risk reclassification drift:** Do not relabel the intentionally retained passwordless portal behavior as a regression; document it as an accepted finding.
- **Manual SQL improvisation:** Do not hand-edit the production database outside the additive scripts.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Live migration sequencing | A one-off shell script or ad hoc operator memory | A fixed checklist tied to the phase SQL files and runbook | The rollout must be repeatable and auditable. |
| Portal acceptance framing | A free-form note that mixes fixed and accepted findings | A closeout table that explicitly labels accepted passwordless behavior | The milestone scope depends on preserving that product decision. |
| Recovery logic | A destructive "repair" query that overwrites mappings | `sql/repair_employee_portal_accounts_20260325.sql` with conflict skips | The live system cannot afford opportunistic rewrites. |
| Regression coverage | A single smoke test | Existing phase tests plus Astro build/check commands | The hardening spans multiple trust boundaries. |

**Key insight:** this phase is about proving rollout safety, not proving the hardening work exists. The implementation already exists; the closeout packet must prove it can be applied and interpreted correctly in production.

## Common Pitfalls

### Pitfall 1: Treating the recovery script as a rollout step
**What goes wrong:** Operators may apply the repair script even when no recovery is needed, which widens the accepted portal-trust surface unnecessarily.  
**Why it happens:** The script sits next to the rollout SQL and looks like part of the same bundle.  
**How to avoid:** Mark it explicitly as conditional and operator-only.  
**Warning signs:** The checklist says "apply all SQL files" without a repair condition.

### Pitfall 2: Collapsing fixed and accepted findings into one bucket
**What goes wrong:** The closeout packet stops being useful because it no longer says what changed versus what was intentionally retained.  
**Why it happens:** Passwordless portal entry is still present, and that can blur the line between a deliberate decision and an unresolved issue.  
**How to avoid:** Use separate sections for remediated findings and accepted findings.  
**Warning signs:** Acceptance text says "security issues remain" without naming which ones are by design.

### Pitfall 3: Verifying only source code, not production application
**What goes wrong:** The checklist passes locally while the live Supabase project still lacks the additive migrations.  
**Why it happens:** The phase spans code, SQL, and operator actions, but only code is easy to test automatically.  
**How to avoid:** Require explicit evidence that the SQL was applied in the production project.  
**Warning signs:** Tests are green, but there is no rollout confirmation from Supabase.

### Pitfall 4: Broadening the portal search boundary again during acceptance
**What goes wrong:** A late "fix" re-exposes chooser data or recovery behavior that was already minimized.  
**Why it happens:** Acceptance work often tempts teams to tweak UX instead of freezing the boundary.  
**How to avoid:** Keep acceptance focused on proof, not redesign.  
**Warning signs:** Any attempt to expand chooser DTOs, query caps, or recovery scope during closeout.

## Code Examples

Verified patterns from repo artifacts:

### Additive rollout order
```text
Phase 50 SQL -> Phase 51 SQL -> Phase 52 SQL -> conditional recovery script -> Flutter/Astro verification
```

### Acceptance taxonomy
```text
Fixed findings:
- kiosk device activation and heartbeat rebinding
- null-role admin analytics access
- portal route/auth leakage and unsafe account repair

Accepted findings:
- passwordless employee portal entry remains intentional
- local-only portal logout remains intentional
```

### Minimal verification commands
```powershell
flutter test test/phase50/kiosk_device_model_test.dart test/phase51/admin_session_claims_test.dart test/phase51/sql_role_guard_contract_test.dart test/phase52/portal_recovery_contract_test.dart
npm run check
npm run build
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Ad hoc SQL execution from memory | Additive phase scripts with operator setup docs | Phases 50-52 | Rollout becomes auditable and safer on the live database. |
| Client-trusted or stale session assumptions | Server-issued `app_metadata` and middleware-cached request state | Phases 51-52 | Privileged surfaces stop trusting writable or stale client state. |
| Public chooser and repair logic with broad exposure | Tight DTOs, capped search, and conflict-skipping repair | Phase 52 | Portal recovery and search are narrowed without removing passwordless entry. |
| "Everything green" acceptance | Explicitly labeled fixed vs accepted findings | Phase 53 goal | Closeout can say what is secure now and what remains intentionally retained. |

**Deprecated/outdated:**
- Treating the recovery script as a routine migration is outdated for this milestone; it is now a conditional operator tool.
- Using one undifferentiated acceptance summary for passwordless and non-passwordless findings is outdated; the closeout packet must split them.

## Open Questions

1. **Should Phase 53 produce a dedicated closeout packet file in the planning folder?**
   - What we know: SECOPS-01 only requires a safe additive rollout checklist and acceptance evidence.
   - What's unclear: whether the planner wants a separate checklist artifact in addition to this research file.
   - Recommendation: create a concise closeout checklist if the planner expects a handoff artifact, otherwise keep the acceptance evidence in the phase summary.

2. **How much live-production proof is required after the additive SQL is applied?**
   - What we know: the system is live and the database must stay additive only.
   - What's unclear: whether acceptance needs a full end-to-end smoke run or only a confirmed SQL application record plus targeted regression tests.
   - Recommendation: capture at least one verification item per surface if the operator window allows it.

3. **Should the Phase 52 recovery script be mentioned in the closeout packet as a recurring operator note or only as a conditional appendix?**
   - What we know: the script is explicitly operator-only and recovery-specific.
   - What's unclear: how prominently the final acceptance packet should surface it.
   - Recommendation: keep it visible, but separate from the normal rollout steps.

## Validation Architecture

### Test Framework
| Property | Value |
|---|---|
| Framework | Flutter `flutter_test` plus Astro `astro check` / `astro build` |
| Config file | `pubspec.yaml`, `package.json` |
| Quick run command | `flutter test test/phase50/kiosk_device_model_test.dart test/phase51/admin_session_claims_test.dart test/phase51/sql_role_guard_contract_test.dart test/phase52/portal_recovery_contract_test.dart && npm run check` |
| Full suite command | `flutter test && npm run build` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| SECOPS-01 | One additive rollout checklist covers the SQL, Astro, and Flutter hardening changes safely for live production | integration + smoke + manual rollout gate | `flutter test test/phase50/kiosk_device_model_test.dart test/phase51/admin_session_claims_test.dart test/phase51/sql_role_guard_contract_test.dart test/phase52/portal_recovery_contract_test.dart && npm run check && npm run build` | ✅ |

### Sampling Rate
- **Per task commit:** `flutter test test/phase50/kiosk_device_model_test.dart test/phase51/admin_session_claims_test.dart test/phase51/sql_role_guard_contract_test.dart test/phase52/portal_recovery_contract_test.dart`
- **Per wave merge:** `flutter test && npm run check`
- **Phase gate:** `flutter test && npm run build` plus explicit Supabase rollout confirmation before closeout

### Wave 0 Gaps
- [ ] No dedicated Phase 53 acceptance file exists yet; if the planner wants a formal handoff artifact, add a compact checklist or validation packet alongside this research.
- [ ] No automated command can prove the production Supabase project has applied the additive SQL; operator evidence still needs to come from the live rollout step.

## Sources

### Primary (HIGH confidence)
- `.planning/ROADMAP.md` - Phase 53 scope, success criteria, and requirement mapping
- `.planning/REQUIREMENTS.md` - `SECOPS-01` requirement text and milestone boundaries
- `.planning/STATE.md` - current status, phase position, and rollout notes
- `.planning/RETROSPECTIVE.md` - process lessons from prior milestones, especially rollout evidence and acceptance framing
- `.planning/phases/50-kiosk-device-boundary-hardening/50-01-SUMMARY.md` - Phase 50 rollout order and additive SQL pattern
- `.planning/phases/50-kiosk-device-boundary-hardening/50-USER-SETUP.md` - operator rollout expectations for the kiosk migration
- `.planning/phases/51-admin-session-trust-hardening/51-01-SUMMARY.md` - additive SQL hardening plus contract-test pattern
- `.planning/phases/52-portal-surface-minimization/52-01-SUMMARY.md` - middleware-first portal boundary and request-local trust model
- `.planning/phases/52-portal-surface-minimization/52-USER-SETUP.md` - rollout and recovery distinction for the portal hardening
- `sql/phase_50_kiosk_boundary_hardening_20260325.sql` - additive kiosk device boundary migration
- `sql/phase_51_admin_session_trust_20260325.sql` - additive admin session trust migration
- `sql/phase_52_portal_search_minimization_20260325.sql` - portal chooser minimization migration
- `sql/repair_employee_portal_accounts_20260325.sql` - conditional recovery script
- `test/phase50/kiosk_device_model_test.dart` - kiosk UUID fallback and malformed timestamp safety
- `test/phase51/admin_session_claims_test.dart` - app metadata trust boundary
- `test/phase51/sql_role_guard_contract_test.dart` - SQL role guard contract
- `test/phase52/portal_recovery_contract_test.dart` - portal recovery contract
- `docs/android-release-runbook.md` - operator sequencing template
- `package.json` - Astro verification commands
- `pubspec.yaml` - Flutter verification commands and current app stack

### Secondary (MEDIUM confidence)
- None required; this research stays inside the repository artifacts supplied for the phase.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - directly supported by the repo's package files, runbook, and phase summaries
- Architecture: HIGH - the rollout and acceptance pattern is explicit in the phase summaries and SQL scripts
- Pitfalls: HIGH - the recovery script, acceptance boundary, and rollout order are all directly stated in the source files

**Research date:** 2026-03-25  
**Valid until:** 2026-04-01
