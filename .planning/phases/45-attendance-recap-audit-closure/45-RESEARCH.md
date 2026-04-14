# Phase 45: Attendance Recap Audit Closure - Research

**Researched:** 2026-03-23
**Domain:** v6.3 audit closure, historical recap-copy correctness, and verification evidence backfill
**Confidence:** HIGH for the audit scope and verification-artifact shape; MEDIUM for the exact final wording of historical employee-facing copy

## Summary

Phase 45 is not a new feature phase. It is a closure phase for the v6.3 milestone audit. The current blockers are explicit and narrow:

1. historical follow-up copy in the portal recap helper is status-only, so past rows can still read as if they are happening "hari ini"
2. phases 42, 43, and 44 have plan and summary artifacts, but no `VERIFICATION.md` files on disk
3. the milestone audit therefore reports every v6.3 requirement as orphaned, even though the shipped code and summaries already exist

The cleanest execution shape is:

1. make the recap presentation helper date-aware so it can generate row-accurate supporting copy for both current and historical days
2. backfill `42-VERIFICATION.md`, `43-VERIFICATION.md`, and `44-VERIFICATION.md` from the shipped code, existing summaries, and targeted build/source evidence
3. rerun and rewrite `v6.3-MILESTONE-AUDIT.md`, then sync `ROADMAP.md`, `REQUIREMENTS.md`, and `STATE.md` so the milestone can close without accepted audit debt

There is no phase-specific `CONTEXT.md` for Phase 45. This research is based on the roadmap, milestone audit, shipped phase 42-44 artifacts, and the current portal implementation in the website repo.

**Primary recommendation:** split Phase 45 into three plans across two waves: one code fix for date-aware recap copy, one documentation-only verification backfill for phases 42-43, and one final closeout plan for phase 44 verification plus milestone audit regeneration.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ATTN-01 | Employee can open an attendance recap inside the existing portal and see recent attendance days without leaving the employee-facing shell. | Covered by Phase 43 shipped route and shell navigation; Phase 45 must add on-disk verification evidence and preserve that path during closeout. |
| ATTN-02 | Each recap day shows the recorded attendance outcome together with the available attendance timestamps for that logical workday. | Covered by Phase 42 shipped SQL + typed helper; Phase 45 must capture verification evidence from those artifacts. |
| ATTN-03 | Portal attendance recap applies the product's existing logical-day and overnight handling so cross-day attendance appears on the correct workday. | Covered by Phase 42 shipped overnight-repair logic; Phase 45 must verify and document it explicitly. |
| ATTN-04 | Employee can see month-to-date summary counts for the attendance states surfaced in the recap. | Covered by Phase 43 summary/history surface; Phase 45 must verify and preserve it. |
| ATTN-05 | Employee can identify days that need follow-up, including incomplete attendance outcomes and scheduled days without a completed attendance record. | This is the only remaining product-level gap: historical follow-up copy still uses current-day phrasing for past rows. |
| PORT-03 | Portal attendance recap is usable on a phone-sized browser and fits the existing employee portal shell. | Already shipped in Phase 43 and reinforced in Phase 44; Phase 45 must backfill verification evidence rather than redesign the UI. |
| PORT-04 | Portal attendance recap shows clear loading, empty, and error states when recap data is unavailable. | Already shipped in Phase 44; Phase 45 must verify the final surface after the copy fix and close the milestone audit. |
</phase_requirements>

## Current State Analysis

### 1. The audit blockers are explicit, not exploratory

`v6.3-MILESTONE-AUDIT.md` already identifies exactly what is missing:

- one real product gap in `attendance-recap-presentation.ts`
- zero `VERIFICATION.md` files for phases 42, 43, and 44
- resulting orphaned requirement evidence across all seven v6.3 requirements

This means Phase 45 should stay narrow and avoid reopening the read model or recap route architecture.

### 2. The historical-copy bug comes from a static status helper

The current portal helper exports `getRecapDayPresentation(status)`. That function only knows the status enum, not:

- the row's `logicalDate`
- the recap `referenceDate`
- whether the row is historical or today

