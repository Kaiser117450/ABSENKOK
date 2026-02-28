# REQUIREMENTS.md — Absensi Enakko

## Scope
This requirements document covers the next development cycle:
bug fixes → live activity overlay → enhanced PDF reports → UI/UX polish → schedule system.

---

## M1 — Bug Fix + Edge Case Handling

### REQ-M1-01: Fix Rekap Harian — Sakit/Izin Status Display
**Priority:** Critical
**What:** When an employee's only attendance for a day is `sakit` or `izin`, the daily
summary tile must NOT show Masuk/Pulang/Kerja/Istirahat cells. Instead, show a clear
status badge (🤒 Sakit / 📋 Izin) with the notes/reason field if available.

**Acceptance:**
- [ ] Day with only `sakit` scan → shows red "🤒 Sakit" badge, not 4 time cells
- [ ] Day with only `izin` scan → shows blue "📋 Izin" badge, not 4 time cells
- [ ] Notes from `attendance_logs.notes` displayed below the badge
- [ ] Days with mixed scans (masuk + sakit erroneously) → show masuk normally

---

### REQ-M1-02: Fix Rekap Harian — --:-- from Pagination
**Priority:** Critical
**What:** Rekap Harian must compute summaries from the FULL dataset for the date range,
not from a paginated slice. The per-scan tab keeps pagination (50 per page). The daily
summary tab uses a separate unlimited fetch.

**Acceptance:**
- [ ] Selecting 7-day range with 14 employees → all employees appear in Rekap Harian with correct times
- [ ] No `--:--` on masuk for days where the employee definitely scanned in
- [ ] Loading indicator shown while fetching complete dataset for Rekap Harian
- [ ] Rekap Harian data independent from Per-Scan pagination state

---

### REQ-M1-03: Midnight Shift / Cross-Day Grouping
**Priority:** High
**What:** If an employee scans `masuk` before midnight and `pulang` after midnight (next day),
the daily summary must group them together as one work session anchored to the masuk date.

**Logic:**
- If `pulang` time is before 12:00 (noon) of the day after `masuk`, attach pulang to masuk's day
- This handles 22:00–06:00 and 20:00–04:00 type shifts

**Acceptance:**
- [ ] Masuk at 22:00 Oct 15 + Pulang at 06:00 Oct 16 → shows as one Oct 15 entry with 8j kerja
- [ ] Masuk at 08:00 Oct 15 + Pulang at 17:00 Oct 15 → unchanged (same-day)
- [ ] Multiple cross-day sessions in same date range handled correctly

---

### REQ-M1-04: Lupa Absen Pulang (Forgot Clock-Out) Handling
**Priority:** High
**What:** When a new day starts (midnight) and an employee still has an open `masuk` with no `pulang`:
- Admin dashboard flags these as "Belum Pulang" (did not clock out)
- The kiosk does NOT auto-generate a fake pulang record
- In Rekap Harian: show masuk time with "Belum Pulang" instead of `--:--` on pulang field
- New day's kiosk session resets normally — employee must scan masuk again

**Acceptance:**
- [ ] Employee with masuk+no pulang in Rekap Harian shows "Belum Pulang" badge (not --:--)
- [ ] New calendar day → kiosk NFC scan starts fresh (no state carryover)
- [ ] Admin can see list of "open shifts" (employees who clocked in but not out yesterday)

---

### REQ-M1-05: 24-Hour Outlet Shift Cycle
**Priority:** Medium
**What:** Some outlets operate 24 hours. The NFC scan sequence (masuk → break → kembali → pulang)
must NOT reset based on clock midnight. The reset trigger is:
- When the PREVIOUS SHIFT's `pulang` has been recorded, OR
- More than 24 hours since the last `masuk` (safety net)

**Logic:** On NFC tap, check last attendance log for this employee at this outlet:
- If no recent log (>24h) → force masuk regardless of time
- If last log was `masuk` → offer break or pulang
- If last log was `break` → offer kembali or pulang
- If last log was `pulang` (or kembali after pulang) → new masuk cycle

**Acceptance:**
- [x] Employee on 22:00–06:00 shift can scan pulang at 06:30 without kiosk resetting to masuk mid-shift
- [x] After pulang recorded → next scan is always masuk (regardless of time)
- [x] 24h safety net: if masuk > 24h ago with no pulang, next scan = masuk (prevents infinite open session)

