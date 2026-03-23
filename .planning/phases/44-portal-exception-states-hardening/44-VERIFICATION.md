---
status: verified
score: 100
human_verification: required-for-visual-and-session-states
---

# Phase 44 Verification Report: Portal Exception States & Hardening

## Goal Achievement

Phase 44 hardened the portal recap surface with a typed exception taxonomy, explicit follow-up labeling in the history component, page-level empty/error state branching, and shell-level loading feedback for SSR navigation. The Phase 45 Plan 01 fix additionally made historical supporting copy accurate for past rows.

| Requirement | Delivered | Evidence |
|---|---|---|
| ATTN-05 — Employee can identify days needing follow-up | Yes | `attendance-recap-presentation.ts` exports `isFollowUpStatus`, `countFollowUpDays`, `getRecapDayPresentationForDay`; `PortalAttendanceHistorySection.astro` renders follow-up chips for `belum_pulang` and `tidak_hadir` only |
| PORT-04 — Recap shows clear loading, empty, and error states | Yes | `attendance.astro` branches empty (`ok:true` + `days.length === 0`), `no_mapping`, and `rpc_error` at page level with `PortalStatePanel`; `PortalLayout.astro` shell progress bar triggered for all same-origin portal navigation |

---

## Observable Truths

### Truth 1 — Follow-up days are determined by a single shared taxonomy

`attendance-recap-presentation.ts` is the sole source of exception semantics for the portal recap surface. It maps every `AttendanceStatus` value to a `RecapDayPresentation` object and exports `isFollowUpStatus(status)` which returns `true` only for `belum_pulang` and `tidak_hadir`. These are prior-day unresolved states. Current-day in-progress states (`sedang_bekerja`, `belum_masuk`) have `needsFollowUp: false` and use `accent` tone so employees are informed without being alarmed. Resolved outcomes (`hadir`, `sakit`, `izin`, `libur`) are also non-follow-up.

`PortalAttendanceHistorySection.astro` imports `getRecapDayPresentationForDay` and calls it for every history card. The old ad hoc `getStatusLabel` and `getStatusStyle` switch statements were replaced. A follow-up chip with warning triangle icon and `followUpLabel` text is rendered only when `pres.needsFollowUp` is `true`.

**Grounded in:**
- `src/lib/portal/attendance-recap-presentation.ts` — `PRESENTATION_MAP`, `isFollowUpStatus`, `getRecapDayPresentation`, `getRecapDayPresentationForDay`
- `src/components/portal/PortalAttendanceHistorySection.astro` — `getRecapDayPresentationForDay` import on line 28; follow-up chip block conditioned on `pres.needsFollowUp && pres.followUpLabel`

### Truth 2 — Historical rows use date-accurate supporting copy

Phase 45 Plan 01 added `getRecapDayPresentationForDay(day, referenceDate)` to the presentation helper. This function accepts both the recap day row (with `logicalDate`) and the recap `referenceDate`. For historical rows (`logicalDate !== referenceDate`), it overrides the supporting copy for statuses that previously used "hari ini" phrasing (`sakit`, `izin`, `sedang_bekerja`, `belum_masuk`), replacing them with "pada hari tersebut" copy. Follow-up gap statuses (`belum_pulang`, `tidak_hadir`) use history-appropriate wording in the base map and are unchanged.

`PortalAttendanceHistorySection.astro` was updated in Phase 45 to use `getRecapDayPresentationForDay(day, referenceDate)` instead of the status-only `getRecapDayPresentation(status)`, so every history card now receives historically accurate supporting copy.

**Grounded in:**
- `src/lib/portal/attendance-recap-presentation.ts` — `getRecapDayPresentationForDay` function (lines 195–234); `case 'sakit':` and `case 'izin':` historical overrides
- `src/components/portal/PortalAttendanceHistorySection.astro` — `getRecapDayPresentationForDay` import; `referenceDate` prop passed as second argument to the helper

### Truth 3 — Recap unavailability branches explicitly at the page level before ready-state components render

`attendance.astro` has four exclusive render branches:

1. `!result.ok && result.reason === 'unauthenticated'` → redirect to `/portal/login`
2. `result.ok && result.recap.days.length === 0` → `PortalLayout` + recap-specific `PortalStatePanel` (variant `"empty"`, title "Belum ada data kehadiran")
3. `result.ok && result.recap.days.length > 0` → ready state with `PortalAttendanceSummary` + `PortalAttendanceHistorySection`
4. `!result.ok && result.reason === 'no_mapping'` → `PortalLayout` + `PortalStatePanel` (variant `"not-linked"`) with logout CTA
5. `!result.ok && result.reason === 'rpc_error'` → `PortalLayout` + `PortalStatePanel` (variant `"error"`) with retry CTA

`PortalAttendanceSummary` and `PortalAttendanceHistorySection` are never asked to render empty/error page states — they only appear inside branch 3. The empty state copy is recap-specific and distinct from the generic schedule-flavored `PortalStatePanel` defaults.

**Grounded in:** `src/pages/portal/attendance.astro` — five render blocks (lines 34–114); `PortalStatePanel` with `variant="empty"`, `variant="not-linked"`, `variant="error"` in respective branches

### Truth 4 — Shell progress bar covers all same-origin portal navigation and retry actions

`PortalLayout.astro` includes an inline script with a shared `showProgress()` helper. This helper sets the `#portal-progress` bar width to `60%` and sets `aria-busy="true"` on `#portal-main`. It is invoked in two places:

