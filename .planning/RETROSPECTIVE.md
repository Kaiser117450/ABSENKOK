# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v5.0 — Observability & Recovery

**Shipped:** 2026-03-20
**Phases:** 4 (27–30) | **Plans:** 5 | **Timeline:** 1 day

### What Was Built
- HeartbeatService — 15-min background ping with battery, charging state, app version, pending sync count
- Sentry crash reporting — unhandled Dart + native exceptions, NFC noise filtered, background isolate covered
- KioskDiagnosticsScreen — device info, connectivity, force sync with toast feedback (long-press logo entry)
- Sync indicator strip on kiosk idle screen — amber strip animates in when pending > 0
- Admin dashboard "Status Kiosk" section — per-outlet online/offline, battery (<20% warning), sync badge
- Production Supabase migration: 5 heartbeat columns added to `outlets` table

### What Worked
- Plans were well-specified with exact interfaces — executors needed minimal inference
- Single-plan phases executed in one shot with zero rework
- Supabase MCP tool made the production migration trivial

### What Was Inefficient
- Rate limit hit between phases 29 and 30 — added a pause
- Verifier was skipped for phase 29 due to rate limit, re-run next session was seamless

### Patterns Established
- Diagnostics entry via long-press on brand logo — zero UI footprint, ops-friendly
- Sync indicator as a SlideTransition strip (not modal/alert) — non-intrusive, auto-hides
- KioskHealthCard: status dot + outlet name + battery indicator + sync badge in one row

### Key Lessons
- Phase 27 had pending migration SQL pre-written — applying it in Phase 30 was instant via MCP
- Sentry NFC noise filter is critical: without it, every lost tag floods Sentry quota
- Background isolate heartbeat is the right architecture: never touches main thread, survives minimize

---

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

## Milestone: v4.0 — Smart Attendance + Admin Dashboard

**Shipped:** 2026-03-19
**Phases:** 4 (23-26) | **Plans:** 11 | **Timeline:** 2 days (Mar 18 → Mar 19)

### What Was Built
- Fixed NFC double-scan crash in employee registration flow (race condition on rapid scan)
- Built AnalyticsService with 3 RPC methods — attendance rate card, overtime flagging, missing clock-out batched notification
- Smart pattern detection with `compute()` isolate (first use) — median arrival times per day-of-week, late notification (>5 min threshold)
- StreakService tracking consecutive on-time attendance with noon-rule logical days
- ChartDashboardScreen with fl_chart — donut chart, weekly bar chart, streak leaderboard, overtime alerts
- Cross-outlet attendance comparison (admin-only grouped bar chart)
- Kiosk scan result displays current streak; StreakBadgeService auto-awards at 7/30/90-day milestones
- CreateAdminScreen — 3-state UI (form→loading→success), WhatsApp deep link sharing, PDF audit trail
- AdminOnboardingService + Supabase Edge Function `create-admin-user` (service_role server-side)
- Edge Function deployed via Supabase MCP tool directly from Claude session

### What Worked
- **Wave-based parallelization:** Plans 02+03 merged into Plan 01 (all touching same .dart file) — avoided merge conflicts entirely
- **Supabase MCP deployment:** Edge Function deployed without leaving the coding session — zero CLI friction
- **compute() isolate for pattern detection:** Clean pattern established — heavy computation never touches the main thread
- **Phase merging for simple plans:** Plans 02+03 (WhatsApp + PDF) were small enough that merging into Plan 01 saved a full wave cycle
- **gsd-tools milestone complete:** CLI handled roadmap/requirements archival automatically — reduced manual steps

### What Was Inefficient
- **REQUIREMENTS.md checkboxes not auto-updated:** After Phase 26 execution, ADMIN-01..04 were still `[ ]` — required manual fix at milestone completion
- **ROADMAP.md Phase 25 plans showed `[ ]`:** Plans 25-00, 25-01, 25-02 had unchecked boxes despite having SUMMARY.md files — roadmap analyze showed disk_status complete correctly but markdown was stale
- **Phase 24 had 0 plan files on disk:** Plans existed as ROADMAP.md descriptions but not as physical PLAN.md files — gsd-tools reported 0 plans for phases 24-25

### Patterns Established
- **Edge Function via MCP:** `mcp__claude_ai_Supabase__deploy_edge_function` deploys directly — no Supabase CLI, no terminal friction
- **compute() isolate pattern:** Use `compute(topLevelFunction, args)` for CPU-heavy analytics (pattern detection, streak calculations). Always cache results with TTL.
- **3-state screen pattern:** `enum _ScreenState { form, loading, success }` + `AnimatedSwitcher` — clean, reusable pattern for wizard-style flows
- **Merge sibling plans:** When 2+ plans modify the same file in sequence, merge them into one wave to avoid file conflicts

### Key Lessons
- **MCP > CLI for deployment:** Supabase Edge Function deployed in seconds via MCP — recommend for all future Edge Function deployments
- **service_role security:** Always verify `grep -r "service_role" lib/` returns only comments — critical for APK security
- **Checkbox hygiene:** Update REQUIREMENTS.md traceability immediately after each phase execution, not at milestone close
- **fl_chart integration:** Add `dispose()` for all chart controllers; use `AutomaticKeepAliveClientMixin` on chart screens to prevent rebuild on tab switch

---

## Milestone: v6.0 — Multi-Outlet & Multi-Device Control

**Shipped:** 2026-03-22
**Phases:** 6 (31-36) | **Plans:** 12 | **Timeline:** 3 days (Mar 20 → Mar 22)

