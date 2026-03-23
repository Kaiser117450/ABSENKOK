# PROJECT.md — Absensi Enakko

## What This Is
NFC attendance kiosk app for **Ayam Guling Enakko** restaurant chain — Android tablet deployed
at each outlet. Replaces paper attendance. Features: real-time reports with PDF/CSV export,
persistent floating pill overlay (Dynamic Island-style), employee badge system, Supabase-synced
schedule grid (week-view TableView), employee archive/restore, batch CSV import, and premium
kiosk UI. Marketing website at absenkok.vercel.app now also hosts a protected employee portal
for self-service schedule visibility. Admin can manage employees, attendance, schedules, and
badges. Kiosk runs unattended 24/7; NFC tap takes < 2 seconds.

## Core Value
Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.

## Current State

**Shipped:** v6.2 Dashboard & Report Foundation (2026-03-23)
**Running at:** 4 Ayam Guling Enakko outlets, 14 employees
**Web surfaces:** marketing site + protected employee portal on the Astro website
**Admin surfaces:** classic admin dashboard restored as the default full-admin landing surface; chain-wide network visibility stays on its own full-admin screen
**Reporting:** Rekap Harian PDF now keeps summary content on large exports and shows count-based attendance metrics
**Codebase:** ~28,400 tracked LOC Dart across 102 tracked files plus the separate Astro website repo and portal-specific Supabase RPCs
**Archive note:** v6.2 archived with accepted planning debt; no dedicated milestone audit or phase SUMMARY artifacts were produced for phases 40-41

## Current Milestone: v6.3 Employee Attendance Recap

**Goal:** Give each employee a clear, phone-friendly attendance recap inside the existing portal so they can review recent workdays and spot issues without asking admin.

**Target features:**
- Employee can open an attendance recap surface from the existing portal
- Recap shows month-to-date summary counts plus recent daily attendance history
- Portal highlights exception days clearly, including sakit, izin, libur, and incomplete attendance outcomes

### Milestone Boundaries
- Keep this milestone read-only for employees
- Reuse the existing Astro portal shell, SSR auth flow, and employee identity resolution
- Defer employee requests, approval workflow, and reminder notifications to later milestones

### What v6.2 Added
- ✅ Restored the classic admin dashboard as the default `/admin/dashboard` landing surface for full admin users
- ✅ Moved chain-wide ringkasan jaringan and status per gerai to a dedicated full-admin screen reachable from the dashboard
- ✅ Replaced the admin dashboard utensil branding with the official Enakko dashboard logo asset
- ✅ Hardened Rekap Harian PDF for large exports and switched summary metrics from percentages to concrete counts

### What v6.1 Added
- ✅ Employee portal provisioning flow for existing employees
- ✅ Password-based name-search login on the Astro website
- ✅ Protected portal shell with employee identity resolution before schedule reads
- ✅ Employee schedule visibility for today, this week, and next week
- ✅ Mobile-first portal states for loading, empty, not-linked, and error
- ✅ Portal-only logout plus hardened authenticated RPC read path in the website backend

### What v6.0 Added
- ✅ Persistent installation UUIDv4 per kiosk that survives logout/re-setup
- ✅ `kiosk_devices` heartbeat pipeline with dedicated nickname/archive RPCs
- ✅ Multi-device admin dashboard with one live card per active kiosk device
- ✅ Full-admin Central Dashboard with chain-wide KPIs and outlet drilldown
- ✅ Gap-closure phases for rollout evidence, validation approval, and final requirement synchronization

### What v5.0 Added
- ✅ Background heartbeat — kiosk pings Supabase every 15 min with battery, charging state, app version, pending sync count
- ✅ Sentry crash reporting — unhandled Dart/native exceptions captured; NFC "Tag lost" noise filtered; background isolate covered
- ✅ Kiosk diagnostics screen (long-press logo) — shows outlet, battery, connectivity, pending/failed counts + Force Sync button
- ✅ Sync indicator strip on kiosk idle screen — amber strip appears when pending logs > 0, auto-hides on clear
- ✅ Admin dashboard "Status Kiosk" section — per-outlet online/offline, battery warning (<20%), sync badge

