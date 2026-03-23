---
phase: 44-portal-exception-states-hardening
plan: "03"
subsystem: portal-web
tags: [portal, attendance-recap, exception-states, loading-feedback]
dependency_graph:
  requires: [44-01, 43-03]
  provides: [ATTN-05, PORT-04]
  affects:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/attendance.astro
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceSummary.astro
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/layouts/PortalLayout.astro
tech_stack:
  added: []
  patterns:
    - countFollowUpDays from attendance-recap-presentation helper drives summary follow-up framing without a second query
    - Same-origin portal anchor click listener triggers shell progress bar for SSR navigation
key_files:
  created: []
  modified:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/attendance.astro
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceSummary.astro
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/layouts/PortalLayout.astro
decisions:
  - recap empty state (ok:true + zero days) handled at page level with PortalStatePanel, not pushed into history component
  - followUpCount derived from countFollowUpDays(recap.days) — no second query
  - shell click listener skips modified clicks, _blank targets, external origins; logout path preserved
metrics:
  duration_minutes: 4
  completed_date: "2026-03-23"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 3
---

# Phase 44 Plan 03: Recap Exception States and Shell Loading Hardening Summary

Explicit empty/error states for recap unavailability plus follow-up workload framing from the existing recap dataset, with shell progress bar extended to internal portal navigation.

## What Was Built

### Task 1: Harden recap page branching and summary framing

- `attendance.astro` now branches `ok:true` into two exclusive paths: zero-days empty state (renders `PortalStatePanel variant="empty"`) and non-zero days ready state with summary and history.
- `countFollowUpDays` from `attendance-recap-presentation.ts` is called on the existing `recap.days` array — no second fetch.
- `followUpCount` is passed as a new optional prop to `PortalAttendanceSummary`.
- `PortalAttendanceSummary.astro` accepts `followUpCount?: number` and renders an amber banner below the summary chips when the count is positive: "N hari perlu ditindaklanjuti".
- `no_mapping` and `rpc_error` states remain explicit and isolated — ready-state content cannot leak into those branches.

### Task 2: Extend shell loading feedback to recap navigation and retry actions

- `PortalLayout.astro` script refactored to extract a shared `showProgress()` helper used by both the logout form path and the new navigation path.
- A `document.addEventListener('click', ...)` handler triggers `showProgress()` for same-origin `/portal` anchor clicks that would cause a full SSR page load.
- Modified clicks (Ctrl, Cmd, Shift, Alt), middle-button clicks, `_blank` targets, hash links, and external origins are all excluded.
- Logout pending treatment (button disable + "Keluar…" text) is fully preserved.

## Verification

- Task 1: `Select-String` match count of 14 across attendance.astro and PortalAttendanceSummary.astro confirms `followUpCount`, `PortalStatePanel`, and `days.length === 0` are all present.
- Task 2: `npm run build` completed with no errors.

## Deviations from Plan

None — plan executed exactly as written.

## Key Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 44-03-01 | Empty state at page level (not inside history component) | Scope guard: do not push empty/error responsibility down into history component |
| 44-03-02 | followUpCount derived via countFollowUpDays from existing recap.days | Scope guard: no second recap fetch |
| 44-03-03 | Click listener scoped to /portal same-origin paths only | Avoids interfering with admin routes, external links, or non-navigation clicks |

## Self-Check: PASSED

- SUMMARY.md: FOUND at .planning/phases/44-portal-exception-states-hardening/44-03-SUMMARY.md
- Task 1 commit 7fb66b2: FOUND
- Task 2 commit a20719e: FOUND
