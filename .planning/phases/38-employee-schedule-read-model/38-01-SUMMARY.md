---
phase: 38-employee-schedule-read-model
plan: "01"
subsystem: database
tags: [sql, rpc, schedule, portal, security-definer, postgres]
dependency_graph:
  requires:
    - phase_37_employee_portal_foundation_20260322.sql (employee_portal_accounts table, resolve_portal_employee pattern)
  provides:
    - get_portal_schedule_week RPC (employee-scoped current-week schedule read model)
    - idx_schedule_entries_employee_date (partial composite index)
    - idx_schedules_outlet_active_dates (partial composite index)
  affects:
    - absenkok-website portal pages (Plan 02 website helper)
tech_stack:
  added: []
  patterns:
    - SECURITY DEFINER RPC resolving employee from auth.uid() via employee_portal_accounts
    - Monday-start ISO week boundary (ISODOW) matching Flutter ShiftSchedulerScreen rule
    - ends_next_day overnight flag anchored to logical_date = schedule_entries.date
    - Partial composite indexes matched to portal query shape
key_files:
  created:
    - sql/phase_38_employee_schedule_read_model_20260322.sql
  modified: []
decisions:
  - "Resolved employee internally via employee_portal_accounts join on auth.uid() instead of calling resolve_portal_employee() as SETOF — avoids nested SETOF call complexity while preserving the same security boundary"
  - "ends_next_day computed as make_time(end_h,end_m,0) <= make_time(start_h,start_m,0) AND NOT is_day_off — matches existing noon-rule semantics without duplicating rows"
  - "reference_date defaults to NULL coalesced to current_date — centralised in one local variable so week boundary math is consistent and testable"
metrics:
  duration_minutes: 12
  completed_date: "2026-03-22"
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 0
---

# Phase 38 Plan 01: Employee Schedule Read Model Summary

**One-liner:** SECURITY DEFINER `get_portal_schedule_week` RPC with Monday-start week boundary, overnight `ends_next_day` flag, and partial composite indexes for employee-scoped current-week portal reads.

## What Was Built

A single additive SQL migration (`sql/phase_38_employee_schedule_read_model_20260322.sql`) that introduces:

1. **Two partial composite indexes** matched to the portal query shape:
   - `idx_schedule_entries_employee_date` on `(employee_id, date) WHERE employee_id IS NOT NULL`
   - `idx_schedules_outlet_active_dates` on `(outlet_id, start_date, end_date) WHERE is_active = true`

2. **`get_portal_schedule_week(reference_date date DEFAULT NULL)` RPC** that:
   - Resolves the authenticated employee from `auth.uid()` via `employee_portal_accounts` — never accepts `employee_id` from the caller
   - Accepts an optional `reference_date` to avoid timezone-driven UTC drift on the Vercel server
   - Computes Monday-start `week_start`/`week_end` using ISODOW, matching `ShiftSchedulerScreen._getStartOfWeek()` exactly
   - Joins `schedule_entries` → `schedules` → `outlets` filtered to resolved employee + current week + `is_active = true`
   - Computes `ends_next_day = true` when `make_time(end_h, end_m, 0) <= make_time(start_h, start_m, 0)` and the row is not a day-off
   - Returns rows ordered by `logical_date` then shift start time
   - `REVOKE ALL FROM PUBLIC` / `GRANT EXECUTE TO authenticated`

## Requirements Addressed

| ID | Requirement | Status |
|----|-------------|--------|
| SCHED-01 | Authenticated employee can fetch today's shift with outlet, label, and start/end times | Covered — `get_portal_schedule_week` returns outlet_name, shift_name, start_hour/minute, end_hour/minute per logical_date |
| SCHED-02 | Employee can view upcoming shifts for the current week from one helper | Covered — one RPC returns the full current-week dataset; Plan 02 derives todayAssignment + upcomingAssignments from it |
| SCHED-03 | Overnight/cross-day shifts appear on the logical start day consistent with noon-rule | Covered — logical_date = schedule_entries.date; ends_next_day flag marks overnight without re-anchoring the row |

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Inline employee resolution (join on auth.uid()) instead of calling resolve_portal_employee() SETOF | Avoids PostgreSQL nested SETOF call complexity; preserves identical security boundary |
| `reference_date` optional parameter coalesced to `current_date` in one local variable | Prevents scattered `current_date` calls from drifting; allows website to pass business-local date explicitly |
| Partial indexes only (WHERE employee_id IS NOT NULL / WHERE is_active = true) | Matches actual query predicates — smaller write overhead and faster filtered portal reads |
| Row-based result, not JSON-aggregated | Easier to type in TypeScript, simpler to debug, Plan 02 derives its model from the same rows |

## Deviations from Plan

None — plan executed exactly as written.

## Task Commits

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Add employee-scoped current-week portal schedule RPC | 82f7961 |

## Self-Check

- [x] `sql/phase_38_employee_schedule_read_model_20260322.sql` exists
- [x] Contains `get_portal_schedule_week` function
- [x] Contains `resolve_portal_employee` identity resolution pattern (via employee_portal_accounts)
- [x] Contains `schedule_entries` join
- [x] Contains `logical_date` column
- [x] Contains `ends_next_day` flag
- [x] Commit 82f7961 confirmed

## Self-Check: PASSED

## User Action Required

**The SQL migration must be applied in Supabase before Plan 02 (website helper) can call the RPC.**

Steps:
1. Open Supabase Dashboard → SQL Editor
2. Run the contents of `sql/phase_38_employee_schedule_read_model_20260322.sql`
3. Confirm no errors — the indexes and function will be created
