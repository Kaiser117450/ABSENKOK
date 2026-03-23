# Phase 43: Portal Attendance Recap Surface - Research

**Researched:** 2026-03-23
**Domain:** Astro portal route design, shared recap components, and mobile-first attendance recap UI
**Confidence:** HIGH

## Summary

Phase 42 already finished the hard part: the website now has a typed `loadPortalAttendanceRecap()` helper that resolves the authenticated employee, calls the recap RPC exactly once, and returns `summaryCounts`, `days`, and `recentDays` from one normalized dataset. Phase 43 should stay a pure portal-surface phase. It does not need new SQL, new auth work, or a second recap query.

The cleanest implementation shape is a dedicated `/portal/attendance` route inside the existing portal shell, backed by shared ready-state components for month summary cards and recent history cards. That gives employees a clear entry point inside the current shell, keeps the schedule home intact, and leaves Phase 44 free to harden exception-state treatment and recap-specific loading/empty/error behavior without redesigning the happy-path UI.

**Primary recommendation:** Add a dedicated `/portal/attendance` page inside `PortalLayout.astro`, introduce shared summary/history components that consume the Phase 42 recap model directly, and expose the page through a shell-level navigation entry plus a lightweight home-page CTA.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ATTN-01 | Employee can open an attendance recap inside the existing portal and see recent attendance days without leaving the employee-facing shell. | Use a dedicated `/portal/attendance` route rendered inside `PortalLayout.astro`, plus a shell navigation entry and a home-page CTA that both point to the same route. |
| ATTN-04 | Employee can see month-to-date summary counts for the attendance states surfaced in the recap. | Consume `summaryCounts` from `loadPortalAttendanceRecap()` directly and render it through a summary-card component; do not issue a second aggregate query. |
| PORT-03 | Portal attendance recap is usable on a phone-sized browser and fits the existing employee portal shell. | Reuse the existing portal shell and the stacked-card visual pattern from `PortalScheduleSection.astro`; avoid tables, client-framework hydration, or dense desktop-first layouts. |
</phase_requirements>

## Current State Analysis

### 1. The read model is already ready for UI work

`src/lib/portal/attendance-recap.ts` already exposes:

- `loadPortalAttendanceRecap(Astro)`
- `summaryCounts`
- `days`
- `recentDays`
- the named attendance timestamps needed to explain a day result

That means Phase 43 should not spend scope on new data modeling.

### 2. The current shell has only one employee destination

The portal currently has:

- one home page at `src/pages/portal/index.astro`
- one shell in `src/layouts/PortalLayout.astro`
- one schedule-ready component in `src/components/portal/PortalScheduleSection.astro`
- one shared blocked-state card in `src/components/portal/PortalStatePanel.astro`

There is no attendance route or shell-level navigation yet, so ATTN-01 is not satisfied.

### 3. The existing mobile pattern is already the right precedent

`PortalScheduleSection.astro` uses:

- one-column stacked cards
- compact metadata rows
- badge-style status treatment
- no client framework

Phase 43 should copy that interaction density instead of inventing a denser table or timeline system.

### 4. Phase 44 owns the hardening work

The active roadmap explicitly reserves for Phase 44:

- follow-up-day clarity (`ATTN-05`)
- loading, empty, and error hardening (`PORT-04`)

Phase 43 can still render basic guarded fallbacks so the new page does not crash, but it should not spend scope on a dedicated exception-state system or a second pass over follow-up labeling.

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Astro SSR route | `astro@5.18.1` | Server-rendered recap page inside the employee portal | Matches the shipped portal architecture and keeps auth/data resolution on the server. |
| Existing portal shell | local repo pattern | Navigation, logout, and page framing | Keeps the recap inside the same employee-facing flow instead of creating a detached page. |
| Phase 42 recap helper | local repo pattern | Typed recap dataset and month summary counts | Already handles identity resolution, reference date, and single-query recap loading. |
| Tailwind utility styling | `tailwindcss@4.2.1` | Mobile-first card layout and status color treatment | Matches the shipped schedule surface and avoids introducing another styling system. |

### Supporting

