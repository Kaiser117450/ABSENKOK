# Phase 44: Portal Exception States & Hardening - Research

**Researched:** 2026-03-23
**Domain:** Portal recap exception presentation, explicit availability states, and cross-repo contract alignment
**Confidence:** HIGH for portal state architecture and follow-up taxonomy; MEDIUM for final employee-facing copy tone

## Summary

Phase 43 shipped the portal recap route on purpose with a minimal happy-path focus: one trusted recap dataset, one shell destination, and only lightweight blocked-state handling. That leaves the exact Phase 44 gap visible in the current code:

- days that need follow-up are present in the dataset but only read as raw status badges
- empty recap data is still treated as a list-section concern instead of a page-level portal state
- loading feedback exists only for logout, not for recap navigation or retry actions inside the shell
- the SQL source contract and the portal presentation code still rely on separate implicit interpretations of the same `attendance_status` values

The safest Phase 44 shape is not a new RPC or a new portal data flow. It is a hardening pass over the existing recap surface:

1. document and centralize the meaning of recap exception statuses across the SQL source file and one typed portal presentation helper
2. use that helper to make follow-up days explicit in the history UI without falsely escalating current-day in-progress states
3. move recap unavailability handling to the page level and treat loading in Astro SSR as shell-level navigation feedback, not client-side data fetching

There is no phase-specific `CONTEXT.md` for Phase 44. This research is based on the approved roadmap, current requirements, project state, and the shipped recap implementation in the website repo.

**Primary recommendation:** keep the Phase 42 RPC shape intact, add one shared presentation/exception mapping in the website repo plus matching SQL source comments, then use that mapping to harden the history cards, summary framing, and page-level empty/error/loading treatment.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ATTN-05 | Employee can identify days that need follow-up, including incomplete attendance outcomes and scheduled days without a completed attendance record. | The recap dataset already exposes `belum_pulang`, `tidak_hadir`, `belum_masuk`, and `sedang_bekerja`; Phase 44 should turn those into one explicit follow-up taxonomy instead of leaving them as raw badges. |
| PORT-04 | Portal attendance recap shows clear loading, empty, and error states when recap data is unavailable. | Astro SSR means loading is shell navigation pending, while empty and error should branch at `attendance.astro` before ready-state recap cards render. |
</phase_requirements>

## Current State Analysis

### 1. The route already exists, but exception days are only raw status labels

`src/pages/portal/attendance.astro` now loads `loadPortalAttendanceRecap(Astro)` exactly once and renders the ready-state page inside `PortalLayout.astro`. That is good Phase 43 behavior. The remaining Phase 44 issue is that `PortalAttendanceHistorySection.astro` still treats the recap day primarily as a status badge plus timestamps. Employees can see `Belum Pulang` or `Tidak Hadir`, but the UI does not yet clearly say:

- which days need follow-up
- why the day is exceptional
- which current-day states are informational rather than action-oriented

The data is present. The presentation contract is not.

### 2. The current recap page handles blocked failures, but not recap unavailability as a first-class page state

The current route already branches for:

- `unauthenticated` -> redirect
- `no_mapping` -> shell + `PortalStatePanel`
- `rpc_error` -> shell + `PortalStatePanel`

But when the recap returns zero days, the page still renders summary cards and only the history component shows a small "Belum ada data riwayat kehadiran" block. That is too subtle for `PORT-04`. Empty recap data should be explicit at the page level so employees do not interpret zero summary chips as a broken recap or a real zero-history month without explanation.

### 3. Loading feedback exists in the shell already, but only for logout

`PortalLayout.astro` already includes:

- a top progress bar
- `aria-busy` handling
- a lightweight inline script

Today that script only runs on the logout form. In this SSR architecture, the cleanest Phase 44 loading state is to reuse the same shell affordance for recap navigation and retry actions. A client-side loading skeleton would be misleading because the page is not doing client fetches after mount.

### 4. The SQL contract already distinguishes actionable and non-actionable states

The Phase 42 SQL source file already derives a richer status set than the Phase 43 UI uses:

- `belum_pulang`
- `tidak_hadir`
- `belum_masuk`
- `sedang_bekerja`
- `hadir`
- `sakit`
- `izin`
- `libur`

This is enough to implement Phase 44 without adding a second query shape. The hardening gap is that these statuses are still interpreted separately in:

- SQL comments
- `attendance-recap.ts`
- `PortalAttendanceHistorySection.astro`
- any future summary or page framing logic

That drift risk is exactly what the roadmap calls out.

### 5. `PortalStatePanel.astro` is generic and schedule-oriented by default

The shared state panel already supports `loading`, `empty`, `not-linked`, and `error`, but its default copy is still schedule-flavored:

- empty -> "Belum ada jadwal"
- error -> "Tidak dapat memuat data"

The recap page can and should keep using the component, but Phase 44 needs recap-specific title/message branching at the page level instead of relying on defaults that were written for the schedule surface.

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Astro SSR route | `astro@5.18.1` | Recap page branching and shell rendering | Matches the current employee portal architecture and keeps auth/data server-side. |
| Existing recap helper | local repo pattern | Trusted typed recap dataset | Already returns the statuses and timestamps Phase 44 needs. |
| Existing portal shell | local repo pattern | Navigation, pending feedback, page framing | Already contains the right place for loading treatment inside the shell. |
| Tailwind utility styling | `tailwindcss@4.2.1` | Mobile-first exception emphasis and state layout | Matches the shipped portal visual language. |

