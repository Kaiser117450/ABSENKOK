# Phase 60: Rollout & Payroll Acceptance - Research

**Researched:** 2026-03-31
**Domain:** operator-safe payroll rollout, cross-surface acceptance evidence, and final admin gating on top of the shipped v8 strict recap stack
**Confidence:** MEDIUM-HIGH

## Summary

Phase 60 should not invent new payroll rules. Phases 54-59 already shipped the contract-aware employee metadata, schedule policy, server-authoritative WITA timing, strict recap engine, payroll matrix/spreadsheet export, and portal/PDF parity. The remaining gap is operational acceptance: give operators one live-safe checklist, make the admin shell expose a rollout-readiness layer, and package evidence that proves admin, spreadsheet, PDF, and portal agree before payroll decisions rely on the new outputs.

No Phase 60 `CONTEXT.md` exists in this workspace. This research therefore relies on `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, the approved `.planning/phases/60-rollout-payroll-acceptance/60-UI-SPEC.md`, the Phase 59 parity artifacts, `docs/android-release-runbook.md`, and the earlier Phase 53 security-rollout patterns. Those files are enough to plan this phase without reopening product discovery.

Primary recommendation: plan this phase as three execution plans across two waves:

1. docs and fixture contract for rollout + acceptance,
2. Flutter acceptance domain services plus a validation bundle exporter,
3. admin recap-shell integration for the rollout acceptance surface and final regression coverage.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| `OPS-01` | Operators have one live-safe rollout and acceptance checklist that verifies contract defaults, WITA server-time, 24-hour outlet overnight cases, break-first scenarios, and export parity before the strict rules are used for payroll decisions. | Existing v8 artifacts already define the strict parity contract. Phase 60 only needs to operationalize those artifacts into one checklist, one acceptance fixture pack, one admin review surface, and one shareable evidence bundle. |
</phase_requirements>

## Existing Code Findings

### 1. The admin recap shell already has the right payroll dataset
- `lib/screens/admin/admin_reports_screen.dart` already builds the payroll recap dataset and exposes recap-tab export actions.
- `lib/services/attendance_policy_recap_service.dart`, `lib/services/payroll_matrix_builder.dart`, and `lib/models/payroll_matrix_row.dart` already provide the employee/date matrix foundation.
- `lib/services/legacy_payroll_recap_fallback_service.dart` already preserves compatibility behavior for outlets still missing `schedule_entries`.

**Implication:** Phase 60 should layer acceptance on top of the existing recap shell instead of creating a second reporting screen or a separate rollout app.

### 2. Payroll semantics already live in one shared source of truth
- `lib/services/payroll_matrix_semantics.dart` already owns the primary labels, short tags, severity palette, and summary counts.
- `lib/services/payroll_spreadsheet_export_service.dart` already defines the salary-facing field boundary.
- `lib/services/payroll_pdf_matrix_export_service.dart` already mirrors the matrix contract for PDF export.

**Implication:** readiness checks should compare outputs derived from those existing services rather than introducing a new parity taxonomy.

### 3. Phase 59 already locked the key parity baselines
- `.planning/phases/59-pdf-portal-parity/59-PARITY-FIXTURES.md` already documents the overnight 24-hour strict row and the legacy fallback row.
- `.planning/phases/59-pdf-portal-parity/59-VALIDATION.md` already calls out the same logical-workday parity proof as the essential verification pattern.
- The approved Phase 60 UI contract explicitly keeps portal, spreadsheet, and PDF as read-only evidence surfaces.

**Implication:** Phase 60 should extend the fixture pack to the full seven required rollout scenarios, not rediscover parity rules from scratch.

### 4. Repo precedents already exist for rollout-only closeout phases
- Phase 49 created a local Android release runbook that turned an existing implementation into a repeatable operator flow.
- Phase 53 created a canonical rollout checklist plus a phase-local `USER-SETUP` note for live security rollout and acceptance.
- Both phases kept live database actions explicit, additive-only, and approval-gated.

**Implication:** Phase 60 should reuse the same doc pattern: one canonical rollout checklist under `docs/` plus one phase-local setup/evidence note in `.planning/phases/60-rollout-payroll-acceptance/`.

### 5. The acceptance domain does not exist yet
- There is no dedicated model/service that represents rollout-readiness, required scenarios, evidence-column status, or a validation bundle.
- The current recap shell can export spreadsheet/PDF, but it cannot answer: "Are all required scenarios passed?" or "Which artifact diverged?"

**Implication:** the safest implementation path is to add an in-memory acceptance domain service that consumes existing dataset outputs and operator-marked evidence state without introducing database persistence.

### 6. Phase 60 should avoid new production dependencies
- The requirement is operational acceptance, not new reporting logic.
- The system is live, and `STATE.md` keeps the additive-only / explicit-confirmation database rule active.
- The UI-SPEC says the only destructive interaction is an explicit database confirmation dialog.

**Implication:** planning should default to docs and Flutter-only changes. New SQL, new portal RPCs, or server persistence are unnecessary unless execution discovers a blocker.

## Standard Stack

### Core
| Library / Tool | Purpose | Why Standard |
|---|---|---|
| Flutter app shell (`admin_reports_screen.dart`) | Host the rollout acceptance surface in the existing admin reporting flow | The approved UI-SPEC explicitly places Phase 60 inside the current admin recap shell. |
| `PayrollMatrixDataset` + `PayrollMatrixSemantics` | Canonical parity comparison inputs | These already encode labels, tags, severity, and compatibility rows. |
| `share_plus` + existing file/export services | Share the final validation artifact | The repo already uses share-based export flows; Phase 60 can extend that pattern without new packages. |
| Repo-tracked planning docs under `.planning/phases/60-rollout-payroll-acceptance/` | Operator setup, fixtures, and acceptance evidence contract | Prior rollout phases already use this pattern successfully. |

### Supporting
| Library / Tool | Purpose | When to Use |
|---|---|---|
| `docs/android-release-runbook.md` | Template for exact operator sequencing and acceptance evidence wording | Use when writing the rollout checklist style and proof expectations. |
| `docs/security-hardening-rollout.md` | Template for additive-only, approval-gated live rollout docs | Use when writing the payroll rollout checklist. |
| `flutter_test` | Service and widget regression coverage | Use for the acceptance domain and admin rollout UI. |
| `59-PARITY-FIXTURES.md` | Existing parity fixture baseline | Use as the seed for Phase 60's seven-scenario fixture pack. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|---|---|---|
| One admin rollout acceptance layer | A standalone acceptance screen or external checklist | Faster to draft, but it splits the operator workflow away from the actual recap surface they must approve. |
| In-memory acceptance domain + bundle export | Database-backed rollout approvals | Database persistence is heavier, unnecessary for this requirement, and risks turning rollout tooling into a production workflow system. |
| Docs + Flutter only | Additional portal or SQL changes | Those changes expand scope without solving the operator acceptance gap. |

## Architecture Patterns

### Pattern 1: Treat rollout acceptance as an overlay on shipped payroll outputs
**What:** reuse the existing recap dataset, spreadsheet export, PDF export, and portal evidence as the source inputs, then build a rollout-readiness overlay on top.

**Why:** this phase proves the shipped contract is safe for payroll; it should not create a second interpretation of the same data.

### Pattern 2: Lock the seven required scenarios in one fixture pack
**What:** create one phase-local fixture source that names the required scenarios:
- full-time
- part-time
- overtime
- 24-hour outlet
- normal outlet
- break-first
- no-show

Each scenario should lock the expected primary label, short tags, severity family, and required evidence columns.

**Why:** operators need one repeatable checklist, not seven improvised interpretations.

### Pattern 3: Separate docs/fixtures from code and UI
**What:** split execution into:
- docs and setup notes,
- acceptance domain services and bundle export,
- admin rollout UI and tests.

**Why:** this keeps the code write-set clean and makes the rollout docs available before the UI work starts.

### Pattern 4: Keep readiness state explainable
**What:** the acceptance service should always return:
- overall readiness status,
- passed / pending / blocked counts,
- per-scenario status,
- blocked parity rows,
- next-action copy.

**Why:** a disabled CTA with no explanation is not operationally useful.

### Pattern 5: Export one operator-ready evidence bundle
**What:** package the validation result into a shareable artifact that includes:
- outlet/date-range context,
- timestamp,
- seven scenario statuses,
- blocked mismatches,
- evidence links/labels for admin/spreadsheet/PDF/portal,
- additive-only reminder.

**Why:** Phase 60 closes a milestone. Operators need something they can review or hand off, not just transient UI state.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Rollout checklist | A free-form note or chat-only instructions | `docs/payroll-rollout-acceptance.md` plus a phase-local setup note | Operators need one tracked flow. |
| Parity verdicts | New hard-coded label mappings | `PayrollMatrixSemantics` and existing export outputs | The parity contract already exists. |
| Acceptance persistence | New Supabase tables or approval RPCs | In-memory state plus a validation bundle export | The requirement is evidence and gating, not multi-user workflow storage. |
| UI verification | Visual-only acceptance with no tests | Widget/service tests plus manual parity checks | The milestone is verification-heavy and needs repeatable checks. |

## Common Pitfalls

### Pitfall 1: Reopening payroll logic in the acceptance phase
**What goes wrong:** execution starts changing strict recap rules, spreadsheet semantics, or portal parity logic again.
**How to avoid:** treat Phase 60 as an overlay and checklist phase unless an actual parity bug is discovered.

### Pitfall 2: Making the checklist too generic
**What goes wrong:** the docs say "check parity" without naming the scenarios, artifacts, or blockers.
**How to avoid:** lock the seven scenarios and the four artifact columns in the fixture pack and UI.

### Pitfall 3: Letting the primary CTA approve incomplete evidence
**What goes wrong:** operators can mark payroll ready while a scenario is still pending or a parity row is blocked.
**How to avoid:** gate `Tandai Siap Payroll` on zero blocked rows and all required scenarios passed.

### Pitfall 4: Exporting low-signal technical data in the validation bundle
**What goes wrong:** the validation artifact starts carrying GPS or raw scan/debug metadata that payroll reviewers do not need.
**How to avoid:** inherit the salary-facing field exclusions from the existing spreadsheet/PDF contract.

## Recommended Project Structure

```text
docs/
└── payroll-rollout-acceptance.md

