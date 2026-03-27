# Phase 55: User Setup Required

**Generated:** 2026-03-27
**Phase:** 55-schedule-policy-absence-rules
**Status:** Incomplete

Complete these items for the Phase 55 schedule-policy foundation to reach production. The agent automated all repo-side changes; the remaining step requires dashboard access and explicit approval.

## Environment Variables

None - this plan does not introduce new environment variables.

## Dashboard Configuration

- [ ] **Apply the Phase 55 schedule-policy migration after explicit approval**
  - Location: Supabase Dashboard -> SQL Editor -> New Query
  - Run: `sql/phase_55_schedule_policy_foundation_20260326.sql`
  - Notes: additive-only patch that backfills `band`, `required_work_minutes`, `late_cutoff_*`, and `break_first_deadline_*` into active `schedule_entries.shift_slot` JSON while preserving the legacy clock-range keys.

## Verification

After the SQL is applied:

```bash
powershell -Command "Select-String -Path 'sql/phase_55_schedule_policy_foundation_20260326.sql' -Pattern 'resolve_schedule_shift_band','required_work_minutes','late_cutoff_hour','break_first_deadline_hour','jsonb_set','employment_contract' | Measure-Object | Select-Object -ExpandProperty Count"
```

Expected results:
- The migration file still contains the helper functions and additive `jsonb_set` backfill logic.
- Production rollout should happen only after explicit user approval in line with the repo safety rule.
