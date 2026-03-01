# ROADMAP.md â€” Absensi Enakko

## Milestone 1 â€” Bug Fix + Edge Cases (v1.1)
**Goal:** Eliminate all production bugs in reports and kiosk scan cycle.
All bugs confirmed from code analysis + live database data.

### Phase 1: Rekap Harian Bug Fixes
**Goal:** Rekap Harian tab shows accurate, correct data for all attendance types.

**Plans:** 1 plan

Plans:
- [ ] 01-01-PLAN.md â€” Fix all three Rekap Harian bugs: separate daily data fetch, cross-day noon-rule grouping, and sakit/izin badge rendering

**Tasks:**
1. Add `status` field (normal/sakit/izin/tidakHadir/belumPulang) to `_DailySummary` class
2. In `_computeDailySummaries()`: detect sakit/izin-only days â†’ set status accordingly
3. In `_DailySummaryTile`: branch rendering â€” if status=sakit/izin â†’ show badge UI, not 4 cells
4. Separate Rekap Harian fetch from Per-Scan pagination: add `_loadAllForSummary()` that fetches complete dataset (no limit) for daily summary computation
5. Fix cross-day shift grouping: if `pulang` time is before noon next day â†’ attach to masuk's date bucket

**UAT:**
- Karyawan dengan status sakit â†’ tampil badge "ðŸ¤’ Sakit" bukan 4 kolom waktu
- Rentang 7 hari dengan 14 karyawan â†’ semua masuk/pulang terisi benar (tidak ada --:--)
- Shift malam (22:00â€“06:00) â†’ tampil sebagai satu sesi kerja di hari masuk

---

### Phase 2: Kiosk Scan Cycle Edge Cases
**Goal:** Kiosk handles forgot-clock-out, midnight transitions, and 24h outlets correctly.

**Plans:** 3 plans

Plans:
- [x] 02-01-PLAN.md â€” Fix 24h shift cycle: replace isSameDay with 24h window query in kiosk_scan_screen.dart _loadLastAttendance (DONE: 83cc48d)
- [ ] 02-02-PLAN.md â€” Add belumPulang status to Rekap Harian: enum variant, detection logic, amber tile rendering
- [ ] 02-03-PLAN.md â€” Admin dashboard Open Shifts widget: _loadOpenShifts, _manualPulang, _buildOpenShiftsWidget

**Tasks:**
1. Refactor last-scan logic in `kiosk_idle_screen.dart`: check last log for employee within 24h window (not just "today")
2. Implement 24h safety net: if last masuk > 24h ago with no pulang â†’ next scan = masuk regardless
3. In Rekap Harian: distinguish `firstMasuk != null && lastPulang == null` â†’ show "Belum Pulang" badge
4. Add "Open Shifts" widget to admin dashboard: fetch employees with masuk yesterday, no pulang
5. Allow admin to manually create pulang record with notes ("Lupa absen pulang")

**UAT:**
- Karyawan lupa absen pulang â†’ hari berikutnya bisa masuk normal
- Rekap Harian menampilkan "Belum Pulang" untuk karyawan yang tidak absen pulang
- Admin dapat menutup shift manual dengan catatan
- Gerai 24 jam: karyawan shift malam bisa pulang di hari berikutnya tanpa masalah

---

## Milestone 2 â€” Floating Pill Live Activity (v1.2)
**Goal:** Persistent live-activity floating pill appears above other apps when Absensi Enakko is minimized/backgrounded.
This is the signature UX feature â€” "Dynamic Island" feel for kiosk attendance.
use the principle of live activity from grab in this website https://engineering.grab.com/live-activity-2

### Phase 3: Overlay Pill Implementation
**Goal:** Persistent floating attendance pill overlay behaves like live activity when app is minimized/backgrounded.

**Plan Progress:** 3/4 complete

Plans:
- [x] 03-01-PLAN.md â€” Overlay payload contract model + parser/serializer tests (DONE: 96afaab)
- [x] 03-02-PLAN.md â€” Overlay controller idempotent show/update flow + typed service payload updates (DONE: 13bd1f5)
- [x] 03-03-PLAN.md - Overlay isolate typed state-machine + premium compact pill UI + widget tests (DONE: c4e97b7)
- [ ] 03-04-PLAN.md

**Tasks:**
1. Refactor overlay state in `overlay_task.dart` to support persistent idle pill + event transition state:
   - Persistent idle state remains visible above other apps
   - Expanded/minimized toggle by tap
   - Compact dark pill (~56dp), brand micro-logo, outlet, type + accent, and time
2. Keep premium transition feel (slide/fade + spring) for state changes, while prioritizing persistent stability
3. Ensure event state returns to persistent idle state (not full overlay dismiss)
4. Wire lifecycle/background triggers (`app.dart` + `kiosk_background_service.dart`) so overlay shows on app minimize/background
5. Add foreground visibility setting (hide vs keep overlay when app is active)
6. Harden permission flow:
   - Guided SYSTEM_ALERT_WINDOW prompt with OEM guidance (MIUI/HyperOS, etc.)
   - Re-check permission each kiosk start
