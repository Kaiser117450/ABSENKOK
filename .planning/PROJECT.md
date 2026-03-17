# PROJECT.md — Absensi Enakko

## What This Is
NFC attendance kiosk app for **Ayam Guling Enakko** restaurant chain — Android tablet deployed
at each outlet. Replaces paper attendance. Features: real-time reports with PDF/CSV export,
persistent floating pill overlay (Dynamic Island-style), employee badge system, Supabase-synced
schedule grid (week-view TableView), employee archive/restore, batch CSV import, and premium
kiosk UI. Marketing website at absenkok.vercel.app. Admin can manage employees, attendance,
schedules, and badges. Kiosk runs unattended 24/7; NFC tap takes < 2 seconds.

## Core Value
Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.

## Current Milestone: v3.1 Biometric Login + Badge Polish + Release

**Goal:** Add biometric fast-login for admin/kepala gerai, visual badge color picker, and publish production APK to GitHub Releases.

**Target features:**
- Biometric (fingerprint/face) login for admin and kepala gerai
- Color picker UI for badge border color selection
- Production APK build + GitHub Release publish

## Current State

**Shipped:** v3.0 Schedule Grid + Landing Website (2026-03-13)
**Running at:** 4 Ayam Guling Enakko outlets, 14 employees
**Codebase:** ~22,000+ LOC Dart across 50+ files; Astro website at `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\`

### What v3.0 Added
- ✅ Schedule UI grid redesign — week-view TableView with pinned row/column headers, color-coded shift chips
- ✅ Bulk assign mode and auto-generate schedule from 2/3-shift templates
- ✅ ABSENKOK marketing website (Astro 5 + Tailwind v4, deployed to Vercel)
- ✅ Website polished with real app screenshots, About/Architecture section, 4 inline SVG tech icons

### Known Tech Debt
- Live Activity pill not confirmed rotating on physical device (code correct, needs device debugging)
- Dual PDF service files (pdf_report_service.dart + pdf_service.dart)
- Phase 15 has no formal PLAN/SUMMARY files (SQL-only phase)

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

### Deferred (Future)
- [ ] Schedule grid tap-to-cycle shift assignment (GRID-D1)
- [ ] Schedule grid copy-week feature (GRID-D2)
- [ ] Schedule grid today-column highlight (GRID-D3)
- [ ] Time-off request approval workflow
- [ ] Keterlambatan (late arrival) automatic flagging vs shift start time
- [ ] Overtime tracking (> 8h kerja → overtime flag)
- [ ] Push notification for missing clock-out
- [ ] Attendance rate card on admin dashboard

### Out of Scope
- iOS app — Android-only kiosk, no iOS target
- Employee self-service portal — kiosk-only workflow
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
*Last updated: 2026-03-18 — v3.1 milestone started*