| Tool / Pattern | Purpose | When to Use |
|----------------|---------|-------------|
| `PortalStatePanel.astro` | Minimal guarded fallback card | Use only for generic blocked or empty recap cases until Phase 44 hardens those states. |
| `PortalScheduleSection.astro` | Visual precedent for stacked cards and compact metadata | Mirror its density and status-badge treatment in recap components. |
| `npm run check` / `npm run build` | Fast portal verification | Run after each plan wave and before closing the phase. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dedicated `/portal/attendance` route | Expanding `/portal` home into one very large page | Faster to wire initially, but mixes schedule and recap concerns and makes shell navigation harder to evolve. |
| Shared recap components | Inline recap markup directly in the new page | Simpler short-term, but makes Phase 44 harder because state hardening and UI refinement would have to re-edit one large page template. |
| Shell nav + home CTA | Home CTA only | Fewer shell edits, but weaker "inside the portal shell" discoverability once more than one employee page exists. |
| Single recap dataset consumption | Separate summary-fetch or page-level data reshaping | Risks drift from the Phase 42 contract and duplicates logic already solved in the helper. |

## Recommended Architecture

### Pattern 1: Dedicated recap route inside the existing shell

Recommended path:

- `src/pages/portal/attendance.astro`

Recommended shell behavior:

- `PortalLayout.astro` accepts an active-section signal such as `home | attendance`
- the shell renders a compact, mobile-safe nav between `/portal` and `/portal/attendance`
- the recap page stays fully server-rendered

### Pattern 2: Shared ready-state recap components

Recommended components:

- `src/components/portal/PortalAttendanceSummary.astro`
- `src/components/portal/PortalAttendanceHistorySection.astro`

Component responsibilities:

- summary component renders month-to-date counts from `summaryCounts`
- history component renders recent day cards from `recentDays`
- both consume the typed recap model directly and do not perform new data fetches

### Pattern 3: Home page remains the schedule landing page

`/portal` should keep the schedule as the primary content. Phase 43 only needs to add a clear recap entry affordance there, for example:

- a compact CTA card below the greeting
- shell-level nav highlighting that the recap is a first-class portal destination

### Pattern 4: Minimal guarded fallbacks only

If `loadPortalAttendanceRecap()` returns:

- `unauthenticated` -> redirect to `/portal/login`
- `no_mapping` or `rpc_error` -> reuse `PortalStatePanel.astro` inside the shell
- `ok:true` with zero rows -> a basic recap-empty card is acceptable

That keeps the page functional without spending Phase 43 scope on the more explicit state and follow-up-day hardening reserved for Phase 44.

## Do Not Hand-Roll

| Problem | Do Not Build | Use Instead | Why |
|---------|--------------|-------------|-----|
| Recap data loading | Another Supabase query path or client-side employee filtering | `loadPortalAttendanceRecap(Astro)` | The helper already enforces the trusted employee-scoped read path. |
| Summary counts | New page-level aggregate logic unrelated to the helper | `summaryCounts` from the recap model | Prevents drift from the Phase 42 contract. |
| Shell navigation | A separate non-portal page or detached card flow | `PortalLayout.astro` with active-section styling | Keeps the recap inside the existing employee-facing portal flow. |
| Mobile UI | Table/grid recap layout | Stacked cards and compact badges | The current portal language is already phone-first and readable. |
| State hardening | New exception taxonomy in this phase | Generic fallback reuse; save hardening for Phase 44 | Prevents scope bleed into `ATTN-05` and `PORT-04`. |

## Common Pitfalls

### Pitfall 1: Double-fetching or re-deriving recap data in the page

**What goes wrong:** The page or components start rebuilding counts or re-querying Supabase even though the typed helper already returns the needed dataset.

**How to avoid:** Treat `loadPortalAttendanceRecap()` as the single recap data boundary. The page composes UI only.

### Pitfall 2: Making the recap route feel detached from the portal shell

**What goes wrong:** Employees land on a new page that feels like a different product surface, or they lose the simple path back to the schedule home.

**How to avoid:** Keep the page inside `PortalLayout.astro` and add an explicit shell nav state rather than a standalone landing page.

### Pitfall 3: Overbuilding exception-state treatment too early

**What goes wrong:** Phase 43 starts solving follow-up-day labels, recap-specific empty states, and hard failure messaging in detail, which overlaps Phase 44.