7. Fallback UX:
   - Show toast warning when overlay render/show fails
8. Test on real kiosk devices and OEM variants (emulator behavior differs for overlays)

**UAT:**
- Saat aplikasi di-minimize/background â†’ pil live-activity muncul di atas aplikasi lain
- Pil tetap terlihat (persistent idle) sampai user/app menyembunyikannya
- Tap pil mengubah mode expanded/minimized
- Jenis absen + warna aksen terlihat di pill persistent
- Transisi state tetap halus tanpa mengganggu aplikasi lain
- Jika izin overlay belum ada, user mendapat panduan jelas untuk mengaktifkan
- Jika overlay gagal tampil, user mendapat toast peringatan

---

## Milestone 3 â€” PDF Reports + Export (v1.3)
**Goal:** Professional PDF attendance report with insights. Export both CSV (per-scan + summary) and PDF.

### Phase 4: PDF Export Engine
**Goal:** Generate branded PDF report with summary insights and per-employee table.

**Tasks:**
1. Create `pdf_report_service.dart` (rename/replace existing `pdf_service.dart`):
   - `generateAttendanceReport(List<_DailySummary> summaries, DateRange range, String outletName)`
   - Compute: totalHadir, attendanceRate%, avgWorkHours, totalSakit
2. Build PDF Page 1 â€” Summary:
   - Header: Enakko logo + "Laporan Absensi" + tanggal range + outlet
   - 4 insight cards in 2Ã—2 grid (hadir%, avg jam kerja, ketidakhadiran, total scan)
   - Generation timestamp
3. Build PDF Page 2+ â€” Per-Employee Table:
   - Columns: No | Nama | Hadir | Avg Masuk | Avg Pulang | Total Jam | Sakit
   - Alternating row colors, bold header
   - Sort by employee name
   - Page break if > 25 rows per page
4. Export button in reports screen: "Export PDF" button next to existing CSV button
5. Wire to `Share.shareXFiles()` with mimeType `application/pdf`

**UAT:**
- Klik Export PDF â†’ PDF ter-generate dan share sheet muncul
- Summary insight angka akurat sesuai data rekap
- Tabel per-karyawan lengkap dan terbaca
- Branding Enakko ada di header
- Generate < 5 detik untuk range 30 hari

---

### Phase 5: CSV Rekap Harian + Export Tab Awareness
**Goal:** Export CSV exports the correct data based on active tab.

**Tasks:**
1. Detect active tab in export bar: `_tabCtrl.index == 0` â†’ scan list CSV, `== 1` â†’ rekap harian CSV
2. Implement Rekap Harian CSV: one row per employee-day with computed fields
3. Update export button label: "Export CSV Scan" / "Export CSV Rekap" based on active tab
4. Add tooltip explaining each export type

**UAT:**
- Di tab Per Scan â†’ Export CSV menghasilkan data per-scan (existing)
- Di tab Rekap Harian â†’ Export CSV menghasilkan satu baris per karyawan-hari
- Label tombol berubah sesuai tab aktif

---

## Milestone 4 â€” UI/UX Polish (v1.4)
**Goal:** Visually polished, premium feel across the entire app. Kiosk idle screen becomes distinctly beautiful.

### Phase 6: NFC Idle Screen Visual Enhancement
**Goal:** Idle screen feels like a premium kiosk product, not a demo app.

**Tasks:**
1. Implement ambient background animation:
   - 3-layer gradient mesh with `AnimationController` (20s cycle, repeat)
   - Layer 1: slow-shifting base gradient (warm dark â†’ neutral dark)
   - Layer 2: breathing radial glow at center (scale 0.8â†’1.1, opacity 0.3â†’0.6, 8s cycle)
   - Layer 3: subtle shimmer sweep (diagonal, every 15s)
   - All using `CustomPainter` for GPU-efficient rendering
2. Replace placeholder logo with `assets/images/logo_enakko.png`
   - Add asset to `pubspec.yaml`
   - Correct sizing: ~120Ã—48dp in top area of idle screen
3. Polish NFC ring widget:
   - Gradient ring (brand color â†’ lighter shade)
   - Inner glow on detected state
4. Improve typography hierarchy:
   - "Tempelkan kartu NFC" â€” larger, lighter weight
   - Outlet name â€” brand color accent
   - Time display (if shown) â€” monospace, large

**UAT:**
- Background beranimasi halus dan tidak mengganggu
- Logo brand terlihat jelas di kiosk
- Tampilan keseluruhan terasa premium dan profesional
- Tidak ada jank/lag setelah 30 menit berjalan

---

### Phase 7: Admin UI System Polish
**Goal:** Admin screens feel consistent, polished, and professional throughout.

**Tasks:**
1. Create `AppWidgets` library:
   - `AppCard` â€” consistent card with shadow + border radius
   - `ShimmerSkeleton` â€” loading placeholder for lists
   - `AppEmptyState` â€” icon + heading + subtext
   - `AppBadge` â€” colored status chip (Hadir/Sakit/Izin/BelumPulang)
