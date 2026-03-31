# v8.1 Research - Features

**Milestone:** v8.1 Reporting Recovery & Schedule Gap Notifications  
**Research date:** 2026-03-31

## Product reading

This milestone is a corrective pass on v8.0 reporting behavior.

The user does **not** want to abandon strict reporting entirely. They want:

- legacy/no-schedule data to stay usable in Rekap Harian and pending views
- spreadsheet/PDF to remain the most important outputs
- strict contract-aware rules to keep working for break-first and excessive
  break cases
- empty schedule days to become follow-up notices for kepala gerai instead of
  breaking recap behavior

## Table stakes

### Recap continuity

- Historical days without `schedule_entries` still produce readable recap rows.
- Existing outlets do not need a full schedule backfill before reports become
  trustworthy again.
- Pending and recap surfaces do not regress into blank or misleading states
  just because schedule data is incomplete.

### Strict rule preservation

- Full-time and part-time contract thresholds remain authoritative when the
  data supports strict evaluation.
- Break-first and excessive-break logic remain active and visible.
- Overnight and 24-hour outlet handling must remain intact.

### Export parity

- Spreadsheet export stays aligned with the corrected recap dataset.
- Payroll PDF stays aligned with the same corrected recap dataset.
- Export outputs remain compact and salary-facing, with no technical metadata.

## Differentiators for this milestone

### Schedule-gap follow-up

- Kepala gerai should see which dates/employees still need schedule filling.
- The follow-up should be visible enough to act on, but non-blocking.
- The notice should be outlet-scoped and operational, not a punitive payroll
  signal.

### Honest compatibility mode

- When the system falls back because schedule rows are missing, that condition
  should be explicit.
- Compatibility should not silently downgrade truly strict days that already
  have enough data for real evaluation.

## Anti-features

- Turning off strict reporting wholesale
- Requiring schedule backfill before reports work again
- Using schedule-gap follow-up as a payroll penalty
- Reintroducing old CSV or new technical fields into payroll exports
- Expanding into salary calculation, payslips, or approval workflow

## Feature categories to carry into requirements

| Category | Why it belongs in v8.1 |
|----------|-------------------------|
| Recap recovery | User explicitly wants Rekap Harian back to the trusted behavior |
| Strict rule retention | User explicitly wants break-first and excess-break rules to remain |
| Export parity | User said spreadsheet and PDF are the main priority |
| Schedule-gap notification | User wants missing schedules surfaced as notices only |

## Conclusion

v8.1 is successful when legacy data is readable again, exports stay canonical,
and strict payroll signals survive only where they should.
