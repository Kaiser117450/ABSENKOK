# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.1 — Bug Fix + Edge Cases + Features

**Shipped:** 2026-03-05
**Phases:** 11 | **Plans:** 24 | **Timeline:** 5 days (Feb 28 → Mar 5)

### What Was Built
- Fixed all 5 production bugs in Rekap Harian and kiosk scan cycle
- Built persistent floating pill overlay (Dynamic Island-style) with typed state machine
- Created professional branded PDF reports with color-coded status tables
- Redesigned kiosk idle screen with 3-layer ambient animation and premium typography
- Systematized admin UI with reusable widget library across all screens
- Fixed schedule Supabase persistence with bulk assign UI
- Added sakit/izin direct input with history management
- Built employee badge system with solid/gradient/glow ring rendering
- Fixed kiosk logout resilience after cold restart

### What Worked
- **Rapid execution:** 11 phases in 5 days — averaging 2+ phases/day
- **Bug-first approach:** Starting with production bugs built confidence and revealed patterns used by later phases
- **Phase dependency chaining:** Phase 1's DailySummary model was reused across Phases 2, 4, 8.1, and 10
- **Gap closure workflow:** Audit → plan-milestone-gaps → execute was effective for catching unsatisfied requirements
- **Widget library payoff:** Phase 7's reusable components (AppCard, ShimmerSkeleton, AppToast) accelerated Phases 10-12

### What Was Inefficient
- **Scattered PDF services:** Two PDF service files (pdf_report_service.dart + pdf_service.dart) created confusion — should have been one from the start
- **Phase 4 Plan 02 abandoned:** Wire Export PDF plan was superseded by Phase 08.1 but never formally marked — leaves a phantom incomplete plan in the archive
- **Phase 5 & 9 never executed:** Original roadmap milestones (v1.2-v1.5) were planned but all work collapsed into v1.1 — milestone structure was premature
- **Missing VERIFICATION.md:** Only 1/11 phases had formal verification — most verified only by commit evidence or visual inspection
- **Missing VALIDATION.md:** Only 2/11 phases had automated test validation — test coverage is concentrated in a few areas

### Patterns Established
- **KioskBackgroundService.stop() per-step isolation:** Each cleanup step in its own try-catch to prevent cascade failure. This pattern should be used for all multi-step cleanup sequences.
- **Supabase-first with SQLite fallback:** Try cloud, cache locally, fallback on network error. Standard for all future Supabase reads.
- **08:00 time anchor for backdated records:** Sakit/izin entries use 08:00 local time to ensure correct Rekap Harian date bucketing.
- **BadgeService singleton with in-memory cache:** Good pattern for small reference tables (<50 rows). Fetch once, cache in Map.
- **AppToast over raw SnackBar:** Consistent toast notifications via toastification package.

### Key Lessons
1. **Don't over-milestone early:** v1.2-v1.5 milestones were planned prematurely. All work ended up shipping as v1.1. Better to plan one milestone at a time.
2. **Verification debt compounds:** Skipping VERIFICATION.md on early phases made the audit harder later — the audit had to rely on commit evidence instead of structured verification.
3. **Bug fixes reveal architecture:** The Rekap Harian bugs (Phase 1) exposed the need for the DailySummary model extraction, which became the foundation for PDF reports and sakit/izin rendering.
4. **Inserted phases (08.1) work well:** The decimal phase pattern effectively handles urgent mid-milestone work without renumbering.
5. **Singleton services need cache invalidation:** BadgeService works now but will need cache invalidation if badge data changes frequently in the future.

### Cost Observations
- Model mix: 100% quality profile (opus-level)
- Sessions: ~10-12 sessions across 5 days
- Notable: Average plan execution took 5-10 minutes — very efficient for feature-complete implementations

---

## Milestone: v2.0 — Admin Tools + Live Activity

**Shipped:** 2026-03-12
**Phases:** 4 (13-16) | **Plans:** 9 | **Timeline:** ~1 day

### What Was Built
- Soft-archive karyawan with Riwayat Karyawan history page (soft-delete pattern)
- Batch CSV import wizard (4-step: upload → validate → preview → import) with pure-function validation
- SQL scripts for Kepala Gerai role promotion (no code changes needed)
- Persistent live activity pill with break detection, fun facts rotation, and displayLabel system
- 56+ new unit tests covering CSV service, live content provider, overlay model

### What Worked
- **Injectable callbacks for testability:** LiveContentProvider with callbacks instead of direct state access = clean unit testing
- **displayLabel backward compat:** Empty string falls back to enum label — no migration needed for existing data
- **Pure-function CSV validation:** CsvImportService stateless validate() = trivially testable without Supabase

### What Was Inefficient
- **Phase 15 SQL-only:** No PLAN/SUMMARY files — work was ad-hoc SQL scripts. For structured tracking, even SQL-only phases should have a minimal PLAN.md.