Because of that, supporting copy for statuses like `belum_pulang`, `tidak_hadir`, `sakit`, and `izin` is hardcoded in present-day language. The history component correctly marks today with a separate "Hari ini" badge, but the helper still injects current-day wording for all rows.

### 3. Missing verification debt is bounded to phases 42-44

Phase 42 already has:

- `42-RESEARCH.md`
- `42-VALIDATION.md`
- `42-01-SUMMARY.md`
- `42-02-SUMMARY.md`
- shipped SQL and website helper artifacts

Phase 43 already has:

- `43-RESEARCH.md`
- `43-VALIDATION.md`
- `43-01-SUMMARY.md`
- `43-02-SUMMARY.md`
- `43-03-SUMMARY.md`
- shipped route and component artifacts

Phase 44 already has:

- `44-RESEARCH.md`
- `44-VALIDATION.md`
- `44-01-SUMMARY.md`
- `44-02-SUMMARY.md`
- `44-03-SUMMARY.md`
- shipped exception-state, empty/error/loading hardening artifacts

The missing work is verification synthesis, not reimplementation.

### 4. `npm run check` is not the clean phase gate for this closure

The milestone audit records repo-wide `npm run check` noise from pre-existing Supabase Edge Function typing issues outside the recap route. Phase 45 should therefore treat:

- targeted PowerShell source/doc smoke checks as the per-task fast feedback loop
- `npm run build` in the website repo as the canonical automated code gate for the recap surface

This avoids blocking the audit closure on unrelated Deno typing debt.

### 5. Phase 45 already owns requirement traceability repair

`REQUIREMENTS.md` has already been reopened and remapped so all v6.3 requirements point to Phase 45 as pending closeout work. That is a good signal: execution should finish by restoring a coherent state where the milestone audit, roadmap, and requirements all agree that:

- phases 42-44 remain the feature-delivery phases
- phase 45 is the audit-closure phase
- all seven requirements have verification evidence instead of orphaned summaries

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Astro SSR portal code | `astro@5.18.1` | Fix row-aware recap copy without changing the recap data flow | Matches the shipped website implementation and keeps the change bounded to the portal repo. |
| Existing planning docs | local repo pattern | Backfill `VERIFICATION.md` evidence for phases 42-44 | The summaries, research, validation, and source files already provide the evidence inputs. |
| PowerShell source/doc smoke checks | shell-native | Fast task-level evidence checks | Good fit for doc backfill and recap surface closure without adding new tooling. |
| Website `astro build` | package script | Canonical automated portal gate | Cleanest automated signal after the helper/history copy fix. |

### Supporting

| Tool / Pattern | Purpose | When to Use |
|----------------|---------|-------------|
| `attendance-recap-presentation.ts` | Single source of meaning for recap statuses | Extend it to accept row context instead of only status. |
| `PortalAttendanceHistorySection.astro` | Consumer of recap supporting copy | Update it to call the new date-aware presentation helper. |
| Existing phase summaries | Closeout evidence source | Use them to author 42/43/44 verification reports instead of reverse-engineering from scratch. |
| `v6.3-MILESTONE-AUDIT.md` | Final milestone audit artifact | Regenerate it after verification files land so the scorecard matches reality. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Date-aware helper input | Replace static strings in place with more neutral generic copy | Faster, but still loses row-specific accuracy and keeps the presentation contract status-only. |
| Backfill verification per shipped phase | Write one combined v6.3 verification doc only | Smaller doc set, but breaks the workflow expectation that each phase owns its own verification artifact. |
| `astro build` + targeted smoke checks | Use `npm run check` as the hard gate | Consistent with earlier docs, but currently noisy because of unrelated Edge Function typing debt. |
| Audit regeneration plus roadmap sync | Leave the old audit in place and archive with accepted debt | Faster, but contradicts Phase 45's goal and leaves the milestone blocked by process debt the roadmap explicitly wants closed. |

## Recommended Architecture

### Pattern 1: Make recap presentation row-aware, not status-only

Recommended helper shape:

- keep the existing tone/follow-up taxonomy
- add a helper that accepts `PortalRecapDay` plus `referenceDate`
- compute contextual copy such as "pada tanggal ..." or equivalent historical phrasing for past rows
- keep current-day informational states explicit without downgrading the "Hari ini" badge already rendered by the history component