**Status: COMPLETE** — Implemented in Phase 2 Plan 01 (commit 83cc48d). `_loadLastAttendance` now uses `.gte('scanned_at', cutoff)` 24h window query instead of `isSameDay` check.

---

## M2 — Floating Pill Live Activity (Dynamic Island Style)

### REQ-M2-01: Floating Overlay Pill on Scan Success
**Priority:** Critical (main feature)
**What:** After a successful NFC scan, display a floating pill overlay that appears above
ALL other apps and the kiosk UI. This uses `flutter_overlay_window` (already in project).

**Content:**
```
┌────────────────────────────────────────────────┐
│  [Brand Logo]  Enakko · [Outlet Name]          │
│  ✅ Budi Santoso — Masuk  ·  07:32             │
└────────────────────────────────────────────────┘
```

**Status variants:**
- Masuk → green left accent, ✅ icon
- Istirahat → amber accent, ☕ icon
- Kembali → blue accent, 🔄 icon
- Pulang → gray/red accent, 🏠 icon
- Sakit → red accent, 🤒 icon

**Behavior:**
- Appears immediately after scan confirmation
- Slides in from top with spring animation
- Auto-dismisses after 3 seconds with fade-out
- Does NOT block kiosk interactions while visible
- Works above lock screen if device is in kiosk mode

**Acceptance:**
- [ ] Pill appears within 300ms of scan success
- [ ] Shows correct outlet name, employee name, type, and time
- [ ] Auto-dismisses after 3 seconds
- [ ] Slide-in + fade-out animation (smooth, < 400ms)
- [ ] Visible above other apps (SYSTEM_ALERT_WINDOW)
- [ ] Tapping pill dismisses it immediately

---

### REQ-M2-02: Overlay UI Design (Luxury Pill)
**Priority:** High
**What:** The overlay must look premium — not a default notification. Dark pill (dark background,
white text) or glass-morphism style. Brand colors as accent only.

**Design spec:**
- Background: semi-transparent dark (`rgba(15,15,15,0.92)`) with subtle blur OR brand dark card
- Border radius: fully rounded pill (border-radius: 50px equivalent)
- Left accent bar colored by attendance type
- Compact height: ~56dp
- Width: 90% of screen width, centered
- Subtle drop shadow for depth
- Brand micro-logo (24dp) on left

**Acceptance:**
- [ ] Pill is visually distinct from system notifications
- [ ] Colors correctly reflect attendance type
- [ ] Does not look like a standard Android notification
- [ ] Readable on both light and dark kiosk backgrounds

---

## M3 — PDF Export + Enhanced Reports

### REQ-M3-01: PDF Export with Insights
**Priority:** High
**What:** Add "Export PDF" button alongside existing "Export CSV" in the reports screen.
PDF generates a professional attendance report for the selected date range.

**PDF Structure:**
```
[Page 1 — Summary]
  Brand header (logo + "Laporan Absensi" + date range)

  INSIGHT CARDS (2×2 grid):
  ┌──────────────┐ ┌──────────────┐
  │ 📊 Total     │ │ ✅ Hadir     │
  │ 248 hari     │ │ 91.2%        │
  └──────────────┘ └──────────────┘
  ┌──────────────┐ ┌──────────────┐
  │ ⏱ Rata-rata  │ │ 🤒 Tidak     │
  │ 8j 12m/hari  │ │ Hadir 22x    │
  └──────────────┘ └──────────────┘

  Outlet: [selected outlet or "Semua Outlet"]
  Generated: [timestamp]

[Page 2+ — Per-Employee Detail Table]
  Columns: Nama | Total Hadir | Avg Masuk | Avg Pulang | Total Kerja | Sakit | Terlambat
  Alternating row colors for readability
  Footer: page number
```

**Acceptance:**
- [ ] PDF generates without error for any date range
- [ ] Summary insights computed correctly
- [ ] Per-employee table sorted by name
- [ ] Enakko branding in header/footer
- [ ] File shared via `share_plus` as `.pdf`
- [ ] Generates in < 5 seconds for 30-day range, 14 employees

---

### REQ-M3-02: CSV Export Improvement
**Priority:** Medium
**What:** The existing CSV export only exports Per-Scan data. Add ability to export the
Rekap Harian summary as CSV too, and indicate which tab is active when user taps export.