**How to avoid:** Limit Phase 43 to the ready-state surface plus minimal guarded fallbacks.

### Pitfall 4: Rendering recent history as a dense desktop list

**What goes wrong:** The page becomes hard to scan on a phone, especially for long notes, overnight shifts, or multiple timestamps.

**How to avoid:** Keep one-column cards with compact metadata rows and status badges, following `PortalScheduleSection.astro`.

## Code Examples

### Existing recap loader boundary

```ts
const recapResult = await loadPortalAttendanceRecap(Astro);
if (recapResult.ok) {
  recapResult.recap.summaryCounts;
  recapResult.recap.recentDays;
}
```

### Recommended shell-nav prop

```astro
<PortalLayout title="Kehadiran" employee={recap.employee} activeSection="attendance">
  ...
</PortalLayout>
```

### Recommended page composition

```astro
<PortalAttendanceSummary recap={recap} />
<PortalAttendanceHistorySection days={recap.recentDays} referenceDate={recap.referenceDate} />
```

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Astro `astro check` + `astro build`; targeted PowerShell source-contract checks |
| Config file | `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\package.json` |
| Quick run command | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` |
| Full suite command | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` |
| Estimated runtime | ~20 seconds |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ATTN-01 | Portal shell exposes an attendance recap destination and the recap page stays inside the shell | source smoke + build | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/layouts/PortalLayout.astro','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/index.astro','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/attendance.astro' -Pattern '/portal/attendance','activeSection','loadPortalAttendanceRecap' | Measure-Object"` | Missing in Phase 43 |
| ATTN-04 | Month-to-date summary counts and recent history render from the same recap model | source smoke + type/check | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceSummary.astro','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro' -Pattern 'summaryCounts','recentDays','attendanceStatus' | Measure-Object"` | Missing in Phase 43 |
| PORT-03 | Recap route and components remain mobile-first inside the portal shell | full build | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` | Existing |

### Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Employee can move between Beranda and Kehadiran without losing the portal shell context | ATTN-01 | Requires page navigation in a browser at real viewport sizes | Open `/portal`, use the shell nav or CTA to open the recap, then return to Beranda and confirm the shell header, logout, and active tab state stay coherent. |
| Summary chips match the visible recap history for seeded month data | ATTN-04 | Needs realistic portal employee data across multiple day statuses | Seed or use an employee with mixed `hadir`, `sakit`, `izin`, `tidak_hadir`, and `belum_pulang` days, then confirm the month summary equals the current-month rows from the recap dataset. |
| Long names, shift notes, and overnight metadata remain readable on a phone-width browser | PORT-03 | Visual density and wrapping are easier to confirm manually than with static source checks | Review `/portal/attendance` around 390px width and confirm there is no horizontal scroll and no clipped status/timestamp content. |

## Sources

### Primary (HIGH confidence)

- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absensi apk\\absensi_enakko_flutter\\.planning\\ROADMAP.md`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absensi apk\\absensi_enakko_flutter\\.planning\\REQUIREMENTS.md`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absensi apk\\absensi_enakko_flutter\\.planning\\STATE.md`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absensi apk\\absensi_enakko_flutter\\.planning\\phases\\39-employee-portal-schedule-ux\\39-01-SUMMARY.md`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absensi apk\\absensi_enakko_flutter\\.planning\\phases\\39-employee-portal-schedule-ux\\39-02-SUMMARY.md`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absensi apk\\absensi_enakko_flutter\\.planning\\phases\\42-attendance-recap-read-model\\42-02-SUMMARY.md`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\src\\layouts\\PortalLayout.astro`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\src\\pages\\portal\\index.astro`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\src\\components\\portal\\PortalScheduleSection.astro`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\src\\components\\portal\\PortalStatePanel.astro`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\src\\lib\\portal\\attendance-recap.ts`

## Metadata

**Confidence breakdown:**

- Route and shell architecture: HIGH - the current portal already uses one SSR shell and thin page orchestration.
- Recap data consumption path: HIGH - the Phase 42 helper is already implemented and typed.
- Mobile UI direction: HIGH - the existing schedule surface establishes the exact visual density this phase should reuse.

**Research date:** 2026-03-23
**Valid until:** 2026-04-22