### Patterns Established
- **Injectable callback pattern:** For any service that needs testable side-effects, pass callbacks at construction time rather than reading from a singleton.
- **4-step import wizard:** Upload → Validate → Preview → Confirm is the right UX pattern for destructive bulk operations.

### Key Lessons
1. **SQL-only phases still need structure:** Phase 15 delivered real value but left no traceable artifacts. A 5-line PLAN.md would have been enough.
2. **Testability-first on services:** LiveContentProvider's injectable design made 56 tests easy to write. Design for testability upfront.

### Cost Observations
- Model mix: 100% quality profile
- Sessions: ~3-4 sessions
- Notable: v2.0 shipped in a single day — tight scope made execution very fast

---

## Milestone: v3.0 — Schedule Grid + Landing Website

**Shipped:** 2026-03-13
**Phases:** 3 (17-19) | **Plans:** 6 | **Timeline:** 1 day

### What Was Built
- ScheduleTableView widget with `two_dimensional_scrollables` — pinned employee column + day headers, diagonal scroll, color-coded shift chips, 6-type legend
- shift_scheduler_screen.dart refactored: removed 282 lines of dual-ListView scroll sync, replaced with widget composition
- ABSENKOK marketing website (Astro 5 + Tailwind v4) — zero JS, Bahasa Indonesia, SEO + sitemap, Vercel deployed
- 6 content sections: Header, Hero, Features (4 cards), HowItWorks (3 steps), Download CTA, Footer
- Real app screenshots replacing CSS mockup in Hero — 5 WebP screenshots via Astro `<Image>`
- About/Architecture section with 4 inline SVG tech icons (Flutter, Supabase, NFC, Android)

### What Worked
- **two_dimensional_scrollables was the right call:** Pinned row+column out-of-the-box, no custom scroll controller hacking needed
- **Top-level cell builder functions:** Non-method functions for cell building kept the widget file flat and testable
- **Separate repo for website:** Zero coupling to Flutter codebase — website can deploy independently, no shared pubspec/gradle complexity
- **Astro 5 zero-JS constraint:** Forced correct architecture — all state in HTML, no JS hydration footgun

### What Was Inefficient
- **Phase 19 was underplanned:** WEB-P requirements were added at the end without updating the traceability table — left "Planned" status in table after completion
- **No device testing for schedule grid:** ScheduleTableView looks correct in code but hasn't been tested on physical Android tablet — pinned scroll behavior needs device verification

### Patterns Established
- **Cell builder extraction:** For complex data grids, extract each cell type as a top-level function (corner, header, employee, shift, _chip). Easy to test and compose.
- **Astro <Image> for screenshots:** Import images from src/assets/images/ for automatic WebP conversion + srcset optimization. Don't put screenshots in public/.
- **CSS-first Tailwind v4:** No tailwind.config.js — all config in global.css @theme block. Simpler, fewer files.

### Key Lessons
1. **Phase 19 added mid-stream:** WEB-P requirements were added after the roadmap was created. This is fine but the traceability table should be updated at plan creation time, not just when requirements are defined.
2. **Device testing is a separate phase:** Schedule grid and website both need on-device/browser verification that wasn't done in this milestone. Add explicit verification plans.
3. **Astro website scope could grow:** About section is compelling but raises the question of future blog posts, pricing, etc. Explicitly defer these in requirements to avoid scope creep.

### Cost Observations
- Model mix: 100% quality profile
- Sessions: ~3-4 sessions
- Notable: Website phases (18-19) were extremely fast to execute — Astro components are very predictable to generate

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Timeline | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.1 | 5 days | 11 | Initial release — all planned milestones collapsed into one |
| v2.0 | 1 day | 4 | Tight scope = very fast execution; SQL-only phase lacks artifacts |
| v3.0 | 1 day | 3 | First cross-domain milestone (Flutter + website); phase added mid-stream |

### Cumulative Quality

| Milestone | Tests | Coverage | Tech Debt Items |
|-----------|-------|----------|----------------|
| v1.1 | 71 | Partial (concentrated in overlay, PDF, schedule) | 8 items |
| v2.0 | 127+ | Extended (CSV, live content, overlay model) | 9 items |
| v3.0 | 127+ | Unchanged (no new Flutter tests) | 10 items (+ schedule grid device testing needed) |

### Top Lessons (Verified Across Milestones)

1. Plan one milestone at a time — premature multi-milestone roadmaps waste context
2. Verification debt compounds — always create VERIFICATION.md even if brief
3. Injectable dependencies (callbacks, not singletons) = fast unit tests
4. Top-level functions beat methods for widget extraction — less context binding, more composable
5. Device verification is a separate concern — add it as an explicit plan, not an afterthought