**Acceptance:**
- [ ] "Export CSV" on Per-Scan tab → exports scan list (existing behavior, unchanged)
- [ ] "Export CSV" on Rekap Harian tab → exports one row per employee-day with computed fields
- [ ] Rekap Harian CSV columns: Nama, Outlet, Tanggal, Masuk, Pulang, Durasi Kerja, Istirahat, Status

---

## M4 — UI/UX Polish

### REQ-M4-01: NFC Idle Screen — Ambient Background Animation
**Priority:** High
**What:** The kiosk idle screen currently has a pulse animation on the NFC ring but the
background is static. Add a subtle ambient background animation that:
- Is NOT distracting (kiosk must remain professional)
- Creates a "premium, alive" feel
- Suggests technology / connectivity
- Works at 24/7 without performance degradation

**Approach:** Layered gradient mesh that slowly shifts positions (10–20s cycle).
Subtle radial glow that breathes (scale + opacity). NO particles (too much CPU for kiosk).

**Acceptance:**
- [ ] Background visibly animated but not distracting
- [ ] Animation uses const AnimationController + dispose (no memory leak)
- [ ] Does not degrade NFC responsiveness
- [ ] Consistent FPS (no jank) after 1 hour continuous

---

### REQ-M4-02: Brand Logo on Idle Screen
**Priority:** Medium
**What:** Replace the top-left placeholder logo on `KioskIdleScreen` with the Ayam Guling
Enakko brand logo asset.

**Acceptance:**
- [ ] `assets/images/logo_enakko.png` (or .svg) loaded from assets
- [ ] Logo visible and correct on idle screen header
- [ ] Proper sizing: ~100×40dp, aspect ratio maintained

---

### REQ-M4-03: Overall Admin UI Polish
**Priority:** Medium
**What:** Systematically polish admin screens to feel refined/premium without changing layout:
- Cards: consistent 12dp border radius, subtle box shadow
- Typography: section headers 500 weight, data values 700 weight
- Color usage: primary color used intentionally (not everywhere)
- Empty states: illustration + helpful copy
- Loading states: shimmer skeletons (not raw CircularProgressIndicator everywhere)
- Admin reports: improve the filter panel visual hierarchy

**Acceptance:**
- [ ] Admin dashboard card grid looks polished
- [ ] Reports screen filter panel has clear visual hierarchy
- [ ] Employee list cards have consistent avatar + content layout
- [ ] Shimmer skeleton on initial data loads (dashboard, reports)
- [ ] Toast/snackbar styling consistent with brand

---

## M5 — Schedule System + Advanced Features

### REQ-M5-01: Fix Schedule Persistence to Supabase
**Priority:** High
**What:** The schedule system writes to SQLite only — `schedules` and `schedule_entries`
tables in Supabase have 0 rows. Fix the schedule creation flow to write to Supabase.

**Acceptance:**
- [ ] Creating a schedule → inserts row in `schedules` table
- [ ] Adding employee assignments → inserts rows in `schedule_entries`
- [ ] Fetching schedules → reads from Supabase with offline SQLite fallback
- [ ] Schedule visible in admin across devices (not just one device)

---

### REQ-M5-02: Schedule UI Rewrite
**Priority:** Medium
**What:** The current `shift_scheduler_screen.dart` layout has UX issues. Redesign for clarity:
- Week-view grid: employees on Y-axis, days on X-axis
- Tap a cell → assign shift (Pagi/Sore/Malam/Libur)
- Color-coded by shift type
- Bulk assign: select multiple employees, click "Assign Pagi This Week"

**Acceptance:**
- [ ] Week grid renders correctly with all employees
- [ ] Tap-to-assign works for each cell
- [ ] Save/publish button commits to Supabase

---

### REQ-M5-03: Auto-Flag Missing Clock-Out
**Priority:** Medium
**What:** Admin dashboard shows a "Perlu Perhatian" section:
- Employees who scanned masuk yesterday but have no pulang
- Allows admin to manually add a pulang record with a note ("Lupa absen")

**Acceptance:**
- [ ] Dashboard shows count of "open shifts" from yesterday
- [ ] Tap → see list of employees with open shifts
- [ ] Admin can manually close the shift with notes

---

### REQ-M5-04: Sakit/Izin — Direct Input by Kepala Gerai (No Approval Step)
**Priority:** Medium
**What:** Kepala Gerai langsung bisa memasukkan status sakit/izin untuk karyawan pada
hari tertentu — **tanpa perlu approval**. Kepala Gerai adalah authority-nya sendiri.