.planning/phases/60-rollout-payroll-acceptance/
├── 60-RESEARCH.md
├── 60-VALIDATION.md
├── 60-USER-SETUP.md
└── 60-ACCEPTANCE-FIXTURES.md

lib/models/
└── payroll_rollout_acceptance.dart

lib/services/
├── payroll_rollout_acceptance_service.dart
└── payroll_validation_bundle_service.dart

lib/screens/admin/widgets/
└── payroll_rollout_acceptance_panel.dart

test/services/
├── payroll_rollout_acceptance_service_test.dart
└── payroll_validation_bundle_service_test.dart

test/screens/admin/
└── admin_reports_payroll_rollout_test.dart
```

## Validation Architecture

### Test Framework
| Property | Value |
|---|---|
| Framework | Flutter `flutter_test` plus targeted PowerShell docs assertions |
| Scope | unit tests for readiness logic and bundle export, widget tests for recap-shell rollout UI, manual parity comparison for real artifacts |
| Why | the phase is mostly docs + Flutter logic; no new website or SQL runtime is required by the recommended path |

### Proposed Commands
```powershell
# Docs / fixture assertions
powershell -Command "Select-String -Path 'docs/payroll-rollout-acceptance.md','.planning/phases/60-rollout-payroll-acceptance/60-USER-SETUP.md','.planning/phases/60-rollout-payroll-acceptance/60-ACCEPTANCE-FIXTURES.md' -Pattern 'Tandai Siap Payroll','Portal','Spreadsheet','PDF','Break-first','No-show' | Measure-Object"

