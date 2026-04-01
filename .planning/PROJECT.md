# PROJECT.md — Absensi Enakko

## What This Is
NFC attendance kiosk app for **Ayam Guling Enakko** restaurant chain — Android tablet deployed
at each outlet. Replaces paper attendance. Features: real-time reports with payroll-facing PDF
and spreadsheet export, persistent floating pill overlay (Dynamic Island-style), employee badge
system, Supabase-synced schedule grid (week-view TableView), employee archive/restore, batch CSV
import, and premium kiosk UI. Marketing website at absenkok.vercel.app now also hosts a protected
employee portal for self-service schedule visibility. Admin can manage employees, attendance,
schedules, badges, and payroll recap outputs. Kiosk runs unattended 24/7; NFC tap takes < 2
seconds.

## Core Value
Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.

## Current Milestone: v8.1 Reporting Recovery & Schedule Gap Notifications

**Goal:** Restore the trusted Rekap Harian behavior for existing no-schedule data without removing strict contract-aware report rules that already matter for payroll review.

**Target features:**
- recover pre-v8.0-style daily recap continuity for historical days that do not yet have pagi/siang/sore/libur schedule entries
- keep spreadsheet export and PDF export as the primary salary-facing outputs from the corrected recap dataset
- retain strict contract-aware report evaluation for break-first and excessive break duration signals
- move empty-schedule enforcement into outlet-scoped notifications for kepala gerai so schedule gaps are visible without corrupting pending or recap states

**Latest shipped milestone:** v8.0 Strict Attendance & Payroll Reporting (2026-03-31)

**Current operational focus:**
- Phase 61 is complete, so the recap baseline is trusted again on the canonical merged dataset
- start Phase 62 schedule-gap notices without reopening recap semantics
- preserve additive-only, explicitly user-approved production SQL changes
- relock spreadsheet/PDF export parity only after the notice surface is in place

## Current State

**Shipped:** v8.0 Strict Attendance & Payroll Reporting (2026-03-31)
**Running at:** 4 Ayam Guling Enakko outlets, 14 employees
**Web surfaces:** marketing site + protected employee portal with schedules plus attendance recap on the Astro website
**Admin surfaces:** classic admin dashboard restored as the default full-admin landing surface; chain-wide network visibility stays on its own full-admin screen
**Workforce metadata:** Phase 54 completed on 2026-03-27, so employee contracts, contract-aware CSV onboarding, and outlet operating modes are now first-class admin inputs
**Scheduling policy:** Phase 55 completed on 2026-03-27, so shift bands, required hours, lateness windows, and no-show handling now flow through the shared schedule-policy layer
**Scan authority:** Phase 56 completed on 2026-03-27, so kiosk scan timing now comes from authoritative WITA server timestamps with offline replay metadata and break-first intent capture
**Strict recap:** Phase 57 completed on 2026-03-27, so admin recap rows now consume primary status, detail signals, work metrics, and manager exemption semantics from one typed strict engine
**Payroll matrix:** Phase 58 completed on 2026-03-27, so Rekap Harian now renders a payroll-ready employee/date matrix with sticky summary counts and spreadsheet export from the same shared dataset
**Recap recovery:** Phase 61 completed on 2026-04-01, so the active admin Rekap Harian tab is row-first again on the canonical merged recap dataset, legacy no-schedule rows stay honest and overnight-safe, and pending recap filters read from recap signals instead of raw-log heuristics
**Employee visibility:** portal now shows month-to-date attendance summary counts, recent logical-day history, and explicit follow-up labels for problem days
**Reporting:** Phase 59 completed on 2026-03-28, so admin recap, spreadsheet export, PDF export, and portal recap now share the strict payroll parity contract without stale clock-first framing
**Rollout acceptance:** Phase 60 completed on 2026-03-31, so operators now have a canonical rollout checklist, locked seven-scenario fixtures, recap-shell readiness gating, and validation-bundle export before payroll is marked ready
**Milestone audit:** v8.0 audit passed on 2026-03-31, so all 17 mapped requirements now have archive-backed summary plus verification coverage
**Release lane:** `tool/release_env.ps1` -> `tool/release_preflight.ps1` -> `tool/release_build.ps1` now produces the canonical signed APK, optional bundle, manifest, smoke evidence, and retained debug artifacts from one tracked PowerShell lane
**Distribution:** GitHub Release `v7.0.0` includes the obfuscated smoke-verified asset `ABSENKOK-v7.0.0+8013.apk`
**Security:** v7.1 hardened kiosk device boundaries, admin session trust, and portal surface exposure; passwordless portal entry is an accepted product decision documented in the risk register
**Codebase:** ~28,619 tracked LOC Dart across 102 tracked files plus the separate Astro website repo, portal recap components/routes/helpers, portal-specific Supabase RPCs, and the tracked Android release helper chain