1. Logout form `submit` event — also disables the logout button and changes text to "Keluar…"
2. `document` click listener — fires on same-origin `/portal` anchor clicks that would cause a full-page SSR navigation. Excluded: modified clicks (`ctrlKey`, `metaKey`, `shiftKey`, `altKey`), middle-button clicks, `target="_blank"` links, hash-only links, `mailto:`, `tel:`, and external origins.

This makes loading feedback visible for retry CTAs on the error branch and for tab navigation between Beranda and Kehadiran, matching the SSR-first interaction model.

**Grounded in:** `src/layouts/PortalLayout.astro` — `#portal-progress` div (lines 111–118); inline script `showProgress()` function (lines 143–150); logout form handler (lines 153–163); click listener handler (lines 168–192)

---

## Required Artifacts

| Artifact | Path | Status |
|---|---|---|
| Recap presentation helper | `src/lib/portal/attendance-recap-presentation.ts` (absenkok-website) | Shipped (commit 5ee50a6; Phase 45 historical fix in commit for 45-01) |
| History section component | `src/components/portal/PortalAttendanceHistorySection.astro` | Hardened (commits 40791e5; Phase 45 history-fix update) |
| Attendance page route | `src/pages/portal/attendance.astro` | Hardened (commit 7fb66b2) |
| Portal layout shell | `src/layouts/PortalLayout.astro` | Extended (commit a20719e) |
| SQL exception taxonomy docs | `sql/phase_42_portal_attendance_recap_20260323.sql` | Annotated (commit 24f97c4) |

---

## Key Link Verification

| From | To | Via | Pattern present |
|---|---|---|---|
| `44-VERIFICATION.md` | `src/lib/portal/attendance-recap-presentation.ts` | Documents the final recap copy behavior after the Phase 45 historical fix | `getRecapDayPresentationForDay` present; `historical` context handled via `logicalDate !== referenceDate` branch |
| `attendance-recap-presentation.ts` | `PortalAttendanceHistorySection.astro` | `getRecapDayPresentationForDay` import; `needsFollowUp`, `followUpLabel`, `supportingCopy` consumed | `needsFollowUp`, `followUpLabel`, `supportingCopy` all present in component (6 matches confirmed during Phase 44 Plan 02 verification) |
| `attendance.astro` | `PortalStatePanel` | Empty state (`days.length === 0`), error state (`rpc_error`), not-linked state (`no_mapping`) all branch to `PortalStatePanel` at page level | `PortalStatePanel`, `days.length === 0`, `PortalLayout` all present in attendance.astro |
| `PortalLayout.astro` | `showProgress()` | Shell progress bar covers logout submit and same-origin portal anchor clicks | `aria-busy`, `portal-progress`, `/portal` path check present in inline script |

---

## Requirements Coverage

| Requirement ID | Description | Evidence |
|---|---|---|
| ATTN-05 | Employee can identify days needing follow-up — incomplete outcomes and scheduled days without completed attendance | `isFollowUpStatus` taxonomy: `belum_pulang` + `tidak_hadir` are prior-day gaps; follow-up chip with warning icon on history cards; `countFollowUpDays` drives amber banner on `PortalAttendanceSummary`; `sedang_bekerja` and `belum_masuk` intentionally excluded from follow-up labeling |
| PORT-04 | Portal recap shows clear loading, empty, and error states when recap data is unavailable | Page-level branches in `attendance.astro`: empty (`days.length === 0` + `PortalStatePanel variant="empty"`), error (`rpc_error` + retry CTA), not-linked (`no_mapping` + logout CTA); shell progress bar in `PortalLayout.astro` for navigation and retry link clicks |

---

## Scope Boundary: Phase 44 Only

Phase 44 verification does not re-claim Phase 42 or 43 evidence. The following behaviors are documented in their respective verification reports:

- RPC authentication and employee scoping: Phase 42 (`42-VERIFICATION.md`)
- Portal shell integration, summary chip grid, home CTA: Phase 43 (`43-VERIFICATION.md`)
- Ready-state data flow (one RPC call, no second query): Phase 43

---

## Human Verification Required

The following checks require a live browser session and cannot be automated from planning files:

1. **Follow-up chip on past `belum_pulang` row:** Sign in as an employee with a past day where clock-out was never recorded. Confirm the history card shows an amber warning chip with "Absensi pulang belum tercatat" and the supporting copy uses "pada hari tersebut" phrasing, not "hari ini".

2. **`tidak_hadir` vs `belum_pulang` distinguished:** Confirm that a `tidak_hadir` day (no scans at all) shows different follow-up copy ("Tidak ada kehadiran tercatat") compared to a `belum_pulang` day ("Absensi pulang belum tercatat").

3. **Empty recap state:** Sign in as an employee whose portal account resolves but whose recap returns zero days. Confirm the page shows the recap-specific empty state ("Belum ada data kehadiran") and does not render summary chips or the history list.

4. **Shell loading feedback:** On a phone-width browser, tap the "Kehadiran" and "Beranda" nav tabs. Confirm the shell progress bar briefly appears before the next page loads. Confirm the same bar appears when clicking the "Muat Ulang" retry CTA on the error state.

5. **`sedang_bekerja` stays calm:** On an active shift day, confirm the current-day card does not show a follow-up chip or warning styling — only the `accent` (pink) tone and the informational "Karyawan sedang dalam jam kerja" note.

---

*Phase: 44-portal-exception-states-hardening*
*Verified: 2026-03-23*