**Flow:**
- Di layar admin (atau dari kiosk admin mode) → pilih karyawan + tanggal + sakit/izin + catatan
- Langsung insert `attendance_log` dengan type `sakit` atau `izin` + notes
- Tampil di Rekap Harian sebagai badge status (bukan 4 kolom waktu)

**Note:** `time_off_requests` table diabaikan untuk flow ini — terlalu kompleks untuk kebutuhan aktual.

**Acceptance:**
- [ ] Kepala gerai bisa set sakit/izin dari admin panel in < 3 tap
- [ ] Catatan (alasan) bisa diisi opsional
- [ ] Status langsung muncul di Rekap Harian karyawan tersebut
- [ ] Bisa di-set untuk tanggal lampau (kemarin, minggu lalu)
- [ ] Bisa di-hapus/edit jika salah

---

### REQ-M5-05: Employee Badge System
**Priority:** Medium
**What:** Setiap karyawan bisa diberikan badge khusus (border custom + emoji) yang tampil
sebagai cincin berwarna di foto profil mereka. Badge membuat karyawan merasa diapresiasi.

**Database:** ✅ Sudah dimigrasikan ke Supabase
```sql
badges table       — id, name, description, emoji, border_color, border_color2, border_style
employees.active_badge_id — FK ke badges
```

**Default badges yang sudah ada di DB:**
| Badge | Emoji | Border |
|-------|-------|--------|
| Employee of the Month | 🏆 | Gold gradient |
| Star Performer | ⭐ | Purple gradient |
| Hadir Sempurna | 💯 | Green gradient |
| Team Captain | 👑 | Red glow |
| Veteran | 🎖️ | Gray solid |

**Badge Display — Tampil di:**
1. **Kiosk scan success screen** — foto karyawan dengan ring berwarna + emoji badge di pojok kanan bawah avatar
2. **Admin employee list** — avatar dengan ring tipis (2px) berwarna badge
3. **Rekap Harian tile** — avatar kecil dengan ring badge
4. **Floating pill overlay** — emoji badge setelah nama karyawan
5. **PDF report** — badge name tercantum di kolom tabel

**Admin Flow — Assign Badge:**
- Admin/Kepala Gerai buka profil karyawan
- Pilih badge dari list (atau hapus badge)
- Simpan → update `employees.active_badge_id`
- Perubahan langsung terlihat di semua layar

**Border Rendering (Flutter):**
```dart
// solid  → BoxDecoration border dengan warna tunggal
// gradient → ShaderMask / gradient border menggunakan CustomPaint
// glow   → BoxDecoration + BoxShadow spread dengan warna badge
```

**Acceptance:**
- [ ] Admin bisa assign badge ke karyawan dari layar employee detail
- [ ] Karyawan tanpa badge → foto tampil normal (no ring)
- [ ] Karyawan dengan badge → foto tampil dengan colored ring sesuai badge
- [ ] Ring style: solid / gradient / glow sesuai badge definition
- [ ] Emoji badge muncul di pojok avatar (small chip overlay)
- [ ] Badge label ("Employee of the Month") tampil di kiosk scan result
- [ ] Admin bisa buat badge custom (nama, warna, emoji) dari admin panel
- [ ] Hapus badge dari karyawan → kembali ke avatar normal

---

## Non-Functional Requirements

### Performance
- App startup to NFC-ready state: < 3 seconds
- NFC scan to feedback: < 500ms
- Supabase sync never blocks UI (always background)
- PDF export: < 5s for 30-day, 14-employee report
- Overlay pill: < 300ms from scan confirmation to visible

### Reliability
- `isLoading` always cleared in `finally` blocks (existing rule)
- `supabaseReady` gate on all Supabase calls (existing rule)
- Overlay must dismiss even if scan data is incomplete
- PDF export must handle null employee/outlet gracefully

### Security
- No sensitive data in overlay (no salary, no personal ID)
- RLS policies verified on all tables (existing rule)
- Supabase anon key never logged or exposed

### Constraints
- Kotlin 1.9.25 — NO upgrade to 2.x
- `catch (e: Exception)` — NOT `catch (_: Exception)`
- SharedPreferences for session (NOT FlutterSecureStorage)
- Notification ID=300: MethodChannel is PRIMARY, flutter_local_notifications FALLBACK only