### Known Tech Debt
- Spreadsheet export still needs manual viewer verification for frozen panes and operator ergonomics in a real spreadsheet app
- The additive SQL patches for Phases 54-57 still require explicit user approval before any production Supabase rollout
- GitHub release publication still needs `gh release upload` fallback in this environment because the app automation could not read the local staged artifact path directly
- Real signing files (`android/key.properties` and the upload keystore) remain intentionally machine-local, so release bootstrap is still an operator task
- Shell `java` may still drift to Temurin 25; operators must enter the release lane through `tool/release_env.ps1` or set `ABSENKOK_JAVA_HOME`
- Flutter 3.41.1 still warns that Kotlin 1.9.25 will age out in a future cycle
- Live Activity pill not confirmed rotating on physical device (code correct, needs device debugging)
- Dual PDF service files (`pdf_report_service.dart` + `pdf_service.dart`)
- Phase 15 has no formal PLAN/SUMMARY files (SQL-only phase)
- Pattern detection `compute()` isolate: first use in this app — monitor production performance

<details>
<summary>v7.0 Closeout Notes (shipped 2026-03-25)</summary>

- Restored the canonical Windows release baseline at `C:\flutter\bin\flutter.bat` and aligned tracked metadata to `7.0.0+8013`.
- Pinned the supported Java 21 / Flutter / Gradle / Kotlin contract in tracked PowerShell helpers and docs.
- Replaced debug signing with a private upload-key flow and staged release evidence under `build/releases/android/ABSENKOK-v7.0.0+8013/`.
- Final published asset is the obfuscated smoke-verified `ABSENKOK-v7.0.0+8013.apk` with retained `symbols/` files plus `mapping.txt`.
- GitHub Release `v7.0.0` was updated manually via `gh release upload`; cloud release automation remains future work.

</details>

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
- ✓ Download APK button -> GitHub Releases — v3.0
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

### Validated (v6.3)
- ✓ Employee can open an attendance recap inside the existing portal and stay within the employee-facing shell — v6.3
- ✓ Each recap day shows the attendance outcome together with the available timestamps for that logical workday — v6.3
- ✓ Portal recap preserves logical-day and overnight handling for cross-day attendance — v6.3
- ✓ Month-to-date summary counts are visible from the same recap dataset — v6.3
- ✓ Exception days are clearly labeled, including incomplete attendance outcomes and scheduled days without a completed record — v6.3
- ✓ Portal attendance recap is usable on a phone-sized browser inside the existing portal shell — v6.3
- ✓ Portal attendance recap has explicit loading, empty, and error states when data is unavailable — v6.3

### Validated (v7.0)
- ✓ Release build succeeds from a clean checkout on the supported Flutter/Java/Gradle toolchain without `--android-skip-build-dependency-validation` — v7.0
- ✓ Release signing uses a private upload keystore flow instead of the debug keystore — v7.0
- ✓ `pubspec.yaml`, Android version metadata, and generated artifact names all reflect the active milestone version — v7.0
- ✓ Release packaging retains the canonical APK, mapping output, obfuscation-aware debug artifacts, and smoke evidence before distribution — v7.0
- ✓ Operators can follow one documented local PowerShell release workflow without guessing hidden bootstrap prerequisites — v7.0

### Validated (v7.1)
- ✓ Kiosk heartbeat and device-management RPCs reject spoofed or unscoped callers — v7.1
- ✓ Dashboard/admin access trusts only server-issued `app_metadata` and a still-valid Supabase session — v7.1
- ✓ Portal public search and repair flows expose only the minimum data needed while keeping passwordless employee entry — v7.1
- ✓ Security rollout stays additive and production-safe for the live Supabase project — v7.1

### Validated (v8.0)
- ✓ Employment contracts and outlet operating modes are now explicit attendance inputs in admin, archive, CSV onboarding, and outlet-management flows — Phase 54
- ✓ Schedule policy now stores shift bands and required hours, and no-show / lateness rules evaluate from that shared policy layer — Phase 55
- ✓ Kiosk attendance timestamps now use authoritative WITA server time, with offline replay metadata and break-first confirmation support — Phase 56
- ✓ Strict recap evaluation now emits primary status, detail signals, work metrics, overtime, incomplete, and manager-exemption semantics for admin recap — Phase 57
- ✓ Rekap Harian admin view now renders a payroll-ready employee/date matrix with compact cell content, semantic colors, and sticky summary counts — Phase 58
- ✓ Spreadsheet export now replaces recap CSV for payroll review and preserves color-coded cells plus per-employee violation/overtime counts — Phase 58

