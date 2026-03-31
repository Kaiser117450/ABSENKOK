# v8.1 Research Summary

**Milestone:** v8.1 Reporting Recovery & Schedule Gap Notifications  
**Research date:** 2026-03-31

## Key findings

### Stack additions

No new external stack is needed. The corrective work should stay inside the
existing recap, matrix, export, and admin-notice layers.

### Strongest existing foundation

The current codebase already contains the user-preferred compatibility idea:

- legacy fallback is contract-aware
- fallback rows do not fabricate late or absence
- overnight grouping survives no-schedule fallback
- spreadsheet and PDF already depend on one matrix dataset

### Where the regression likely lives

The weak boundary is between:

- report semantics for payroll evidence
- schedule completeness enforcement for operations

These should not be represented by the same failure state.

### Table stakes for v8.1

- restore usable Rekap Harian continuity for no-schedule legacy days
- keep break-first and excess-break strict rules active where they are valid
- keep spreadsheet and PDF as the canonical salary-facing outputs
- surface empty schedule dates as kepala gerai follow-up notices only

### Watch-outs

- do not let fallback overwrite valid strict rows
- do not convert schedule gaps into red/yellow payroll penalties
- do not break overnight 24-hour logic
- do not let admin recap drift away from spreadsheet/PDF semantics

## Recommended requirement categories

1. Recap Recovery
2. Strict Rule Retention
3. Export Parity
4. Schedule Gap Notifications

## Recommended implementation sequence

1. Correct recap/fallback merge semantics.
2. Add schedule-gap audit and notice behavior.
3. Reconfirm spreadsheet/PDF parity from the corrected dataset.
4. Lock regression fixtures for mixed strict + fallback scenarios.

## Bottom line

v8.1 should recover trusted report behavior without weakening the strict
contract-aware rules that still matter for payroll review.