2. Apply to admin_reports_screen: shimmer on load, consistent card styling
3. Apply to admin_employees_screen: avatar sizing, position badge, shimmer list
4. Apply to admin_dashboard_screen: metric cards with proper shadow + icon
5. Toast/snackbar: replace raw SnackBar with `toastification` consistently
6. Admin shell bottom nav: active indicator polish (brand color pill indicator)

**UAT:**
- Semua layar admin menggunakan card style yang sama
- Loading state menampilkan shimmer skeleton (bukan loading spinner sendiri)
- Empty state informatif dengan ilustrasi kecil
- Toast muncul konsisten di semua aksi admin

---

## Milestone 5 â€” Schedule System + Advanced Features (v1.5)
**Goal:** Schedule system works end-to-end. Auto-flag for missing clock-outs. Time-off request workflow.

### Phase 8: Schedule System Fix + Supabase Integration
**Goal:** Schedules are persisted to Supabase and visible across all admin devices.

**Tasks:**
1. Fix `shift_scheduler_screen.dart` save flow: write to `schedules` + `schedule_entries` Supabase tables
2. Rebuild schedule grid UI: week-view grid (employees Ã— days), color-coded by shift type
3. Implement bulk assign: select all â†’ assign Pagi/Sore/Malam/Libur
4. Fetch schedule for week from Supabase on screen open
5. Add `schedule_sqlite_service.dart` sync: cache schedules locally for offline access

**UAT:**
- Buat jadwal untuk minggu ini â†’ tersimpan di Supabase (cek dashboard)
- Buka layar jadwal di device lain â†’ data sama
- Grid week-view tampil dengan warna shift yang benar
- Assign bulk untuk 5 karyawan dalam 2 klik

---

### Phase 9: Direct Sakit/Izin Input + Auto-Flag + Badge System
**Goal:** Kepala Gerai bisa langsung set sakit/izin tanpa approval. Admin punya visibility
open shifts. Karyawan bisa diberikan badge khusus yang tampil di profil mereka.

**Tasks:**

**Sakit/Izin Direct Input:**
1. Di layar employee detail (admin) â†’ tambah tombol "Set Sakit/Izin"
2. Picker: pilih tanggal + type (sakit/izin) + catatan opsional
3. Direct insert ke `attendance_logs` dengan type sakit/izin â€” no approval step
4. Bisa edit/hapus record sakit/izin yang sudah dibuat
5. Tampil langsung di Rekap Harian sebagai badge status

**Auto-Flag Open Shifts:**
6. Admin dashboard "Perlu Perhatian" section
7. Fetch employees: masuk kemarin + no pulang
8. Manual close shift: admin input jam pulang + catatan "lupa absen"
9. Attendance rate widget: hadir hari ini / total karyawan aktif

**Badge System:**
10. Model & service: `Badge` model, `BadgeService` untuk fetch dari Supabase
11. `BadgeAvatar` widget: avatar dengan ring berwarna berdasarkan badge type
    - solid â†’ Border biasa
    - gradient â†’ CustomPaint gradient ring
    - glow â†’ BoxShadow spread
12. Badge emoji chip: pojok kanan bawah avatar
13. Admin employee detail: badge picker (list badges â†’ tap assign)
14. Admin badge management: CRUD badge definitions (nama, warna, emoji, style)
15. Tampilkan badge di: scan success screen, employee list, rekap harian, overlay pill
16. Badge di PDF report: kolom "Badge" di tabel per-karyawan

**UAT:**
- Kepala gerai set sakit untuk karyawan â†’ langsung muncul di Rekap Harian hari itu
- Karyawan yang lupa pulang kemarin â†’ muncul di dashboard "Perlu Perhatian"
- Assign "Employee of the Month" ke karyawan â†’ foto tampil dengan gold gradient ring
- Emoji ðŸ† muncul di pojok avatar di semua tampilan karyawan tersebut
- Buat badge custom dari admin â†’ tersimpan dan bisa di-assign
- Dashboard menampilkan persentase kehadiran hari ini

---

## Future Backlog (Not Scheduled)
- Push notification when employee doesn't clock out by X hours
- Employee attendance streak tracking (gamification)
- Cross-outlet attendance comparison chart
- Keterlambatan (late arrival) automatic flagging vs shift start time
- Overtime tracking (> 8h kerja â†’ overtime flag)
- WhatsApp/email daily attendance summary for outlet managers
- QR code backup when NFC fails (camera scan)
- Employee self-service portal (view own attendance history)

---

## Release Schedule Estimate
| Milestone | Phases | Estimated Effort |
|-----------|--------|-----------------|
| v1.1 â€” Bug Fixes | 1â€“2 | 2â€“3 days |
| v1.2 â€” Live Pill | 3 | 3â€“4 days |
| v1.3 â€” PDF Reports | 4â€“5 | 2â€“3 days |
| v1.4 â€” UI Polish | 6â€“7 | 3â€“4 days |
| v1.5 â€” Schedule + Advanced | 8â€“9 | 4â€“5 days |