- ✓ Portal and payroll PDF recap surfaces now consume the strict parity contract and stay aligned with the admin payroll matrix — Phase 59
- ✓ Rollout validation now ships as one additive-only checklist, seven-scenario fixture pack, recap-shell acceptance surface, and validation-bundle export before payroll use — Phase 60

### Validated (v8.1 / Phase 61)
- ✓ Rekap Harian and pending views stay usable on legacy no-schedule attendance data — Phase 61
- ✓ Compatibility rows preserve logical-day grouping, contract-based required hours, and honest incomplete states without fabricating late or absence signals — Phase 61
- ✓ Strict contract-aware break-first and excess-break recap semantics stay visible when strict evaluation data exists — Phase 61

### Active
- [ ] Spreadsheet export and payroll PDF stay aligned with the corrected daily recap semantics and remain the primary operator outputs.
- [ ] Kepala gerai receives actionable notifications about empty schedule days for their outlet employees without those gaps distorting pending and recap behavior.

### Out of Scope
- Automatic payroll amount calculation, payslip generation, or THR formulas — this milestone stops at strict attendance evidence and salary-ready reports
- Free-form custom shift start/end editing per employee — this milestone standardizes business shift bands and rules instead of arbitrary times
- GPS coordinates or technical scan metadata in payroll recap exports — user explicitly wants compact salary-facing reports only
- Overtime approval workflow or employee correction requests — defer until the strict reporting baseline is stable
- Remove passwordless employee portal sign-in entirely — intentionally retained this milestone for employee convenience, even though it leaves accepted impersonation risk
- Enforce a strict portal-account whitelist that blocks any active employee without pre-created mapping — conflicts with the chosen passwordless product behavior for now
- Change portal logout from local scope to global token revocation — local-only logout is retained to avoid breaking concurrent admin/kiosk sessions
- Employee portal request/approval features — deferred until Android release packaging is stable again
- Multi-channel reminder workflows or escalation ladders beyond the kepala gerai empty-schedule notice — defer until the reporting baseline is trusted again
- Website/Astro deployment automation — this milestone is scoped to the Flutter Android release path
- Build-speed-only work — reliability comes first; performance tuning is deferred until the release path is reproducible
- APK size-only work — defer until signed release artifacts are consistently generated and verifiable
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
- **Connectivity:** Must work offline-first; syncs when internet returns (SQLite queue -> Supabase)
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
```text
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
| 34 | Portal attendance recap stays employee-scoped end-to-end through `resolve_portal_employee()` and one recap dataset | ✓ Portal recap never trusts client-supplied employee identity |
| 35 | Only `belum_pulang` and `tidak_hadir` are follow-up gaps; current-day in-progress states stay informational | ✓ Portal highlights actionable days without alarming active-shift employees |
| 36 | Historical recap copy is row-aware via `getRecapDayPresentationForDay(day, referenceDate)` | ✓ Past rows use date-accurate wording instead of generic "hari ini" copy |
| 37 | Canonical Windows release lane uses `C:\flutter\bin\flutter.bat` while AGP/Gradle/Kotlin stay pinned through Phase 46 | ✓ Release packaging baseline recovered without a toolchain upgrade |
| 38 | `pubspec.yaml` remains the single version source of truth and APK naming stays derived from `variant.versionName` | ✓ v7.0 metadata now aligns from source version through packaged artifact name |
| 39 | v8.0 attendance rules will read explicit employee contracts (`FULLTIME` / `PARTTIME`) plus outlet operating mode (`NORMAL` / `TWENTY_FOUR_HOUR`) instead of today’s generic overtime heuristic | ✓ Phase 54 foundation complete |
| 40 | Schedule-required lateness, no-show handling, and required-hours metadata live in the shared shift-band policy layer instead of fixed clock heuristics | ✓ Phase 55 foundation complete |
| 41 | WITA server time, not tablet local time, becomes the authoritative scan clock for strict lateness and payroll reporting | ✓ Phase 56 foundation complete |
| 42 | Strict recap primary status, detail signals, and manager exemption stay canonical in SQL and typed model output instead of being re-derived in widgets | ✓ Phase 57 foundation complete |
| 43 | Shared payroll matrix data is the canonical contract for admin recap, spreadsheet export, payroll PDF, and parity wiring | ✓ v8.0 reporting surfaces stay aligned on one dataset |
| 44 | Legacy payroll fallback only fills missing strict recap keys and never overwrites strict recap rows | ✓ Phase 58.1 compatibility remains additive and honest |
| 45 | Payroll rollout readiness stays as a typed manual acceptance workflow inside the admin recap shell before salary use | ✓ Phase 60 makes go-live review explicit instead of implicit |

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

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check -> still the right priority?
3. Audit Out of Scope -> reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-01 after Phase 61 completion*