### Supporting

| Tool / Pattern | Purpose | When to Use |
|----------------|---------|-------------|
| `PortalStatePanel.astro` | Shared empty/error/loading shell card | Use for recap unavailability with recap-specific copy. |
| `PortalScheduleSection.astro` | Card-density precedent | Keep recap exception cards as one-column stacked cards, not tables. |
| SQL source comments in `phase_42_portal_attendance_recap_20260323.sql` | Cross-repo status contract anchor | Clarify which statuses are follow-up vs current-day neutral without changing the deployed RPC shape. |
| `npm run check` / `npm run build` | Portal verification | Use after each task and after the final wave. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Shared presentation helper for recap statuses | Inline badge/copy logic inside each component | Faster short-term, but increases drift between the route, summary, history cards, and SQL semantics. |
| Page-level empty state when `days.length === 0` | Keep the current history-section-only empty card | Simpler, but too easy to miss and not strong enough for `PORT-04`. |
| Shell-level pending feedback for recap navigation | Client-side loading skeletons | Looks more dynamic, but is architecturally wrong for this server-rendered portal path. |
| Reusing existing status union | Adding new SQL columns just for UI wording | Could make UI code smaller, but introduces unnecessary database churn for a problem already solvable with the current contract. |

## Recommended Architecture

### Pattern 1: One typed recap presentation helper

Add one small helper module in the website repo, for example:

- `src/lib/portal/attendance-recap-presentation.ts`

Recommended responsibilities:

- map `AttendanceStatus` to employee-facing label, tone, and supporting copy
- expose `needsFollowUp` and `followUpLabel`
- expose one helper like `countFollowUpDays(days)` for page framing

This keeps Phase 44 from re-implementing the same meaning in multiple components.

### Pattern 2: Follow-up is explicit, but current-day in-progress states stay neutral

Recommended taxonomy:

- `belum_pulang` -> follow-up day
- `tidak_hadir` -> follow-up day
- `belum_masuk` -> informational current-day pending state, not follow-up yet
- `sedang_bekerja` -> informational in-progress state, not follow-up
- `sakit`, `izin`, `libur`, `hadir` -> non-follow-up outcomes

That distinction matters because employees should not see "needs follow-up" on a day that is still actively in progress.

### Pattern 3: Empty and error states branch before ready-state recap cards render

Recommended page behavior in `attendance.astro`:

- `unauthenticated` -> redirect
- `no_mapping` -> shell + recap-specific blocked copy
- `rpc_error` -> shell + recap-specific error copy and retry action
- `ok:true` with `days.length === 0` -> shell + recap-specific empty state
- ready state only when recap data exists

The summary and history components should not be asked to explain the page's unavailability.

### Pattern 4: Loading is shell-level pending feedback, not a recap data skeleton

Because the recap path is server-rendered, the correct loading signal is:

- progress bar in `PortalLayout.astro`
- `aria-busy="true"` on internal navigation / retry click
- no client framework and no fake list skeleton

That keeps the shell consistent and makes loading visible even on phone-width navigation taps.

### Pattern 5: Keep SQL source and portal helper semantics synchronized

Phase 44 does not need a new database output shape, but it does need one source-of-truth contract story. The easiest way to do that is:

- annotate the SQL source comments around `with_status`
- build the website presentation helper directly from the existing `AttendanceStatus` union
- verify both repos mention the same exception states in the validation checks

This closes the "cross-repo hardening gap" without reopening the deployed recap RPC.

## Do Not Hand-Roll

| Problem | Do Not Build | Use Instead | Why |
|---------|--------------|-------------|-----|
| Follow-up meaning | Hand-written badge/copy logic in every component | One shared recap presentation helper | Prevents drift and keeps current-day states consistent. |
| Empty recap handling | A tiny empty block only inside `PortalAttendanceHistorySection.astro` | Page-level `PortalStatePanel` branch in `attendance.astro` | Makes recap unavailability explicit before ready-state cards render. |
| Loading state | Client-side recap fetch and skeleton cards | Shell progress + `aria-busy` on internal navigation | Fits Astro SSR and avoids fake client state. |
| Contract alignment | Silent assumptions in UI only | SQL source comments + typed helper + validation smoke checks | Keeps the SQL contract, portal implementation, and planning language aligned. |
| Phase 44 scope | Mutation actions, correction forms, or request submission | Read-only explanatory hardening | Request workflows are still out of scope for v6.3. |

## Common Pitfalls

### Pitfall 1: Treating `belum_masuk` as a follow-up failure

**What goes wrong:** Employees see a false warning for a scheduled day that has not started yet.

**How to avoid:** Keep `belum_masuk` informational and reserve follow-up labeling for unresolved prior-day gaps like `belum_pulang` and `tidak_hadir`.

### Pitfall 2: Leaving empty recap handling inside the history section only

