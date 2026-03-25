# Milestones
## v7.1 Security Hardening (Shipped: 2026-03-25)

**Phases completed:** 4 phases, 10 plans
**Timeline:** 2026-03-25 (single day)

**Key accomplishments:**
1. Hardened kiosk device activation and heartbeat to bind persistent UUIDs at activation time, preventing spoofing and unscoped writes.
2. Fail-closed seven privileged analytics RPCs and removed admin trust in writable metadata or stale remembered roles.
3. Minimized portal search exposure (3-char min, 5-result cap, chooser-only DTO) while preserving passwordless employee entry.
4. Fail-closed portal account recovery to only restore proven `employee_portal` identities with explicit employee bindings.
5. Created canonical operator rollout checklist with ordered additive SQL for live Supabase deployment.
6. Documented accepted risk register for passwordless portal boundary and local-only logout decisions.

### Delivered
Security hardening closes the non-passwordless Codex Security findings across kiosk device boundaries, admin session trust, and portal surface minimization — with additive SQL rollout, acceptance automation, and an explicit risk register for the retained passwordless portal flow.

---

## v7.0 Android Release Hardening (Shipped: 2026-03-25)

**Phases completed:** 5 phases, 12 plans, 20 tracked tasks
**Timeline:** 2026-03-23 → 2026-03-25
**Git range:** `4449d4e` → `71ea220`

**Key accomplishments:**
1. Restored the canonical Windows release lane and aligned tracked Android metadata to `7.0.0+8013`.
2. Published a tracked Java 21 / Flutter / Gradle contract plus a fail-fast release preflight lane.
3. Replaced debug signing with a private upload-key scaffold and a single `tool/release_build.ps1` packaging entrypoint.
4. Re-centered release retention on a canonical staged APK with manifest, mapping, smoke evidence, and optional bundle output.
5. Documented the PowerShell 5.1 operator runbook and closed acceptance on a real Android device.
6. Rebuilt the final distributable APK with `-Obfuscate`, retained Dart symbol files plus `mapping.txt`, and uploaded `ABSENKOK-v7.0.0+8013.apk` to GitHub Release `v7.0.0`.

### Known Gaps
- Archived without a dedicated `v7.0-MILESTONE-AUDIT.md`; closeout proceeded because all 9 milestone requirements and all 12 plan summaries were complete.

### Notes
- Final published asset digest: `sha256:600eb099456f981a3a4b38af083d7f676c7dce1aed5db96b17aa9141ac0dfab1`.
- GitHub release upload in this environment required `gh release upload` fallback because the app automation could not read the local staged artifact path directly.
- Local release bootstrap still depends on private `android/key.properties` and upload keystore files staying machine-local and untracked.

### Delivered
ABSENKOK now has a reproducible local Android release lane with private signing, APK-first artifact staging, smoke evidence, retained debug artifacts, and a published obfuscated v7.0 GitHub release asset.

---

## v6.3 Employee Attendance Recap (Shipped: 2026-03-23)

**Phases completed:** 4 phases, 11 plans, 20 tracked tasks
**Timeline:** 2026-03-23 → 2026-03-23
**Git range:** `0a494ed` → `8f32b6e`

**Key accomplishments:**
1. Added an employee-scoped portal attendance recap RPC and supporting index with logical-day-aware overnight repair.
2. Derived month-to-date summary counts and recent logical-day history from one typed recap dataset in the Astro portal.
3. Shipped a dedicated attendance entry point and `/portal/attendance` surface inside the existing employee portal shell.
4. Centralized exception-state presentation so follow-up gaps are explicit while current-day in-progress states stay informational.
5. Hardened recap empty/error/loading states and fixed historical row copy so past days no longer read as "hari ini".
6. Closed the v6.3 audit with verification artifacts for phases 42-44 and applied the recap RPC/index to production Supabase during closeout.

### Notes
- Production now has `get_portal_attendance_recap` and `idx_attendance_logs_employee_recap` after migration `phase_42_portal_attendance_recap_20260323` was applied during closeout.
- Repo-wide `npm run check` in `absenkok-website` still reports pre-existing Deno edge-function typing noise outside the portal recap surface.
- `followUpCount` derives from `recap.days` (14-day history horizon) while summary chips stay month-scoped; accepted as minimal overlap.

