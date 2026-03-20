# Milestones
## v5.0 Observability & Recovery (Shipped: 2026-03-20)

**Phases completed:** 4 phases, 5 plans, 3 tasks

**Key accomplishments:**
- (none recorded)

---

## v4.0 Smart Attendance + Admin Dashboard (Shipped: 2026-03-19)

**Phases completed:** 2 phases, 5 plans, 0 tasks

**Key accomplishments:**
- (none recorded)

---

## v3.0 Schedule Grid + Landing Website (Shipped: 2026-03-13)

**Phases:** 17-19 (3 phases, 6 plans)
**Timeline:** 2026-03-13 (single session)
**Git range:** feat(17-01) → feat(19-02)

**Key accomplishments:**
1. Built ScheduleTableView widget with `two_dimensional_scrollables` — pinned employee column + day headers, 5 cell builder functions, 6-type legend widget
2. Refactored shift_scheduler_screen.dart — removed 282 lines of dual-ListView scroll sync, replaced with clean ScheduleTableView + ScheduleLegend composition
3. Scaffolded ABSENKOK landing website (Astro 5 + Tailwind v4) — zero-JS static output, Bahasa Indonesia copy, SEO meta + sitemap, Vercel deployed
4. Built 6 content sections: Header (sticky), Hero (CSS mockup), Features (4 cards + icons), HowItWorks (3 steps), Download CTA, Footer (Akmal credit)
5. Replaced CSS mockup with real app screenshot in Hero — migrated 5 WebP screenshots via Astro `<Image>` component with automatic optimization
6. Added About/Architecture section with Flutter/Supabase/NFC/Android inline SVG icons and 3-card layout (Tech Stack, Dev Story, Deployment)

### Delivered
Schedule management UI upgraded to proper week-view grid. ABSENKOK marketing website live on Vercel with real screenshots and architecture story.

---


## v2.0 Admin Tools + Live Activity (Shipped: 2026-03-12)

**Phases:** 13-16 (4 phases)
**Requirements:** 17 (ARCH×6, CSV×6, ADMIN×1, LIVE×4)

**Key accomplishments:**
1. Soft-archive karyawan with Riwayat Karyawan history page
2. Batch CSV import for multi-outlet employee onboarding
3. Quick SQL setup for promoting Kepala Gerai admin
4. Persistent live activity pill outside app (break status, fun facts)

---

## v1.1 Bug Fix + Edge Cases + Features (Shipped: 2026-03-05)

**Phases completed:** 11 phases (1-4, 6-8, 8.1, 10-12), 24 plans executed
**Timeline:** 5 days (2026-02-28 → 2026-03-05)
**Codebase:** 19,124 LOC Dart (47 files) | 98 commits (38 feat, 12 fix, 42 docs)
**Tests:** 71/71 GREEN
**Git range:** initial commit → 280a0e5

**Key accomplishments:**
1. Fixed all 5 production bugs: Rekap Harian sakit/izin display, --:-- pagination, cross-day shift grouping, belum pulang state, 24h outlet shift cycle
2. Built persistent floating pill overlay (Dynamic Island-style) with idle/event state machine, premium dark UI, and guided OEM permission flow
3. Created professional PDF attendance reports with branded summary page, color-coded status tables, and insight cards
4. Redesigned kiosk idle screen with 3-layer ambient animation, gradient NFC ring, monospace clock, and brand logo
5. Systematized admin UI with reusable widget library (AppCard, ShimmerSkeleton, AppBadge, AppToast) across all admin screens
6. Fixed schedule system Supabase persistence with bulk assign UI and Supabase-first data flow
7. Added direct sakit/izin input with history list, edit/delete, and 30-day backdating
8. Built employee badge system with solid/gradient/glow ring rendering, emoji chips, and admin CRUD management
9. Fixed kiosk logout resilience — stop() individually isolated, 5s timeout, guaranteed session clear

### Known Gaps
- **REQ-M5-02** (Schedule UI Rewrite): Bulk assign implemented and functional. Full grid redesign deferred to future milestone. Existing grid works for current scale (4 outlets, 14 employees).

### Delivered
NFC attendance kiosk app is production-ready with accurate reports, persistent overlay notifications, premium kiosk UI, Supabase-synced schedules, sakit/izin management, employee badges, and resilient logout. Running at 4 Ayam Guling Enakko outlets.

---

