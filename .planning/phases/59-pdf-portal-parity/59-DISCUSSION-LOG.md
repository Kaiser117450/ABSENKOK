# Phase 59: PDF & Portal Parity - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 59-pdf-portal-parity
**Areas discussed:** portal schedule framing, portal strict outcome presentation, portal progress detail, PDF recap layout, PDF signal density

---

## Portal Schedule Framing

| Option | Description | Selected |
|--------|-------------|----------|
| Band + target | Keep the shift band as the main label, show required hours prominently, and add worked/remaining progress as supporting text. | ✓ |
| Progress first | Make worked or remaining time the main emphasis, with band and required hours underneath. | |
| Target only | Show only band plus required hours on the card and keep progress off the main schedule surface. | |

**User's choice:** Band + target
**Notes:** Exact shift clock ranges should stop being the main portal schedule framing. The portal should stay band-first and contract-aware.

---

## Portal Strict Outcome Presentation

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit labels | Show the real outcome names like `Terlambat` or `Kurang jam`, but keep the helper copy calm and employee-facing. | ✓ |
| Softened wording | Translate strict outcomes into gentler portal phrases like `Perlu review` or `Jam belum cukup`. | |
| Minimal chips | Show only compact badges with very little explanatory copy. | |

**User's choice:** Explicit labels
**Notes:** Portal labels should stay in sync with the canonical strict engine, but the supporting copy should not feel admin-punitive.

---

## Portal Progress Detail

| Option | Description | Selected |
|--------|-------------|----------|
| Show both | Active days show worked plus remaining time; completed days show worked versus target so the employee can see the gap or surplus. | ✓ |
| Remaining only | Focus the portal on how much time is left and avoid repeating worked totals on the main card. | |
| Worked only | Show already-worked time and omit the remaining countdown framing. | |

**User's choice:** Show both
**Notes:** The portal should make progress understandable for both in-progress and completed logical workdays.

---

## PDF Recap Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Matrix + summary | Keep the spreadsheet-style employee/date matrix as the core report and add a compact summary page ahead of it. | ✓ |
| Matrix only | Match the spreadsheet as closely as possible with no extra summary framing. | |
| Daily rows | Use a row-per-employee-day table instead of a matrix, even though parity with the spreadsheet becomes looser. | |

**User's choice:** Matrix + summary
**Notes:** Spreadsheet parity stays primary, but the PDF may keep a compact summary page for payroll review context.

---

## PDF Signal Density

| Option | Description | Selected |
|--------|-------------|----------|
| Short tags | Use the same compact tags as the spreadsheet, with a legend so PDF and XLSX stay visually aligned. | ✓ |
| Full labels | Spell out `Terlambat`, `Kurang jam`, and similar labels directly inside cells. | |
| Primary only | Keep only the main status/color in each cell and drop secondary signal tags from the matrix. | |

**User's choice:** Short tags
**Notes:** PDF matrix cells should stay compact and match the spreadsheet contract rather than inventing a second signal vocabulary.

---

## the agent's Discretion

- Exact placement of portal progress copy and helper text.
- Exact PDF summary metrics, pagination, and legend placement.
- Exact implementation path for replacing the portal's older status-only recap and exact-clock schedule read models.

## Deferred Ideas

- Legacy per-scan audit PDF can remain separate from the payroll recap parity contract unless later planning explicitly expands scope.
