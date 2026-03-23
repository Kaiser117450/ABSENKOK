---
status: verified
score: 100
human_verification: required-for-visual-and-navigation
---

# Phase 43 Verification Report: Portal Attendance Recap Surface

## Goal Achievement

Phase 43 delivered the employee-facing attendance recap portal route and all ready-state UI components required by v6.3.

| Requirement | Delivered | Evidence |
|---|---|---|
| ATTN-01 — Employee can view attendance recap in the portal | Yes | `/portal/attendance` SSR route; `loadPortalAttendanceRecap` called once; summary + history rendered |
| ATTN-04 — Recap history surface shows per-day status and timestamps | Yes | `PortalAttendanceHistorySection.astro` renders per-day status badge and named timestamps |
| PORT-03 — Recap route lives inside the portal shell | Yes | `PortalLayout` wraps every branch; `activeSection="attendance"` activates the shell nav tab |

---

## Observable Truths

### Truth 1 — `/portal/attendance` stays inside the existing portal shell

Every render branch in `attendance.astro` (ready with data, empty, no_mapping, rpc_error) wraps its content in `<PortalLayout ... activeSection="attendance">`. The shell's two-tab nav (Beranda / Kehadiran) was extended in Phase 43 Plan 02 via the `activeSection` prop on `PortalLayout`; the attendance tab is highlighted when the employee is on `/portal/attendance`. Unauthenticated requests redirect to `/portal/login` before any shell render.

**Grounded in:** `src/pages/portal/attendance.astro` (all four render branches, lines 34–114); `src/layouts/PortalLayout.astro` (activeSection prop added in commit 909c406).

### Truth 2 — Month summary and recent history render from one recap dataset

`attendance.astro` calls `loadPortalAttendanceRecap(Astro)` exactly once (line 12). Both child components receive data derived from that single result:

- `PortalAttendanceSummary` receives `result.recap.summaryCounts` and `result.recap.monthStart` — both derived inside `loadPortalAttendanceRecap` from the single RPC call.
- `PortalAttendanceHistorySection` receives `result.recap.recentDays` — the 14-day slice also derived from the same normalized day array inside the helper.

No second RPC or fetch is issued by the page or either component.

**Grounded in:** `src/pages/portal/attendance.astro` (lines 65–77 — `PortalAttendanceSummary` and `PortalAttendanceHistorySection` props); `src/lib/portal/attendance-recap.ts` (lines 308–309 — `recentDays` derived from `days` with no second query).

### Truth 3 — Surface is phone-first, not table-based

`PortalAttendanceSummary.astro` renders a responsive 3-column chip grid (not a data table). `PortalAttendanceHistorySection.astro` renders stacked one-column cards in the same pattern as `PortalScheduleSection.astro`. Neither component uses `<table>` elements. The page has no horizontal scroll container or fixed-width column layout.

**Grounded in:** `src/components/portal/PortalAttendanceSummary.astro` (chip grid, commit f3cbb4a); `src/components/portal/PortalAttendanceHistorySection.astro` (stacked card list, commit 3a7febc).

---

## Required Artifacts

| Artifact | Path | Status |
|---|---|---|
| Portal attendance route | `src/pages/portal/attendance.astro` (absenkok-website) | Shipped (commit 593b32a) |
| Month-summary component | `src/components/portal/PortalAttendanceSummary.astro` | Shipped (commit f3cbb4a) |
| Recent-history component | `src/components/portal/PortalAttendanceHistorySection.astro` | Shipped (commit 3a7febc) |
| Shell nav extension | `src/layouts/PortalLayout.astro` (activeSection prop) | Shipped (commit 909c406) |
| Home CTA card | `src/pages/portal/index.astro` (recap CTA below greeting) | Shipped (commit 7d5541a) |

---

## Key Link Verification

| From | To | Via | Pattern present |
|---|---|---|---|
| `43-VERIFICATION.md` | `src/pages/portal/attendance.astro` | Documents the same shell-contained recap route already shipped by Phase 43 | `/portal/attendance` present as `href` and SSR route |
| `attendance.astro` | `loadPortalAttendanceRecap` | `import { loadPortalAttendanceRecap } from '../../lib/portal/attendance-recap'` | `loadPortalAttendanceRecap` called on line 12 |
| `attendance.astro` | `PortalLayout` | Every render branch wraps content in `<PortalLayout>` with `activeSection="attendance"` | Pattern present across all four branches |

---

## Automated Evidence Check

The following structural check confirms the route and shell integration are present in the shipped source:

```
grep "loadPortalAttendanceRecap" src/pages/portal/attendance.astro
# → import { loadPortalAttendanceRecap } from '../../lib/portal/attendance-recap';
# → const result = await loadPortalAttendanceRecap(Astro);

grep "activeSection=\"attendance\"" src/pages/portal/attendance.astro
# → four matches — one per render branch (empty, ready, no_mapping, rpc_error)
```

Both patterns are confirmed present in `attendance.astro` at the time of this verification.

---

## Requirements Coverage

| Requirement ID | Description | Evidence |
|---|---|---|
| ATTN-01 | Employee can view attendance recap in the portal | `/portal/attendance` SSR route; `PortalAttendanceSummary` + `PortalAttendanceHistorySection` render on successful load |
| ATTN-04 — | Per-day status and named timestamps visible in history surface | `PortalAttendanceHistorySection` renders `attendanceStatus` badge, `firstMasukAt`, `lastPulangAt`, `firstBreakAt`, `lastKembaliAt` per card |
| PORT-03 | Recap route integrated into portal shell with navigation | `PortalLayout` wraps all branches; `activeSection="attendance"` activates shell nav; home CTA at `/portal` links to `/portal/attendance` |

---

## Scope Boundary: Phase 44 Hardening Not Claimed Here

Phase 43 delivers the base ready-state recap surface. The following behaviors belong to Phase 44 and are not verified here:

- Loading skeleton and shimmer state during recap fetch
- Follow-up count badge and `PortalAttendanceSummary` follow-up framing (added in Phase 44 Plan 03)
- `countFollowUpDays` import in `attendance.astro` — this import was wired in Phase 44, not Phase 43
- Full recap-specific empty/error state taxonomy beyond the base `PortalStatePanel` fallbacks

---

## Human Verification Required

The following checks require a live browser session and cannot be automated from planning files:

1. **Shell nav active state:** Open `/portal/attendance` as an authenticated employee and confirm the "Kehadiran" tab in the shell nav is highlighted (pink active indicator) while "Beranda" is inactive.

2. **Summary chip grid:** Confirm the month-summary counts render as a 3-column chip grid (Hadir, Tidak Hadir, Sakit, Izin, Belum Pulang, Libur) with correct color coding on a mobile viewport.

3. **History card timestamps:** Open a day with both masuk and pulang in recent history; confirm that clock-in and clock-out timestamps are shown in the card in Indonesian-locale hour:minute format.

4. **Home CTA entry point:** Open `/portal` and confirm the attendance recap CTA card is visible below the employee greeting with a link to `/portal/attendance`.

---

*Phase: 43-portal-attendance-recap-surface*
*Verified: 2026-03-23*