### What v4.0 Added
- ✅ NFC double-scan crash fix during employee registration
- ✅ Smart attendance pattern detection (BETA) — median arrival time per day-of-week, late notification
- ✅ Overtime tracking flags from shift template duration comparison
- ✅ Missing clock-out batched notification per outlet ("3 karyawan belum pulang di Outlet A")
- ✅ Attendance rate card on admin dashboard (hadir %, concrete counts)
- ✅ Gamification streak system — consecutive on-time attendance, kiosk scan streak display
- ✅ Auto-badge awards at 7/30/90-day streak milestones
- ✅ Chart dashboard with fl_chart — donut chart, weekly trend bar, streak leaderboard, overtime alerts
- ✅ Cross-outlet attendance comparison grouped bar chart (admin-only)
- ✅ Kepala Gerai onboarding via app — CreateAdminScreen (3-state UI), Edge Function user creation, WhatsApp share, PDF audit trail
- ✅ All chart/analytics aggregations via Supabase RPC (server-side PostgreSQL)

### Known Tech Debt
- v6.2 archived without a dedicated milestone audit or per-phase PLAN/SUMMARY artifacts for phases 40-41
- Final admin logo correction landed after the first `v6.2.0` build; milestone closeout rebuilds from the corrected asset path `src/assets/images/logogoenakko.png`
- v6.1 verification debt accepted at archive time: Phase 37 has no verification artifact; Phase 38 and 39 validation files remained draft
- v6.1 planning summaries lag the shipped website hardening (`get_portal_schedule_overview`, authenticated RPC ACL tightening, and portal UI follow-up tweaks)
- Live Activity pill not confirmed rotating on physical device (code correct, needs device debugging)
- Dual PDF service files (pdf_report_service.dart + pdf_service.dart)
- Phase 15 has no formal PLAN/SUMMARY files (SQL-only phase)
- Pattern detection `compute()` isolate: first use in this app — monitor production performance

<details>
<summary>v3.1 Context (shipped 2026-03-18)</summary>

- Biometric login (fingerprint/face) with 5s timeout fallback
- Badge color picker for visual customization
- Production release: GitHub Release v3.1 with ABSENKOK-v3.1.0.apk

</details>

<details>
<summary>v2.0 Context (shipped 2026-03-12)</summary>

- Soft-archive karyawan with Riwayat Karyawan history page
- Batch CSV import for multi-outlet employee onboarding (4-step wizard)
- Quick SQL setup for promoting Kepala Gerai admin
- Dynamic Island-style overlay pill with break detection + fun facts rotation
- 56+ new unit tests (CSV service, live content provider, overlay model)
- ~22,000 LOC Dart across 50+ files

</details>

<details>
<summary>v1.1 Context (shipped 2026-03-05)</summary>

Shipped v1.1 with 19,124 LOC Dart across 47 files.
All 5 original production bugs fixed. 71/71 tests GREEN.
Key areas shipped: bug fixes, floating pill overlay, PDF/CSV reports, kiosk visual polish,
admin UI consistency, schedule Supabase sync, sakit/izin management, employee badges, logout resilience.

</details>

## Requirements

### Validated (v4.0)
- ✓ NFC double-scan crash fixed — v4.0
- ✓ Smart attendance pattern detection (BETA, median arrival per day-of-week) — v4.0
- ✓ Overtime tracking from shift template duration — v4.0
- ✓ Missing clock-out batched notification per outlet — v4.0
- ✓ Attendance rate card on admin dashboard (hadir %, concrete counts) — v4.0
- ✓ Gamification streak — consecutive on-time attendance with kiosk display — v4.0
- ✓ Auto-badge awards at 7/30/90-day streak milestones — v4.0
- ✓ Chart dashboard (donut chart, weekly trend, streak leaderboard, overtime alerts) — v4.0
- ✓ Cross-outlet attendance comparison (admin-only grouped bar chart) — v4.0
- ✓ Kepala Gerai onboarding from app (Edge Function, WhatsApp share, PDF audit trail) — v4.0
- ✓ All chart aggregations via Supabase RPC (server-side) — v4.0

### Validated (v3.0)
- ✓ Schedule UI grid redesign — week-view TableView, pinned headers, color-coded shift chips — v3.0
- ✓ Tap-to-assign shift (Pagi/Siang/Sore/Libur) per cell — v3.0
- ✓ Bulk assign mode (multi-karyawan, same shift) — v3.0
- ✓ Auto-generate jadwal dari template shift — v3.0
- ✓ ABSENKOK landing website (Astro 5 + Tailwind v4, zero JS, Bahasa Indonesia) — v3.0
- ✓ Download APK button → GitHub Releases — v3.0
- ✓ SEO meta tags + sitemap.xml + Vercel deploy — v3.0
- ✓ Real app screenshots in Hero + HowItWorks — v3.0
- ✓ About/Architecture section with tech stack story + 4 SVG icons — v3.0

