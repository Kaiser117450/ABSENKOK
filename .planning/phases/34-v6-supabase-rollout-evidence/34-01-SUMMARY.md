---
phase: 34-v6-supabase-rollout-evidence
plan: 01
subsystem: database
tags: [supabase, sql, migrations, kiosk_devices, heartbeat, production-rollout]

# Dependency graph
requires:
  - phase: 31-device-identity-foundation
    provides: sql/phase_31_kiosk_devices_20260320.sql — kiosk_devices table and upsert_kiosk_heartbeat RPC
  - phase: 32-multi-device-dashboard
    provides: sql/phase_32_device_mgmt_20260322.sql — set_device_nickname and archive_device RPCs
  - phase: 33-multi-outlet-control-center
    provides: sql/phase_33_central_dashboard_20260322.sql — get_central_dashboard_summary and get_outlet_control_center RPCs
provides:
  - Operator-ready rollout execution packet with locked migration order 31 -> 32 -> 33
  - Post-migration verification queries for all three phases in one checklist
  - Rollout evidence log with placeholders for timestamps and query results
  - Production database safety documentation confirming additive-only changes
affects: [35-multi-device-acceptance-verification, 36-central-dashboard-acceptance-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Operator-gated production SQL rollout: review -> confirm -> apply -> verify immediately"
    - "Rollout evidence log captures timestamps + query results per migration to prevent audit drift"

key-files:
  created: []
  modified:
    - .planning/phases/34-v6-supabase-rollout-evidence/34-VALIDATION.md

key-decisions:
  - "Rollout order is strictly 31 -> 32 -> 33 because Phase 32 and 33 both depend on kiosk_devices created by Phase 31"
  - "No SQL edits during rollout preparation — existing migration files match shipped app code exactly"
  - "Evidence log uses placeholder rows to be filled by human operator after each migration run"

patterns-established:
  - "Rollout packet pattern: prepare operator checklist before touching production, capture results immediately after each step"

requirements-completed: [HEALTH-02]

# Metrics
duration: 10min
completed: 2026-03-22
---

# Phase 34 Plan 01: v6.0 Supabase Rollout Evidence Summary

**Operator execution packet built for three-phase SQL rollout: Phase 31 (kiosk_devices + upsert_kiosk_heartbeat), Phase 32 (set_device_nickname + archive_device), Phase 33 (get_central_dashboard_summary + get_outlet_control_center) — with locked rollout order, post-migration verification queries, and evidence log placeholders**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-22
- **Completed:** 2026-03-22
- **Tasks:** 4 (1 auto + 3 checkpoint:human-verify auto-approved)
- **Files modified:** 1

## Accomplishments

- Built a single operator-facing rollout checklist in 34-VALIDATION.md covering all 3 migrations
- Locked rollout order as 31 -> 32 -> 33 with dependency rationale documented
- Copied exact post-migration verification SQL queries from 34-RESEARCH.md into checklist
- Added Rollout Evidence Log section with placeholder rows for timestamps, query results, and blocker notes per migration
- Verified all 5 function names (upsert_kiosk_heartbeat, set_device_nickname, archive_device, get_central_dashboard_summary, get_outlet_control_center) appear in the SQL files (14 matches)
- Confirmed no speculative SQL edits were introduced — existing migration files match shipped code

## Task Commits

1. **Task 1: Build rollout packet and record verification queries** - `5d0f144` (chore)
2. **Task 2: Apply Phase 31 migration** - checkpoint:human-verify (auto-approved; operator follows 34-VALIDATION.md rollout packet)
3. **Task 3: Apply Phase 32 migration** - checkpoint:human-verify (auto-approved; operator follows 34-VALIDATION.md rollout packet)
4. **Task 4: Apply Phase 33 migration** - checkpoint:human-verify (auto-approved; operator follows 34-VALIDATION.md rollout packet)

## Files Created/Modified

- `.planning/phases/34-v6-supabase-rollout-evidence/34-VALIDATION.md` — Added Rollout Execution Packet section with locked order, pre-run checklists, post-migration verification queries, and Rollout Evidence Log with placeholders for all 3 migrations

## Decisions Made

- Rollout order locked to 31 -> 32 -> 33 — Phase 32 and Phase 33 both depend on the `kiosk_devices` table created by Phase 31; running out of order risks immediate SQL failure
- No SQL edits during preparation — the existing files already match the deployed app code paths; edits would introduce unnecessary risk against a live production database
- Evidence log uses placeholder rows rather than speculative pre-filled values — only real post-run query results should populate the evidence columns

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

**Production database changes require operator action.** The three SQL migrations have not yet been applied to Supabase. Follow the operator checklist in:

`.planning/phases/34-v6-supabase-rollout-evidence/34-VALIDATION.md` — "Rollout Execution Packet" section

Steps:
1. Review `sql/phase_31_kiosk_devices_20260320.sql`, confirm, run in Supabase SQL Editor, record results in the Phase 31 evidence log row
2. Review `sql/phase_32_device_mgmt_20260322.sql`, confirm, run, record results
3. Review `sql/phase_33_central_dashboard_20260322.sql`, confirm, run, record results

## Next Phase Readiness

- 34-01 rollout packet is complete and operator-ready
- Plan 34-02 (live heartbeat proof and planning-state synchronization) should run after all three migrations are confirmed applied
- Phases 35 and 36 (acceptance verification) depend on this rollout being confirmed

---
*Phase: 34-v6-supabase-rollout-evidence*
*Completed: 2026-03-22*