### What Was Built
- Persistent installation UUIDv4 stored in `SharedPreferences`, reused across logout and re-setup
- `kiosk_devices` heartbeat pipeline with nickname/archive RPCs and per-device admin dashboard cards
- Full-admin Central Dashboard with chain-wide KPIs, outlet drilldown, and role-aware routing
- Gap-closure phases for rollout evidence, acceptance validation, and milestone requirement synchronization to `7/7 complete`

### What Worked
- Splitting implementation phases (31-33) from closure phases (34-36) made rollout and validation debt explicit instead of leaving it hidden in summaries
- Acceptance packets in `34-VALIDATION.md`, `35-VALIDATION.md`, and `36-VALIDATION.md` gave the milestone a consistent verification structure
- Additive Supabase migrations and RPCs kept the production rollout safe while expanding the device-health model

### What Was Inefficient
- The saved audit file became stale once phases 34-36 closed the gaps; archival would have been cleaner with a fresh audit rerun before closeout
- Auto-approved human-verify checkpoints pushed too much weight onto structural evidence instead of fresh live proof capture

### Patterns Established
- Treat rollout evidence as a first-class phase whenever database changes require operator confirmation
- Close validation debt with dedicated acceptance phases rather than burying it inside implementation work
- Role-aware dashboard routing is easy to test when loaders and navigation hooks are injectable

### Key Lessons
1. If an audit fails on evidence, add explicit gap-closure phases immediately instead of carrying the debt forward informally.
2. Keep `REQUIREMENTS.md` synchronized during closure work so milestone readiness is visible without rereading every summary.
3. Archive only after `PROJECT.md`, `ROADMAP.md`, `STATE.md`, and the milestone archive all agree on what actually shipped.

---

## Milestone: v6.1 — Employee Portal

**Shipped:** 2026-03-23
**Phases:** 3 (37-39) | **Plans:** 8 | **Timeline:** 2 days

### What Was Built
- Employee portal provisioning contract and initial admin provisioning flow
- Password-based name-search login on the Astro website
- Protected employee portal shell with server-side identity resolution
- Employee schedule visibility for today, this week, and next week
- Mobile-first portal UX with empty, not-linked, and error states
- Hardened authenticated RPC read path for the shipped portal backend

### What Worked
- Tight milestone scope kept the portal release small enough to ship quickly
- Cross-repo split remained clear: Flutter repo kept planning and app state, Astro repo carried the website implementation
- The later hardening pass improved portal security without changing employee UX

### What Was Inefficient
- Verification discipline broke again: Phase 37 had no verification artifact, and 38/39 validation files stayed draft
- Planning summaries drifted behind the shipped website implementation after the hardening pass
- Milestone closeout required a proceed-anyway decision because the archive trail lagged the actual implementation

### Patterns Established
- Employee self-service belongs in the separate Astro portal, not in kiosk or admin surfaces
- Portal auth and schedule reads should stay server-side and employee-scoped
- When work spans a second repo, planning artifacts need a mandatory backfill step before milestone archive

### Key Lessons
1. Cross-repo milestones need explicit verification ownership; otherwise the implementation ships faster than the planning evidence.
2. Security hardening landed smoothly because the portal already had a clean server-side boundary.
3. Accepting verification debt at archive time is possible, but it should stay exceptional and documented.

### Cost Observations
- Model mix: balanced profile with targeted manual verification
- Sessions: short burst across 2 days
- Notable: implementation moved faster than archive hygiene; closeout time was spent on traceability debt, not feature work

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Timeline | Phases | Key Change |
|-----------|----------|--------|------------|
| v6.1 | 2 days | 3 | First employee portal milestone; implementation shipped fast but verification/traceability lagged |
| v6.0 | 3 days | 6 | Implementation milestone expanded with explicit rollout/acceptance closure phases before archive |
| v1.1 | 5 days | 11 | Initial release — all planned milestones collapsed into one |
| v2.0 | 1 day | 4 | Rapid iteration — admin tools + live activity |
| v3.0 | 1 day | 3 | Website + schedule grid — separate Astro repo pattern |
| v3.1 | 1 day | 3 | Biometric + badge polish + production release |
| v4.0 | 2 days | 4 | Analytics + dashboard + Edge Function MCP deployment |
| v2.0 | 1 day | 4 | Tight scope = very fast execution; SQL-only phase lacks artifacts |
| v3.0 | 1 day | 3 | First cross-domain milestone (Flutter + website); phase added mid-stream |

### Cumulative Quality

| Milestone | Tests | Coverage | Tech Debt Items |
|-----------|-------|----------|----------------|
| v6.1 | Website build checks plus pending manual portal validation | Partial (requirements implemented, audit passed only by proceed-anyway decision) | 4 items |
| v6.0 | Targeted unit/widget tests plus validation packets | Extended (device identity, kiosk devices, analytics/routing, milestone traceability) | 4 items |
| v1.1 | 71 | Partial (concentrated in overlay, PDF, schedule) | 8 items |
| v2.0 | 127+ | Extended (CSV, live content, overlay model) | 9 items |
| v3.0 | 127+ | Unchanged (no new Flutter tests) | 10 items (+ schedule grid device testing needed) |

### Top Lessons (Verified Across Milestones)

1. Plan one milestone at a time — premature multi-milestone roadmaps waste context
2. Verification debt compounds — always create VERIFICATION.md even if brief
3. Injectable dependencies (callbacks, not singletons) = fast unit tests
4. Top-level functions beat methods for widget extraction — less context binding, more composable
5. Device verification is a separate concern — add it as an explicit plan, not an afterthought
6. Cross-repo milestones need a deliberate backfill step for verification and planning artifacts before archive
