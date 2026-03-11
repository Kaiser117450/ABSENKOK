# PROJECT.md — Absensi Enakko

## What This Is
NFC attendance kiosk app for **Ayam Guling Enakko** restaurant chain — Android tablet deployed
at each outlet. Replaces paper attendance. Features: real-time reports with PDF/CSV export,
persistent floating pill overlay (Dynamic Island-style), employee badge system, Supabase-synced
schedules, and premium kiosk UI. Admin can manage employees, attendance, schedules, and badges.
Kiosk runs unattended 24/7; NFC tap takes < 2 seconds.

## Core Value
Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.

## Requirements

### Validated
- ✓ Rekap Harian sakit/izin display — v1.1
- ✓ Rekap Harian --:-- pagination fix — v1.1
- ✓ Cross-day shift grouping (noon rule) — v1.1
- ✓ Lupa absen pulang handling (belum pulang state) — v1.1
- ✓ 24h outlet shift cycle — v1.1
- ✓ Persistent live-activity overlay on background — v1.1
- ✓ Overlay UI luxury pill design — v1.1
- ✓ PDF export with insights (branded summary + per-employee table) — v1.1
- ✓ CSV export improvement (per-scan + rekap harian) — v1.1
- ✓ NFC idle screen ambient animation — v1.1
- ✓ Brand logo on idle screen — v1.1
- ✓ Admin UI polish (cards, shimmer, empty states, toast) — v1.1
- ✓ Schedule persistence to Supabase — v1.1
- ✓ Auto-flag missing clock-out (open shifts widget) — v1.1
- ✓ Sakit/Izin direct input by Kepala Gerai — v1.1
- ✓ Employee badge system (solid/gradient/glow rings, emoji, CRUD) — v1.1

### Active
- [ ] Soft-archive karyawan (arsip ke Riwayat Karyawan, hilang dari daftar aktif & jadwal, log tetap utuh)
- [ ] Batch import karyawan via CSV (nama, jabatan, gerai, photo_url — NFC UID di-set manual)
- [ ] Quick setup Kepala Gerai via SQL script (tinggal ganti email di Supabase SQL editor)
- [ ] Persistent live activity pill (Dynamic Island-style overlay di luar app — status istirahat real-time, fun fact saat idle)

### Deferred (Future)
- [ ] Schedule UI full grid redesign (week-view grid, tap-to-assign cells)
- [ ] Time-off request approval workflow
- [ ] Keterlambatan (late arrival) automatic flagging vs shift start time
- [ ] Overtime tracking (> 8h kerja → overtime flag)
- [ ] Push notification for missing clock-out
- [ ] Attendance rate card on admin dashboard

### Out of Scope
- iOS app — Android-only kiosk, no iOS target
- Employee self-service portal — kiosk-only workflow, employees don't interact with app directly
- WhatsApp/email daily summary — external integration, low priority
- Video chat / real-time monitoring — not needed for attendance kiosk
- QR code backup — NFC reliability proven sufficient at 4 outlets

## Context

Shipped v1.1 with 19,124 LOC Dart across 47 files.
Tech stack: Flutter 3.x, Supabase (PostgreSQL + Auth), SQLite (offline queue), Kotlin 1.9.25.
Running at 4 Ayam Guling Enakko outlets with 14 employees.
All 5 original production bugs fixed. 71/71 tests GREEN.

Key areas shipped: bug fixes, floating pill overlay, PDF/CSV reports, kiosk visual polish,
admin UI consistency, schedule Supabase sync, sakit/izin management, employee badges, logout resilience.

Known tech debt: dual PDF service files (pdf_report_service.dart + pdf_service.dart), missing
VERIFICATION.md on 6/11 phases, missing VALIDATION.md on 8/11 phases.

## Product Context
- **Type:** B2B internal tool (restaurant chain HR/ops)
- **Users:** Kiosk guests (employees tap NFC cards) + Admin/Kepala Gerai (web-like admin panel in-app)
- **Scale:** 4 outlets, 14 employees today — designed for up to 20 outlets, 200 employees
- **Platform:** Android only (tablet kiosk) — no iOS target
- **Connectivity:** Must work offline-first; syncs when internet returns (SQLite queue → Supabase)
- **Uptime:** 24/7 kiosk — never hangs, never blocks startup

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
- **UI System:** AppCard, ShimmerSkeleton, AppEmptyState, AppBadge, AppToast, BadgeAvatar

## Database Schema (Supabase — `tmapxdftdhxovthgbhww`)
```
outlets (4 rows)          — id, name, address, lat/lng, device_id, kiosk_password_hash, is_active
employees (14 rows)       — id, name, employee_code, nfc_uid, home_outlet_id, position, photo_url, is_active, active_badge_id
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

## Key Decisions

| # | Decision | Outcome |
|---|----------|---------|
| 1 | Overlay pill via flutter_overlay_window (not live_activities) | ✓ Good — works on Android, no iOS complexity |
| 2 | Separate fetch for Rekap Harian (no pagination) | ✓ Good — eliminates --:-- bug completely |
| 3 | Noon rule for cross-day grouping | ✓ Good — handles 22:00-06:00 shifts correctly |
| 4 | PDF via existing `pdf` package | ✓ Good — no new dependency, branded output |
| 5 | Kotlin 1.9.25 (no upgrade) | ✓ Good — nfc_manager stable |
| 6 | Supabase-first schedule load | ✓ Good — dual-write ensures cross-device sync |
| 7 | SharedPreferences over FlutterSecureStorage | ✓ Good — eliminated ANR issue |
| 8 | Direct Supabase INSERT for sakit/izin | ✓ Good — immediate visibility in reports |
| 9 | BadgeService singleton with in-memory cache | ✓ Good — small reference table, fast lookup |
| 10 | Per-step try-catch in KioskBackgroundService.stop() | ✓ Good — prevents cascade failure on cold restart |

## Brand & Design Direction
- **Brand:** Ayam Guling Enakko (Indonesian restaurant chain)
- **Color:** `AppColors.primary` — warm amber/orange tones (restaurant brand)
- **Design language:** Minimalist-professional, NOT generic AI aesthetic
  - Cards with subtle shadows, clean typography, purposeful whitespace
  - Luxury "polished" feel — like a premium POS system
  - Animations: subtle, ambient, not intrusive (especially on kiosk idle screen)
- **Logo:** Ayam Guling Enakko brand logo in kiosk idle screen header

## Constraints
- Kotlin 1.9.25 — NO upgrade to 2.x
- `catch (e: Exception)` — NOT `catch (_: Exception)`
- SharedPreferences for session (NOT FlutterSecureStorage)
- Notification ID=300: MethodChannel is PRIMARY, flutter_local_notifications FALLBACK only
- Android only — no iOS target
- minSdk 24, compileSdk 35, targetSdk 35

## Current Milestone: v2.0 Admin Tools + Live Activity

**Goal:** Empower admin with employee lifecycle management (archive, batch import, quick Kepala Gerai setup) and deliver persistent Dynamic Island-style live activity overlay.

**Target features:**
- Soft-archive karyawan with Riwayat Karyawan history page
- Batch CSV import for multi-outlet employee onboarding
- Quick SQL setup for promoting Kepala Gerai admin
- Persistent live activity pill outside app (break status, fun facts)

---
*Last updated: 2026-03-11 after v2.0 milestone start*
