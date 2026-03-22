---
phase: 39
plan: "01"
subsystem: employee-portal-web
tags: [portal, schedule, ux, astro, typescript]
dependency_graph:
  requires: [38-02]
  provides: [portal-home-state-model, portal-schedule-components]
  affects: [portal-index-page]
tech_stack:
  added: []
  patterns: [discriminated-union-state-model, mobile-first-stacked-cards, astro-component-composition]
key_files:
  created:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/home.ts
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalStatePanel.astro
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalScheduleSection.astro
  modified: []
decisions:
  - "empty state from ok:true with zero weekAssignments is mapped in loadPortalHome (not loadPortalSchedule) to preserve employee identity in the greeting"
  - "PortalStatePanel uses role=status + aria-live=polite for accessible state transitions"
metrics:
  duration_minutes: 15
  completed_date: "2026-03-23"
  tasks_completed: 2
  files_created: 3
---

# Phase 39 Plan 01: Portal Home State Model and Mobile Schedule Components Summary

**One-liner:** Typed `PortalHomeState` discriminated union plus shared Astro components for all portal non-ready states and the mobile-first schedule surface.

## What Was Built

### Task 1 — Typed portal home state helper (`home.ts`)

`loadPortalHome(Astro)` wraps `loadPortalSchedule()` and maps the raw `PortalScheduleResult` into a page-ready `PortalHomeState` discriminated union:

| kind | trigger |
|------|---------|
| `ready` | `ok:true` with at least one week assignment |
| `empty` | `ok:true` with zero `weekAssignments` — preserves `employee` + `referenceDate` |
| `not-linked` | `ok:false, reason:'no_mapping'` |
| `error` | `ok:false, reason:'rpc_error'` |
| `unauthenticated` | `ok:false, reason:'unauthenticated'` |

`index.astro` will branch on `state.kind` only — no raw `ok`/`reason` inspection needed.

### Task 2 — Reusable portal Astro components

**`PortalStatePanel.astro`**
- Supports `loading | empty | not-linked | error` variants
- Consistent card structure: icon, title, message, optional `<slot />` action area
- `role="status"` + `aria-live="polite"` for accessible state transitions
- Per-variant colour tokens: red border/icon for error/not-linked, gray for empty/loading

**`PortalScheduleSection.astro`**
- Phone-first stacked `today` + `Minggu ini` sections — single column, no table/grid
- Today card highlights active shift with pink accent and "Hari ini" badge
- Day-off variant (Libur) with sun icon
- Overnight indicator `(Selesai besok)` in amber
- Today row in week list marked with pink day number and "Hari ini" inline label
- Notes field rendered in both today card and week rows
- `role="list"` + `role="listitem"` for accessible week list

## Verification

```
npm run check → ok (no errors)
```

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `src/lib/portal/home.ts` — created, type-checks clean
- [x] `src/components/portal/PortalStatePanel.astro` — created, type-checks clean
- [x] `src/components/portal/PortalScheduleSection.astro` — created, type-checks clean
- [x] Task 1 commit: `89900a1`
- [x] Task 2 commit: `4079e0e`

## Self-Check: PASSED