This closes the audit's only product-level blocker without changing the recap RPC or route contract.

### Pattern 2: Backfill verification from shipped evidence, not memory

Each missing verification report should be authored from:

- the phase goal in `ROADMAP.md`
- the relevant `SUMMARY.md` artifacts
- the shipped source files
- the existing `VALIDATION.md` strategy
- one current automated evidence check where possible

That keeps the reports credible and aligned with the existing GSD verification format.

### Pattern 3: Close the milestone by regenerating the audit, not just adding files

The milestone remains blocked until the audit document itself reflects the new state. The final plan therefore needs to:

- create `44-VERIFICATION.md` after the copy fix is in place
- regenerate `v6.3-MILESTONE-AUDIT.md` with no orphaned requirements and no historical-copy blocker
- sync `ROADMAP.md`, `REQUIREMENTS.md`, and `STATE.md` to the post-audit state

### Pattern 4: Keep Phase 45 additive and documentation-safe

No database change is needed for this phase. The audit gap is:

- one bounded website-repo code fix
- planning and verification artifacts in this repo

That means the execution plans should stay additive and avoid any migration or Supabase mutation step.

## Do Not Hand-Roll

| Problem | Do Not Build | Use Instead | Why |
|---------|--------------|-------------|-----|
| Historical recap copy | More static status strings with softer wording | Date-aware presentation helper fed by the actual recap row | The bug is lack of row context, not tone. |
| Verification closeout | One vague summary paragraph per phase | Full `VERIFICATION.md` reports with truths, artifacts, key links, and requirement coverage | The milestone audit expects real verification artifacts. |
| Audit pass condition | Manual eyeballing of docs | Regenerated `v6.3-MILESTONE-AUDIT.md` plus smoke checks for orphan-free status | Keeps the closeout reproducible. |
| Automated gate | Repo-wide `npm run check` | Targeted smoke checks plus website `npm run build` | Avoids unrelated typing noise outside the portal recap surface. |
| Phase 45 scope | New recap data flow, new SQL, or request workflow changes | Copy fix + verification evidence + audit sync | The milestone is already feature-complete enough; Phase 45 is closure work. |

## Common Pitfalls

### Pitfall 1: Fixing the text but leaving the helper status-only

**What goes wrong:** Past rows may read slightly better, but the helper still cannot reliably express historical versus current context.

**How to avoid:** Change the helper contract so the history component passes row context (`logicalDate` and `referenceDate`) instead of only status.

### Pitfall 2: Writing verification docs without grounding them in source artifacts

**What goes wrong:** The docs read like summaries, not verification, and the milestone audit still lacks trustworthy evidence.

**How to avoid:** Use the existing verification-report format with direct references to source files, key links, and current automated checks.

### Pitfall 3: Treating `npm run check` failure as a recap blocker

**What goes wrong:** The phase gets stuck on unrelated Deno typing debt that the audit itself already classified as outside the recap route.

**How to avoid:** Use `npm run build` as the canonical automated code gate and keep source/doc smoke checks explicit.

### Pitfall 4: Regenerating the audit but not syncing roadmap/requirements state

**What goes wrong:** The milestone audit says pass, but `ROADMAP.md` or `REQUIREMENTS.md` still show a pending or orphaned story.

**How to avoid:** Make doc sync part of the final closeout plan, not an optional follow-up.

## Code Examples

### Recommended row-aware helper signature

```ts
type RecapPresentationInput = Pick<PortalRecapDay, 'logicalDate' | 'attendanceStatus'>;

function getRecapDayPresentationForDay(
  day: RecapPresentationInput,
  referenceDate: string,
): RecapDayPresentation
```

### Recommended audit smoke check