### Validated (v2.0)
- ✓ Soft-archive karyawan (arsip ke Riwayat Karyawan, hilang dari daftar aktif & jadwal, log tetap utuh)
- ✓ Batch import karyawan via CSV (nama, jabatan, gerai, photo_url — NFC UID di-set manual)
- ✓ Quick setup Kepala Gerai via SQL script (tinggal ganti email di Supabase SQL editor)
- ✓ Persistent live activity pill (Dynamic Island-style overlay di luar app — status istirahat real-time, fun fact saat idle)

### Validated (v1.1)
- ✓ Rekap Harian sakit/izin display
- ✓ Cross-day shift grouping (noon rule)
- ✓ Persistent live-activity overlay on background
- ✓ PDF export with insights
- ✓ NFC idle screen ambient animation
- ✓ Admin UI polish
- ✓ Schedule persistence to Supabase
- ✓ Sakit/Izin direct input by Kepala Gerai
- ✓ Employee badge system

### Validated (v5.0)
- ✓ Background heartbeat (15-min, battery + charging + version + pending count) — v5.0
- ✓ Sentry crash reporting — unhandled Dart/native + NFC noise filter + background isolate — v5.0
- ✓ Kiosk diagnostics screen + force sync button — v5.0
- ✓ Sync indicator strip on kiosk idle screen — v5.0
- ✓ Admin dashboard "Status Kiosk" section (online/offline, battery, sync count) — v5.0

### Validated (v6.0)
- ✓ Persistent kiosk installation UUID with logout/re-setup resilience — v6.0
- ✓ Heartbeat writes to `kiosk_devices` instead of `outlets` — v6.0
- ✓ Multi-device outlet dashboard with per-device health state — v6.0
- ✓ Device archive/unlink flow from admin dashboard — v6.0
- ✓ Device nickname flow from admin dashboard — v6.0
- ✓ Full-admin Central Dashboard with chain-wide device visibility — v6.0
- ✓ Firm-wide daily attendance aggregation in the Central Dashboard — v6.0

### Validated (v6.1)
- ✓ Admin can provision initial employee portal access for existing staff records — v6.1
- ✓ Employee can find their profile through name search and sign in with password — v6.1
- ✓ Protected portal routes resolve exactly one employee before schedule data is shown — v6.1
- ✓ Employee can see current and upcoming schedules in a mobile-first portal shell — v6.1
- ✓ Portal logout is scoped locally to the portal session — v6.1

### Validated (v6.2)
- ✓ Full admin lands on the classic admin dashboard at `/admin/dashboard` again — v6.2
- ✓ Dedicated action opens chain-wide ringkasan jaringan and status per gerai without replacing the classic dashboard — v6.2
- ✓ Kepala gerai stays outlet-scoped while chain-wide network views remain full-admin only — v6.2
- ✓ Admin dashboard uses the official Enakko brand logo asset — v6.2
- ✓ Rekap Harian PDF keeps per-employee summaries visible on large exports — v6.2
- ✓ Rekap Harian PDF summary cards use concrete counts instead of percentages — v6.2
- ✓ Rekap Harian PDF per-employee rows show count-based attendance metrics while preserving time context — v6.2

### Active (v6.3 Employee Attendance Recap)
- [ ] Employee can view an attendance recap inside the existing portal
- [ ] Portal recap shows month-to-date summary counts and recent day-by-day attendance history
- [ ] Portal recap preserves existing logical-day handling for overnight and cross-day attendance
- [ ] Portal recap surfaces exception days clearly without introducing request/approval workflow scope

### Deferred (Future)
- [ ] Employee time-off or absence request submission
- [ ] Manager/admin approval workflow for employee requests
- [ ] Shift reminders or notifications for upcoming work
- [ ] Employee-driven attendance correction or dispute submission
- [ ] Portal attendance filtering by custom date range or export
- [ ] Schedule grid tap-to-cycle shift assignment (GRID-D1)
- [ ] Schedule grid copy-week feature (GRID-D2)
- [ ] Schedule grid today-column highlight (GRID-D3)
- [ ] Time-off request approval workflow
- [ ] Keterlambatan (late arrival) automatic flagging vs shift start time