# Targeted phase tests
C:\flutter\bin\flutter.bat test `
  test/services/payroll_rollout_acceptance_service_test.dart `
  test/services/payroll_validation_bundle_service_test.dart `
  test/screens/admin/admin_reports_payroll_rollout_test.dart `
  test/screens/admin/admin_reports_payroll_matrix_test.dart

# Full app suite before verify-work
C:\flutter\bin\flutter.bat test
```

### Manual-Only Checks
- Compare one logical workday across admin, spreadsheet, PDF, and portal and confirm the primary label, short tags, and severity family all match.
- Confirm the readiness banner and the additive-only reminder are visible without scrolling past the first screenful on desktop.
- Confirm the destructive confirmation dialog appears only when the operator triggers a production-impacting action and not on initial load.

## Open Questions

1. **Should the acceptance panel keep draft state only in memory or also cache drafts locally?**
   - Recommendation: start with in-memory state plus exported evidence bundle. Add local draft caching only if execution finds the workflow too fragile.

2. **Should legacy no-schedule compatibility be a required eighth scenario?**
   - Recommendation: keep the seven required scenarios locked to the roadmap success criteria, but mention compatibility/fallback evidence in the docs and bundle when relevant.

3. **Does the final milestone closeout need a dedicated `60-ACCEPTANCE.md` artifact?**
   - Recommendation: yes, but create it during execution or verification when the real evidence exists, not during planning.
