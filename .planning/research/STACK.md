# v8.1 Research - Stack

**Milestone:** v8.1 Reporting Recovery & Schedule Gap Notifications  
**Research date:** 2026-03-31  
**Scope:** corrective reporting milestone, not a net-new platform expansion

## Recommendation

No new package or platform dependency is required for v8.1.

The existing reporting stack already contains the pieces needed to recover the
desired behavior:

- `LegacyPayrollRecapFallbackService` already synthesizes contract-aware recap
  rows when schedule data is missing.
- `PayrollMatrixSemantics` already treats `hadir_tanpa_jadwal` as an
  informational state and keeps red/yellow counts focused on actual payroll
  penalties.
- `PayrollSpreadsheetExportService` and
  `PayrollPdfMatrixExportService` already consume one shared matrix dataset and
  intentionally exclude technical scan fields.
- `SchedulePolicySummaryCard` already shows that schedule-policy guidance is
  expected to be non-blocking UI, not a hard workflow gate.

## Existing stack to reuse

| Area | Existing implementation | Why it matters for v8.1 |
|------|-------------------------|--------------------------|
| Legacy compatibility | `lib/services/legacy_payroll_recap_fallback_service.dart` | Preserves historical days without fabricating late/absence penalties |
| Matrix assembly | `lib/services/payroll_matrix_builder.dart` | Gives one employee/date dataset for admin and export |
| Recap semantics | `lib/services/payroll_matrix_semantics.dart` | Separates informational cells from red/yellow payroll flags |
| Spreadsheet export | `lib/services/payroll_spreadsheet_export_service.dart` | Keeps workbook output compact and salary-facing |
| Payroll PDF | `lib/services/payroll_pdf_matrix_export_service.dart` | Keeps PDF in parity with the same matrix semantics |
| Schedule notice UI | `lib/screens/admin/widgets/schedule_policy_summary_card.dart` | Good pattern for lightweight schedule warnings or follow-up notices |

## Suggested internal additions

These are code-level additions inside the existing app, not new stack:

1. A schedule-completeness audit helper that computes empty schedule dates per
   outlet/employee range without mutating recap results.
2. A small orchestration layer that decides when admin recap should surface
   fallback continuity versus strict schedule-driven evaluation.
3. Focused regression fixtures for mixed datasets:
   strict rows + fallback rows + export parity + schedule-gap notifications.

## What not to add

- No new export format.
- No external notification channel for this milestone.
- No forced production backfill job as a prerequisite to correct reports.
- No second reporting dataset that diverges from spreadsheet/PDF parity.

## Evidence from current code

- Phase 58.1 explicitly scoped legacy fallback as a compatibility patch for
  outlets that still have attendance logs but no `schedule_entries`.
- The v8.0 audit marked "legacy no-schedule compatibility flow" as passed.
- Current fallback tests confirm contract-aware required hours, overnight-safe
  grouping, and honest incomplete rows without fake late/absence signals.

## Conclusion

v8.1 should stay on the current stack and fix orchestration/semantics, not
expand infrastructure.