**What goes wrong:** The page still looks half-ready because summary chips render above a small empty card.

**How to avoid:** Branch empty recap at the page level and render one explicit recap-specific empty state before any ready-state recap components.

### Pitfall 3: Solving loading with client-side recap fetches

**What goes wrong:** The portal adds a second data path and more moving parts for a server-rendered route.

**How to avoid:** Reuse the shell progress bar and `aria-busy` handling for navigation/retry actions instead.

### Pitfall 4: Re-describing the SQL status contract differently in each component

**What goes wrong:** History cards, summary framing, and later detail pages disagree about which states need follow-up.

**How to avoid:** Centralize the mapping in one helper and point the validation smoke checks at both the SQL source and the helper.

### Pitfall 5: Turning Phase 44 into a workflow phase

**What goes wrong:** The UI starts promising correction submission or manager escalation flows that do not exist in v6.3.

**How to avoid:** Keep the phase explanatory and read-only: clear labels, clear states, no mutation actions.

## Code Examples

### Suggested presentation helper shape

```ts
type RecapDayPresentation = {
  label: string;
  tone: 'neutral' | 'success' | 'warning' | 'danger' | 'accent';
  needsFollowUp: boolean;
  followUpLabel: string | null;
  supportingCopy: string | null;
};
```

### Suggested follow-up classifier

```ts
function isFollowUpStatus(status: AttendanceStatus): boolean {
  return status === 'belum_pulang' || status === 'tidak_hadir';
}
```

### Recommended page-level empty branch

```astro
if (result.ok && result.recap.days.length === 0) {
  return (
    <PortalLayout ...>
      <PortalStatePanel variant="empty" ... />
    </PortalLayout>
  );
}
```

### Recommended shell loading treatment

```ts
link.addEventListener('click', () => {
  bar.style.width = '60%';
  main?.setAttribute('aria-busy', 'true');
});
```

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Astro `astro check` + `astro build`; targeted PowerShell source-contract smoke checks |
| Config file | `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\package.json` |
| Quick run command | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` |
| Full suite command | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` |
| Estimated runtime | ~20 seconds |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ATTN-05 | Follow-up days are derived from one shared recap taxonomy and rendered explicitly in portal history/framing | source smoke + type/check | `powershell -Command "Select-String -Path 'sql/phase_42_portal_attendance_recap_20260323.sql','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap-presentation.ts','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro' -Pattern 'belum_pulang','tidak_hadir','needsFollowUp','followUpLabel' | Measure-Object"` | Missing in Phase 44 |
| PORT-04 | Recap loading, empty, and error states are explicit at the shell/page level | source smoke + build | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/attendance.astro','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/layouts/PortalLayout.astro' -Pattern 'PortalStatePanel','aria-busy','portal-progress','days.length === 0' | Measure-Object"` | Existing |

### Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Missing-clock-out and no-attendance days read as different follow-up problems | ATTN-05 | The difference is easier to judge visually than with static text checks | Seed or use one employee with both `belum_pulang` and `tidak_hadir` days, then confirm each card has distinct explanatory copy instead of one generic warning. |
| A newly linked employee with no recap rows sees a clear no-data recap state | PORT-04 | Needs a realistic account state with valid auth but no recap history | Sign in as an employee whose portal account resolves correctly but has no recap rows, then confirm the page shows one explicit recap state instead of summary zeros plus a tiny list placeholder. |
| Shell navigation and retry actions show pending feedback on a phone-width browser | PORT-04 | Requires interaction timing and viewport behavior | On a phone-width browser, tap `Kehadiran`, `Beranda`, and any recap retry CTA, then confirm the shell progress bar appears and `aria-busy` behavior does not trap navigation. |

## Sources

### Primary (HIGH confidence)

- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\ROADMAP.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\REQUIREMENTS.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\STATE.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\43-portal-attendance-recap-surface\43-RESEARCH.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\43-portal-attendance-recap-surface\43-01-PLAN.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\43-portal-attendance-recap-surface\43-02-PLAN.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\43-portal-attendance-recap-surface\43-03-PLAN.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\sql\phase_42_portal_attendance_recap_20260323.sql`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\lib\portal\attendance-recap.ts`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\pages\portal\attendance.astro`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\components\portal\PortalAttendanceHistorySection.astro`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\components\portal\PortalAttendanceSummary.astro`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\components\portal\PortalStatePanel.astro`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\layouts\PortalLayout.astro`

### Secondary (MEDIUM confidence)

- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\42-attendance-recap-read-model\42-RESEARCH.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\42-attendance-recap-read-model\42-02-SUMMARY.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\components\portal\PortalScheduleSection.astro`

## Metadata

**Confidence breakdown:**

- Recap state architecture: HIGH - the route, shell, and helper boundaries are already shipped and easy to extend without new data flow.
- Follow-up taxonomy: HIGH - the current SQL status union already distinguishes prior-day gaps from current-day in-progress states.
- Final copy tone: MEDIUM - the exact wording for employee-facing follow-up labels may need one pass during implementation to keep it calm but explicit.

**Research date:** 2026-03-23
**Valid until:** 2026-04-22
