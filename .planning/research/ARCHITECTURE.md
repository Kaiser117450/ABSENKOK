# v8.1 Research - Architecture

**Milestone:** v8.1 Reporting Recovery & Schedule Gap Notifications  
**Research date:** 2026-03-31

## Current architecture reading

The reporting chain is already mostly correct in shape:

1. recap rows are produced as typed `AttendancePolicyRecapDay` data
2. rows are converted into a shared payroll matrix dataset
3. matrix semantics determine labels, tags, colors, and summary counts
4. spreadsheet and PDF export read the same matrix contract

The important compatibility behavior already exists in
`LegacyPayrollRecapFallbackService`:

- missing strict rows are filled from raw attendance logs
- required hours still come from employee contract
- no fake lateness or fake absence is introduced
- incomplete missing-pulang days remain honest
- overnight grouping still works for `TWENTY_FOUR_HOUR` outlets

## Where the corrective milestone should integrate

### 1. Strict row precedence must remain intact

Fallback rows should continue to exist only when strict recap does not produce a
row for that employee/day. This is already the safest rule in the current
fallback service and should remain a hard boundary.

### 2. Schedule completeness must be split from recap semantics

The user's complaint points to a boundary problem:

- "schedule completeness" is an operational follow-up problem
- "report semantics" is a payroll evidence problem

Those two concerns should not share the same failure mode.

v8.1 should introduce or clarify a separate schedule-gap audit/read model that:

- detects empty schedule dates
- groups them by outlet and employee
- feeds a notice surface for kepala gerai
- does **not** mutate recap primary status or export colors directly

### 3. Admin recap must consume one corrected final dataset

Recommended data order:

1. fetch strict recap rows
2. synthesize eligible legacy fallback rows for uncovered days only
3. merge them into one final recap dataset
4. derive matrix rows from that merged dataset
5. let spreadsheet/PDF reuse the same result

### 4. Notification surface should stay lightweight

`SchedulePolicySummaryCard` already proves the scheduler uses lightweight,
dismissible guidance. A schedule-gap notice should follow that operational
pattern rather than blocking report rendering.

## Build order recommendation

1. Lock the corrected report semantics and fallback boundaries.
2. Add schedule-gap audit/read model and outlet-scoped notification contract.
3. Wire admin recap and pending surfaces to the corrected merged dataset.
4. Re-run spreadsheet/PDF parity from the same merged dataset.

## Components most likely to change

- recap orchestration service or admin report data loader
- `LegacyPayrollRecapFallbackService` only if its current merge boundary is too
  narrow for the desired continuity
- schedule-gap notice/read model
- admin report surface and/or scheduler notice surface
- regression tests for export parity and mixed strict/fallback scenarios

## Components that should remain stable

- `PayrollMatrixSemantics` tag/color vocabulary
- spreadsheet export field policy
- PDF export field policy
- contract-aware required-hours defaults
- overnight logical-day grouping contract

## Conclusion

v8.1 should fix orchestration boundaries, not invent a second reporting system.
