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

## Cross-Milestone Trends

### Process Evolution

| Milestone | Timeline | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.1 | 5 days | 11 | Initial release — all planned milestones collapsed into one |

### Cumulative Quality

| Milestone | Tests | Coverage | Tech Debt Items |
|-----------|-------|----------|----------------|
| v1.1 | 71 | Partial (concentrated in overlay, PDF, schedule) | 8 items across 5 phases |

### Top Lessons (Verified Across Milestones)

1. Plan one milestone at a time — premature multi-milestone roadmaps waste context
2. Verification debt compounds — always create VERIFICATION.md even if brief