```powershell
$audit = Get-Content '.planning/v6.3-MILESTONE-AUDIT.md' -Raw
if ($audit -match 'gaps_found' -or $audit -match 'orphaned') {
  throw 'v6.3 audit still blocked'
}
```

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | PowerShell source/doc smoke checks plus Astro `npm run build` in the website repo |
| Config file | `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\package.json` |
| Quick run command | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap-presentation.ts','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro' -Pattern 'logicalDate','referenceDate','getRecapDayPresentationForDay' | Measure-Object"` |
| Full suite command | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` |
| Estimated runtime | ~30 seconds |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ATTN-05 | Historical follow-up rows describe the correct workday instead of generic current-day wording | source smoke + build | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap-presentation.ts','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro' -Pattern 'getRecapDayPresentationForDay','logicalDate','referenceDate' | Measure-Object"` | Missing in Phase 45 |
| ATTN-02, ATTN-03 | Phase 42 has explicit verification evidence for the recap contract and logical-day handling | doc smoke | `powershell -Command "Test-Path '.planning/phases/42-attendance-recap-read-model/42-VERIFICATION.md'; Select-String -Path '.planning/phases/42-attendance-recap-read-model/42-VERIFICATION.md' -Pattern 'ATTN-02','ATTN-03','get_portal_attendance_recap','overnight' | Measure-Object"` | Missing in Phase 45 |
| ATTN-01, ATTN-04, PORT-03 | Phase 43 has explicit verification evidence for the recap route and portal-shell surface | doc smoke | `powershell -Command "Test-Path '.planning/phases/43-portal-attendance-recap-surface/43-VERIFICATION.md'; Select-String -Path '.planning/phases/43-portal-attendance-recap-surface/43-VERIFICATION.md' -Pattern 'ATTN-01','ATTN-04','PORT-03','/portal/attendance' | Measure-Object"` | Missing in Phase 45 |
| PORT-04 and final closeout | Phase 44 and the v6.3 audit both show a closed milestone with no orphaned blockers | doc smoke | `powershell -Command "$audit = Get-Content '.planning/v6.3-MILESTONE-AUDIT.md' -Raw; if ($audit -match 'gaps_found' -or $audit -match 'orphaned') { throw 'audit blocked' }"` | Missing in Phase 45 |

### Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| A historical `belum_pulang` or `tidak_hadir` row reads as a past-day issue instead of sounding like it is happening today | ATTN-05 | Copy accuracy is ultimately a human readability judgment | Open `/portal/attendance` with one employee whose recent history includes a past unresolved day, then confirm the supporting sentence names the row's date or clearly indicates it is historical. |
| Portal recap empty/error/loading states remain understandable after the copy fix | PORT-04 | Needs real portal navigation and page-state transitions | On a phone-width browser, load `/portal/attendance`, then exercise empty/error/retry flows and confirm the shell and state panels still behave as before. |
| The recap route, summary counts, and history still match the shipped portal shell flow after audit closure | ATTN-01, ATTN-04, PORT-03 | Requires browser navigation and realistic seeded data | Navigate between `/portal` and `/portal/attendance`, confirm the shell context remains intact, and spot-check that month summary counts still agree with the visible current-month rows. |

## Sources

### Primary (HIGH confidence)

- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\ROADMAP.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\REQUIREMENTS.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\STATE.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\v6.3-MILESTONE-AUDIT.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\42-attendance-recap-read-model\42-RESEARCH.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\42-attendance-recap-read-model\42-01-SUMMARY.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\42-attendance-recap-read-model\42-02-SUMMARY.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\43-portal-attendance-recap-surface\43-RESEARCH.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\43-portal-attendance-recap-surface\43-03-SUMMARY.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\44-portal-exception-states-hardening\44-RESEARCH.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\44-portal-exception-states-hardening\44-03-SUMMARY.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\sql\phase_42_portal_attendance_recap_20260323.sql`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\lib\portal\attendance-recap-presentation.ts`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\components\portal\PortalAttendanceHistorySection.astro`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\pages\portal\attendance.astro`

## Metadata

**Confidence breakdown:**

- Audit scope: HIGH - the blockers are already listed explicitly in the milestone audit.
- Verification backfill path: HIGH - phases 42-44 already have summaries, validation docs, and shipped source artifacts.
- Final copy wording: MEDIUM - the implementation direction is clear, but final phrasing still needs one human readability pass during execution.

**Research date:** 2026-03-23
**Valid until:** 2026-04-22