### Out of Scope
- iOS app — Android-only kiosk, no iOS target
- WhatsApp/email daily summary — external integration, low priority
- Blog/pricing on website — internal tool, not SaaS
- Drag-and-drop shift assignment — wrong for tablet touch
- Monthly view (30-day grid) — cognitive overload on tablet

## Product Context
- **Type:** B2B internal tool (restaurant chain HR/ops)
- **Users:** Kiosk guests (employees tap NFC cards) + Admin/Kepala Gerai (web-like admin panel in-app)
- **Scale:** 4 outlets, 14 employees today — designed for up to 20 outlets, 200 employees
- **Platform:** Android only (tablet kiosk) — no iOS target
- **Connectivity:** Must work offline-first; syncs when internet returns (SQLite queue → Supabase)
- **Uptime:** 24/7 kiosk — never hangs, never blocks startup
- **Website:** absenkok.vercel.app — Astro 5 static site, Vercel hosted

## Tech Stack
- **Framework:** Flutter 3.x / Dart (Kotlin 1.9.25 — cannot upgrade to 2.x, breaks nfc_manager)
- **Backend:** Supabase (PostgreSQL + Auth + Realtime) — project `tmapxdftdhxovthgbhww`
- **Local DB:** SQLite (sqflite) — offline attendance queue + schedule cache
- **State:** Riverpod (`AppProvider`)
- **Navigation:** GoRouter with redirect guards
- **NFC:** nfc_manager ^3.5.0 — universal UID reader (8 card types)
- **Notifications:** 3-tier — KioskNotificationHelper.kt (primary) + flutter_local_notifications (fallback) + flutter_overlay_window (floating pill)
- **Foreground service:** flutter_foreground_task — keeps app alive
- **PDF:** `pdf` package — PdfReportService (summary) + PdfService (export tables)
- **CSV:** `csv` ^6.0.0 + `file_picker` ^8.1.0 — batch employee import
- **Schedule Grid:** `two_dimensional_scrollables ^0.3.8` — TableView with pinned row/column, cell builder architecture
- **UI System:** AppCard, ShimmerSkeleton, AppEmptyState, AppBadge, AppToast, BadgeAvatar
- **Website:** Astro 5 + Tailwind v4 + @astrojs/vercel + @astrojs/sitemap

## Database Schema (Supabase — `tmapxdftdhxovthgbhww`)
```
outlets (4 rows)          — id, name, address, lat/lng, device_id, kiosk_password_hash, is_active
employees (14 rows)       — id, name, employee_code, nfc_uid, home_outlet_id, position, photo_url, is_active, active_badge_id, archived_at
employee_streaks          — employee_id, current_streak, longest_streak, last_attendance_date, last_updated
attendance_logs (89+ rows)— id, employee_id, scan_outlet_id, type[masuk|break|pulang|kembali|sakit|izin],
                            lat/lng, scanned_at, local_id, is_backup, notes
shift_templates (3 rows)  — id, outlet_id, name, slots(jsonb), is_default
schedules                 — id, outlet_id, week_start, created_by (Supabase-synced since v1.1)
schedule_entries           — id, schedule_id, employee_id, date, shift_type
badges                    — id, name, description, emoji, border_color, border_color2, border_style
time_off_requests (0 rows)— workflow schema exists but UI incomplete
```

## Key Architecture Rules (DO NOT BREAK)
- `supabaseReady` bool must gate all Supabase calls
- `loadSession()` must always set `isLoading = false` in `finally`
- `SharedPreferences` NOT `FlutterSecureStorage` (causes ANR)
- NFC init has 3s timeout in main() — never blocks startup
- MethodChannel notification is PRIMARY; flutter_local_notifications is FALLBACK only
- Both use ID=300 — never create both simultaneously
- Kotlin 1.9.x syntax: `catch (e: Exception)` NOT `catch (_: Exception)`
- GoRouter: `/admin/login` must ALWAYS be accessible before kiosk check
- KioskBackgroundService.stop() — each step individually try-caught (Phase 12 pattern)
- Logout handler has 5s timeout, clearKioskSession() always runs in separate try-catch
- Additive migrations only — production DB serving 4 outlets

## Key Decisions

