# Milestones

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

