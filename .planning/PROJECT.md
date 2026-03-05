# PROJECT.md — Absensi Enakko

## Vision
NFC attendance kiosk app for **Ayam Guling Enakko** restaurant chain — Android tablet deployed
at each outlet. Replaces paper attendance. Admin can see real-time reports, export to PDF/CSV,
manage employees and schedules. Kiosk runs unattended 24/7; NFC tap takes < 2 seconds.

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
- **Local DB:** SQLite (sqflite) — offline attendance queue
- **State:** Riverpod (`AppProvider`)
- **Navigation:** GoRouter with redirect guards
- **NFC:** nfc_manager ^3.5.0 — universal UID reader (8 card types)
- **Notifications:** 3-tier — KioskNotificationHelper.kt (primary) + flutter_local_notifications (fallback) + flutter_overlay_window (floating pill)
- **Foreground service:** flutter_foreground_task — keeps app alive

## Database Schema (Supabase — `tmapxdftdhxovthgbhww`)
```
outlets (4 rows)          — id, name, address, lat/lng, device_id, kiosk_password_hash, is_active
employees (14 rows)       — id, name, employee_code, nfc_uid, home_outlet_id, position, photo_url, is_active
attendance_logs (89 rows) — id, employee_id, scan_outlet_id, type[masuk|break|pulang|kembali|sakit|izin],
                            lat/lng, scanned_at, local_id, is_backup, notes
shift_templates (3 rows)  — id, outlet_id, name, slots(jsonb), is_default
schedules (0 rows!)       — schedule system exists in schema but HAS NO DATA — broken/unused
schedule_entries (0 rows!)
time_off_requests (0 rows)— workflow schema exists (approved_by/approved_at) but UI incomplete
```

### Attendance Type Distribution (real data)
- masuk: 24, pulang: 22, kembali: 21, break: 21, sakit: 1, izin: 0
- Pattern: balanced masuk/pulang (healthy), break/kembali balanced, very few sick days

## Known Bugs (Confirmed)

### BUG-001: Rekap Harian — Sakit/Izin shows wrong tiles [HIGH]
- **Where:** `admin_reports_screen.dart` → `_DailySummaryTile`
- **Root cause:** `_computeDailySummaries()` has no detection of sakit/izin-only days.
  `_DailySummaryTile` always renders 4 cells (Masuk | Pulang | Kerja | Istirahat) even
  when the only attendance event for that day is `sakit` or `izin`.
- **Fix:** Add `status` enum (normal/sakit/izin/tidakAbsen) to `_DailySummary`. When status ≠ normal,
  render a single-status badge row instead of the 4 time cells.

### BUG-002: Rekap Harian — --:-- on masuk/pulang fields [HIGH]
- **Where:** `admin_reports_screen.dart` → `_computeDailySummaries()`
- **Root cause:** Pagination! Data fetched in descending order, limit 50. For earlier dates
  in the range, `masuk` scan may not be in the first 50 records → `firstMasuk = null` → shows `--:--`.
- **Fix:** Rekap Harian tab must fetch ALL data for the date range (separate query, no pagination limit,
  or use a higher limit). Per-scan tab keeps pagination. Or separate the two queries entirely.

### BUG-003: Midnight/Cross-day shift grouping [MEDIUM]
- **Where:** `_computeDailySummaries()` — groups by local-timezone date of `scanned_at`
- **Root cause:** Employee on 22:00–06:00 shift has masuk on Day 1, pulang on Day 2. These land
  in different day buckets → Day 1 shows masuk+no pulang (--:--), Day 2 shows pulang+no masuk.
- **Fix:** Implement "shift day anchor" — if pulang occurs before 12:00 next day, attach it to
  the masuk's date group. Also handle auto-pulang for lupa absen.

## Key Architecture Rules (DO NOT BREAK)
- `supabaseReady` bool must gate all Supabase calls
- `loadSession()` must always set `isLoading = false` in `finally`
- `SharedPreferences` NOT `FlutterSecureStorage` (causes ANR)
- NFC init has 3s timeout in main() — never blocks startup
- MethodChannel notification is PRIMARY; flutter_local_notifications is FALLBACK only
- Both use ID=300 — never create both simultaneously
- Kotlin 1.9.x syntax: `catch (e: Exception)` NOT `catch (_: Exception)`
- GoRouter: `/admin/login` must ALWAYS be accessible before kiosk check

## Brand & Design Direction
- **Brand:** Ayam Guling Enakko (Indonesian restaurant chain)
- **Color:** `AppColors.primary` — warm amber/orange tones (restaurant brand)
- **Design language:** Minimalist-professional, NOT generic AI aesthetic
  - Cards with subtle shadows, clean typography, purposeful whitespace
  - Luxury "polished" feel — like a premium POS system
  - Animations: subtle, ambient, not intrusive (especially on kiosk idle screen)
- **Logo:** Replace placeholder with Ayam Guling Enakko brand logo (asset to be provided)

## Flutter Overlay / Live Activity Implementation Plan
The app already has `flutter_overlay_window` package + `overlay_task.dart` entry point.
The existing `KioskNotificationHelper.kt` does Grab-style RemoteViews notification (ID=300).
The user wants a **floating pill overlay** (separate from notification) showing:
  - Gerai (outlet name)
  - Waktu scan (time)
  - Nama karyawan + status (masuk/istirahat/pulang)

**Approach:** Enhance `overlay_task.dart` with a properly designed overlay widget.
Show on NFC scan success → auto-hide after 3s. Uses `SYSTEM_ALERT_WINDOW` permission
(already granted in manifest). This is separate from the notification system.
Do NOT use `live_activities` package (adds iOS complexity for Android-only app).
Platform channel: `com.enakko.kiosk/notification` → show/update/dismiss.

## Schedule System Status
- `schedules` and `schedule_entries` tables exist with correct schema
- The Flutter UI (`shift_scheduler_screen.dart`) has code but writes to SQLite only (local)
- DB has 0 schedules — the system has never successfully persisted a schedule to Supabase
- Need to fix: schedule creation must write to Supabase, not just local state

## PDF Report Design Direction
- Use `pdf` package (already in pubspec.yaml)
- Enakko brand header (logo + colors)
- Summary section: total present, total absent, avg hours worked, total overtime
- Per-employee table: name | days present | avg masuk | avg pulang | late count | sakit days
- Visual: clean table layouts, colored status badges, brand footer
- File name: `laporan_absensi_YYYYMMDD_YYYYMMDD.pdf`

## Feature Ideas (Suggested based on DB analysis)
1. **Auto-pulang reminder** — employee has masuk but no pulang after 10h → flag in admin
2. **Time-off approval workflow** — `time_off_requests` schema exists; build UI for approve/reject
3. **Keterlambatan tracking** — flag employees who scan masuk > 15min past shift start
4. **Cross-outlet visibility** — `is_backup` column already exists; add filter in admin reports
5. **Attendance rate card** — quick % card on admin dashboard (hadir today / total employees)
6. **Employee streak** — consecutive present days (gamification for morale)