| # | Decision | Outcome |
|---|----------|---------|
| 1 | Overlay pill via flutter_overlay_window | ✓ Works on Android, no iOS complexity |
| 2 | Noon rule for cross-day grouping | ✓ Handles 22:00-06:00 shifts correctly |
| 3 | Kotlin 1.9.25 (no upgrade) | ✓ nfc_manager stable |
| 4 | SharedPreferences over FlutterSecureStorage | ✓ Eliminated ANR issue |
| 5 | Per-step try-catch in stop() | ✓ Prevents cascade failure |
| 6 | Archive = soft-delete via archived_at + is_active | ✓ Preserves all history |
| 7 | Kepala Gerai = SQL script only | ✓ Simple, secure for 4 outlets |
| 8 | CSV pure-function validation | ✓ Testable without Supabase |
| 9 | LiveContentProvider injectable callbacks | ✓ Clean testability |
| 10 | displayLabel backward compat (empty = enum label) | ✓ No breaking changes |
| 11 | two_dimensional_scrollables for schedule grid | ✓ Pinned headers work on Android tablet, diagonal scroll |
| 12 | Top-level cell builder functions (not methods) | ✓ Clean widget extraction, no context binding |
| 13 | Astro 5 website in separate repo (absenkok-website/) | ✓ Zero coupling to Flutter codebase |
| 14 | Tailwind v4 CSS-first config (no tailwind.config.js) | ✓ Simpler, no config file overhead |
| 15 | Inline SVG tech icons (no external library) | ✓ Zero bundle overhead, color-customizable |
| 16 | Time-based overtime threshold (8h default), not schedule-aware join | ✓ Avoids SQLite/Supabase cross-system join complexity |
| 17 | MissingClockoutService: direct RPC call (not via AnalyticsService) | ✓ Avoids build-order dependency between services |
| 18 | Late detection threshold exclusive (>5 min, not >=) | ✓ Matches "late >5 minutes" UX spec |
| 19 | Pattern detection via compute() isolate + 6h cache | ✓ Never blocks NFC scan handler |
| 20 | Kepala Gerai creation via Edge Function (service_role server-side) | ✓ service_role key never in APK |
| 21 | WhatsApp sharing via deep link + share_plus fallback | ✓ Works on all Android versions |
| 22 | Plans 02+03 merged into 01 for same .dart file | ✓ Avoids merge conflicts, reduces build iterations |
| 23 | Sentry NFC noise filter via type+message check | ✓ Zero spam; real errors still captured |
| 24 | HeartbeatService in background isolate (not main) | ✓ Never blocks NFC scan, survives app minimize |
| 25 | Diagnostics screen behind long-press logo (hidden) | ✓ No UI clutter; ops can access without training |
| 26 | Hidden portal auth email uses `employee+<uuid>@portal.absenkok.internal` | ✓ Stable employee-linked auth key without exposing user-entered identifiers |
| 27 | Portal search normalization stays in Postgres via generated column + trigram gate | ✓ Fast duplicate-safe employee search without mutating display names |
| 28 | Astro SSR portal auth validates with `getUser()` in middleware | ✓ Server-side portal access does not trust stale client session state |
| 29 | Portal schedule UI derives today and upcoming views from one schedule dataset | ✓ Portal surfaces stay internally consistent across current and future schedule sections |
| 30 | Portal logout uses `scope: 'local'` and blocked states stay inside `PortalLayout` | ✓ Employee portal can sign out safely without affecting kiosk/admin sessions |
| 31 | Full admin returns to the classic dashboard; chain-wide network visibility moves to a dedicated route | ✓ Restores the preferred ops surface without losing cross-gerai visibility |
| 32 | Rekap Harian PDF summary switched to count metrics and `MultiPage` landscape summary layout | ✓ Large exports keep per-employee summary content visible |
| 33 | Final admin branding ships with `src/assets/images/logogoenakko.png` | ✓ Dashboard branding now matches the intended Enakko logo asset |

## Brand & Design Direction
- **Brand:** Ayam Guling Enakko (Indonesian restaurant chain)
- **Color:** `AppColors.primary` — warm amber/orange tones (restaurant brand)
- **Design language:** Minimalist-professional, luxury "polished" feel
- **Logo:** Ayam Guling Enakko brand logo in kiosk idle screen header
- **Website:** ABSENKOK brand, white minimalist, Apple/Stripe-inspired

## Constraints
- Kotlin 1.9.25 — NO upgrade to 2.x
- SharedPreferences for session (NOT FlutterSecureStorage)
- Notification ID=300: MethodChannel PRIMARY, flutter_local_notifications FALLBACK
- Android only — no iOS target
- minSdk 24, compileSdk 35, targetSdk 35
- Additive migrations only (production DB live)

---
*Last updated: 2026-03-23 after starting milestone v6.3 Employee Attendance Recap*