### Delivered
Employee portal now includes a phone-friendly attendance recap with month-to-date summary counts, recent logical-day history, explicit follow-up labeling, and verified closeout evidence.

---

## v6.2 Dashboard & Report Foundation (Shipped: 2026-03-23)

**Phases completed:** 2 phases, 0 formal plans, 0 tracked tasks
**Timeline:** 2026-03-23 → 2026-03-23
**Git range:** `52bb5c1` → `e6c2902`

**Key accomplishments:**
1. Restored the classic admin dashboard as the full-admin default landing surface while preserving role-based outlet scoping for kepala gerai.
2. Moved chain-wide ringkasan jaringan and status per gerai into a dedicated full-admin screen reachable from the dashboard.
3. Replaced the admin dashboard utensil mark with the intended Enakko logo asset and tracked that asset in the Flutter repo.
4. Hardened Rekap Harian PDF exports so large datasets keep rendering per-employee summary content.
5. Replaced percentage-based attendance summaries with concrete counts for masuk, tidak hadir, and belum pulang.

### Known Gaps
- Archived without a dedicated `v6.2-MILESTONE-AUDIT.md`.
- Phases 40-41 were executed as a rapid foundation pass without formal PLAN/SUMMARY artifacts.
- Initial milestone drafting referenced `assets/images/logo_enakko.png`; the shipped admin logo path is `src/assets/images/logogoenakko.png`.

### Delivered
Admin dashboard flow restored, chain-wide network visibility isolated into its own screen, branding corrected, and PDF exports hardened before the next feature milestone.

---

## v6.1 Employee Portal (Shipped: 2026-03-23)

**Phases completed:** 3 phases, 8 plans, 15 tasks
**Timeline:** 2026-03-22 → 2026-03-23
**Git range:** `0082be6` → `3d9d3f2`

**Key accomplishments:**
1. Added a deterministic employee portal account contract with indexed name search and server-side provisioning for existing staff records.
2. Extended the Astro website with password-based employee login, SSR auth guards, and server-side employee identity resolution.
3. Shipped an employee-scoped portal schedule read model with current-week visibility, overnight handling, and mobile-first portal surfaces.
4. Delivered portal state handling for loading, empty, not-linked, and error cases plus portal-only logout behavior.
5. Hardened the shipped portal read path in the website repo around authenticated RPCs, current-plus-next-week schedule visibility, and status-tinted schedule cards.

### Known Gaps
- Archived with audit status `gaps_found` because Phase 37 has no verification artifact and Phase 38/39 validation artifacts remained draft at closeout.
- Planning summaries for Phase 37-38 lag the shipped website hardening (`get_portal_schedule_overview`, RPC ACL tightening, and portal UI follow-up tweaks).

### Delivered
First employee-facing ABSENKOK web portal: admin-provisioned password login, employee-scoped schedule visibility, mobile-first portal UX, and hardened server-side schedule reads.

---

## v6.0 Multi-Outlet & Multi-Device Control (Shipped: 2026-03-22)

**Phases completed:** 6 phases, 12 plans, 33 tasks
**Timeline:** 2026-03-20 → 2026-03-22
**Git range:** `6cda407` → `96aaaef`

**Key accomplishments:**
1. Added persistent installation UUIDs and moved device heartbeats into `kiosk_devices` for true per-device tracking.
2. Rebuilt the admin device-health surface around multi-device cards with nickname and archive actions.
3. Added a full-admin Central Dashboard with chain-wide KPIs, outlet drilldown, and role-aware routing.
4. Captured rollout proof for the phase 31-33 SQL changes and turned validation debt into explicit closure work.
5. Closed milestone coverage at `7/7` requirements across `HEALTH-01..05` and `ADMIN-01..02`.

### Notes
- Archived audit artifact predates the final gap-closure phases; milestone closure used the updated requirements and approved validation state without rerunning a final audit.

### Delivered
Chain-wide admin control with per-device kiosk tracking, central dashboard visibility, and archived rollout/validation evidence for v6.0.

---

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

