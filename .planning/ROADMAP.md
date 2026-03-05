# ROADMAP.md — Absensi Enakko

## Milestone 1 — Bug Fix + Edge Cases (v1.1)
**Goal:** Eliminate all production bugs in reports and kiosk scan cycle.
All bugs confirmed from code analysis + live database data.

### Phase 1: Rekap Harian Bug Fixes
**Goal:** Rekap Harian tab shows accurate, correct data for all attendance types.

**Plans:** 1 plan

Plans:
- [ ] 01-01-PLAN.md — Fix all three Rekap Harian bugs: separate daily data fetch, cross-day noon-rule grouping, and sakit/izin badge rendering

**Tasks:**
1. Add `status` field (normal/sakit/izin/tidakHadir/belumPulang) to `_DailySummary` class
2. In `_computeDailySummaries()`: detect sakit/izin-only days → set status accordingly
3. In `_DailySummaryTile`: branch rendering — if status=sakit/izin → show badge UI, not 4 cells
4. Separate Rekap Harian fetch from Per-Scan pagination: add `_loadAllForSummary()` that fetches complete dataset (no limit) for daily summary computation
5. Fix cross-day shift grouping: if `pulang` time is before noon next day → attach to masuk's date bucket

**UAT:**
- Karyawan dengan status sakit → tampil badge "🤒 Sakit" bukan 4 kolom waktu
- Rentang 7 hari dengan 14 karyawan → semua masuk/pulang terisi benar (tidak ada --:--)
- Shift malam (22:00–06:00) → tampil sebagai satu sesi kerja di hari masuk

---

### Phase 2: Kiosk Scan Cycle Edge Cases
**Goal:** Kiosk handles forgot-clock-out, midnight transitions, and 24h outlets correctly.

**Plans:** 3 plans

Plans:
- [x] 02-01-PLAN.md — Fix 24h shift cycle: replace isSameDay with 24h window query in kiosk_scan_screen.dart _loadLastAttendance (DONE: 83cc48d)
- [ ] 02-02-PLAN.md — Add belumPulang status to Rekap Harian: enum variant, detection logic, amber tile rendering
- [ ] 02-03-PLAN.md — Admin dashboard Open Shifts widget: _loadOpenShifts, _manualPulang, _buildOpenShiftsWidget

**Tasks:**
1. Refactor last-scan logic in `kiosk_idle_screen.dart`: check last log for employee within 24h window (not just "today")
2. Implement 24h safety net: if last masuk > 24h ago with no pulang → next scan = masuk regardless
3. In Rekap Harian: distinguish `firstMasuk != null && lastPulang == null` → show "Belum Pulang" badge
4. Add "Open Shifts" widget to admin dashboard: fetch employees with masuk yesterday, no pulang
5. Allow admin to manually create pulang record with notes ("Lupa absen pulang")

**UAT:**
- Karyawan lupa absen pulang → hari berikutnya bisa masuk normal
- Rekap Harian menampilkan "Belum Pulang" untuk karyawan yang tidak absen pulang
- Admin dapat menutup shift manual dengan catatan
- Gerai 24 jam: karyawan shift malam bisa pulang di hari berikutnya tanpa masalah

---

## Milestone 2 — Floating Pill Live Activity (v1.2)
**Goal:** Persistent live-activity floating pill appears above other apps when Absensi Enakko is minimized/backgrounded.
This is the signature UX feature — "Dynamic Island" feel for kiosk attendance.
use the principle of live activity from grab in this website https://engineering.grab.com/live-activity-2

### Phase 3: Overlay Pill Implementation
**Goal:** Persistent floating attendance pill overlay behaves like live activity when app is minimized/backgrounded.

**Plan Progress:** 3/4 complete

Plans:
- [x] 03-01-PLAN.md — Overlay payload contract model + parser/serializer tests (DONE: 96afaab)
- [x] 03-02-PLAN.md — Overlay controller idempotent show/update flow + typed service payload updates (DONE: 13bd1f5)
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
- Saat aplikasi di-minimize/background → pil live-activity muncul di atas aplikasi lain
- Pil tetap terlihat (persistent idle) sampai user/app menyembunyikannya
- Tap pil mengubah mode expanded/minimized
- Jenis absen + warna aksen terlihat di pill persistent
- Transisi state tetap halus tanpa mengganggu aplikasi lain
- Jika izin overlay belum ada, user mendapat panduan jelas untuk mengaktifkan
- Jika overlay gagal tampil, user mendapat toast peringatan

---

## Milestone 3 — PDF Reports + Export (v1.3)
**Goal:** Professional PDF attendance report with insights. Export both CSV (per-scan + summary) and PDF.

### Phase 4: PDF Export Engine
**Goal:** Generate branded PDF report with summary insights and per-employee table.

**Plans:** 2 plans

Plans:
- [ ] 04-01-PLAN.md — Extract DailySummary model to lib/models/ and build PdfReportService with insight stats + per-employee table
- [ ] 04-02-PLAN.md — Wire Export PDF button in admin reports screen + human verification

**Tasks:**
1. Create `pdf_report_service.dart` (rename/replace existing `pdf_service.dart`):
   - `generateAttendanceReport(List<_DailySummary> summaries, DateRange range, String outletName)`
   - Compute: totalHadir, attendanceRate%, avgWorkHours, totalSakit
2. Build PDF Page 1 — Summary:
   - Header: Enakko logo + "Laporan Absensi" + tanggal range + outlet
   - 4 insight cards in 2×2 grid (hadir%, avg jam kerja, ketidakhadiran, total scan)
   - Generation timestamp
3. Build PDF Page 2+ — Per-Employee Table:
   - Columns: No | Nama | Hadir | Avg Masuk | Avg Pulang | Total Jam | Sakit
   - Alternating row colors, bold header
   - Sort by employee name
   - Page break if > 25 rows per page
4. Export button in reports screen: "Export PDF" button next to existing CSV button
5. Wire to `Share.shareXFiles()` with mimeType `application/pdf`

**UAT:**
- Klik Export PDF → PDF ter-generate dan share sheet muncul
- Summary insight angka akurat sesuai data rekap
- Tabel per-karyawan lengkap dan terbaca
- Branding Enakko ada di header
- Generate < 5 detik untuk range 30 hari

---

### Phase 5: CSV Rekap Harian + Export Tab Awareness
**Goal:** Export CSV exports the correct data based on active tab.

**Tasks:**
1. Detect active tab in export bar: `_tabCtrl.index == 0` → scan list CSV, `== 1` → rekap harian CSV
2. Implement Rekap Harian CSV: one row per employee-day with computed fields
3. Update export button label: "Export CSV Scan" / "Export CSV Rekap" based on active tab
4. Add tooltip explaining each export type

**UAT:**
- Di tab Per Scan → Export CSV menghasilkan data per-scan (existing)
- Di tab Rekap Harian → Export CSV menghasilkan satu baris per karyawan-hari
- Label tombol berubah sesuai tab aktif

---

## Milestone 4 — UI/UX Polish (v1.4)
**Goal:** Visually polished, premium feel across the entire app. Kiosk idle screen becomes distinctly beautiful.

### Phase 6: NFC Idle Screen Visual Enhancement
**Goal:** Idle screen feels like a premium kiosk product, not a demo app.

**Plan Progress:** 2/2 complete

Plans:
- [x] 06-01-PLAN.md — Dark kiosk idle screen with 3-layer ambient background (gradient, glow, shimmer) using CustomPainter (DONE: fa1a2b2)
- [x] 06-02-PLAN.md — Brand logo, gradient NFC ring (_GradientRingPainter), monospace clock (GoogleFonts.robotoMono), premium typography (DONE: 613b39f)

**Tasks:**
1. Implement ambient background animation:
   - 3-layer gradient mesh with `AnimationController` (20s cycle, repeat)
   - Layer 1: slow-shifting base gradient (warm dark → neutral dark)
   - Layer 2: breathing radial glow at center (scale 0.8→1.1, opacity 0.3→0.6, 8s cycle)
   - Layer 3: subtle shimmer sweep (diagonal, every 15s)
   - All using `CustomPainter` for GPU-efficient rendering
2. Replace placeholder logo with `assets/images/logo_enakko.png`
   - Add asset to `pubspec.yaml`
   - Correct sizing: ~120×48dp in top area of idle screen
3. Polish NFC ring widget:
   - Gradient ring (brand color → lighter shade)
   - Inner glow on detected state
4. Improve typography hierarchy:
   - "Tempelkan kartu NFC" — larger, lighter weight
   - Outlet name — brand color accent
   - Time display (if shown) — monospace, large

**UAT:**
- Background beranimasi halus dan tidak mengganggu
- Logo brand terlihat jelas di kiosk
- Tampilan keseluruhan terasa premium dan profesional
- Tidak ada jank/lag setelah 30 menit berjalan

---

### Phase 7: Admin UI System Polish
**Goal:** Admin screens feel consistent, polished, and professional throughout.

**Plan Progress:** 3/3 complete

Plans:
- [x] 07-01-PLAN.md — Create reusable widget library: AppCard, ShimmerSkeleton, AppEmptyState, AppBadge, AppToast + badge color palette (DONE: b9d295d)
- [x] 07-02-PLAN.md — Apply widget library to admin_dashboard_screen + bottom nav polish (DONE: 66b959d)
- [x] 07-03-PLAN.md — Apply widget library to employees, reports, outlets, sakit_izin screens (DONE: 319b833, 6639b91)

**Tasks:**
1. Create `AppWidgets` library:
   - `AppCard` — consistent card with shadow + border radius
   - `ShimmerSkeleton` — loading placeholder for lists
   - `AppEmptyState` — icon + heading + subtext
   - `AppBadge` — colored status chip (Hadir/Sakit/Izin/BelumPulang)
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

## Milestone 5 — Schedule System + Advanced Features (v1.5)
**Goal:** Schedule system works end-to-end. Auto-flag for missing clock-outs. Time-off request workflow.

### Phase 8: Schedule System Fix + Supabase Integration
**Goal:** Schedules are persisted to Supabase and visible across all admin devices.

**Plans:** 1/3 plans executed

Plans:
- [x] 08-01-PLAN.md — Fix data flow: Supabase-first read, dual-write save, auto-generate draft indicator, SQLite date normalization (DONE: c9c4406, f644232)
- [x] 08-02-PLAN.md — Bulk assign UI: employee selection checkboxes, Select All, shift picker bottom sheet (DONE: 328c9fd)

**Tasks:**
1. Fix `shift_scheduler_screen.dart` save flow: write to `schedules` + `schedule_entries` Supabase tables
2. Rebuild schedule grid UI: week-view grid (employees × days), color-coded by shift type
3. Implement bulk assign: select all → assign Pagi/Sore/Malam/Libur
4. Fetch schedule for week from Supabase on screen open
5. Add `schedule_sqlite_service.dart` sync: cache schedules locally for offline access

**UAT:**
- Buat jadwal untuk minggu ini → tersimpan di Supabase (cek dashboard)
- Buka layar jadwal di device lain → data sama
- Grid week-view tampil dengan warna shift yang benar
- Assign bulk untuk 5 karyawan dalam 2 klik

---

### Phase 08.1: Perbaiki export laporan CSV/PDF: akurasi data waktu absen, bedakan export Per Scan vs Rekap Harian, dan sinkronkan format PDF dengan UI laporan (INSERTED)

**Goal:** [Urgent work - to be planned]
**Requirements**: TBD
**Depends on:** Phase 8
**Plans:** 2/2 plans complete

Plans:
- [x] TBD (run /gsd:plan-phase 08.1 to break down) (completed 2026-03-04)

### Phase 9: Direct Sakit/Izin Input + Auto-Flag + Badge System
**Goal:** Kepala Gerai bisa langsung set sakit/izin tanpa approval. Admin punya visibility
open shifts. Karyawan bisa diberikan badge khusus yang tampil di profil mereka.

**Tasks:**

**Sakit/Izin Direct Input:**
1. Di layar employee detail (admin) → tambah tombol "Set Sakit/Izin"
2. Picker: pilih tanggal + type (sakit/izin) + catatan opsional
3. Direct insert ke `attendance_logs` dengan type sakit/izin — no approval step
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
    - solid → Border biasa
    - gradient → CustomPaint gradient ring
    - glow → BoxShadow spread
12. Badge emoji chip: pojok kanan bawah avatar
13. Admin employee detail: badge picker (list badges → tap assign)
14. Admin badge management: CRUD badge definitions (nama, warna, emoji, style)
15. Tampilkan badge di: scan success screen, employee list, rekap harian, overlay pill
16. Badge di PDF report: kolom "Badge" di tabel per-karyawan

**UAT:**
- Kepala gerai set sakit untuk karyawan → langsung muncul di Rekap Harian hari itu
- Karyawan yang lupa pulang kemarin → muncul di dashboard "Perlu Perhatian"
- Assign "Employee of the Month" ke karyawan → foto tampil dengan gold gradient ring
- Emoji 🏆 muncul di pojok avatar di semua tampilan karyawan tersebut
- Buat badge custom dari admin → tersimpan dan bisa di-assign
- Dashboard menampilkan persentase kehadiran hari ini

---

### Phase 10: Sakit/Izin Direct Input (Gap Closure)
**Goal:** Kepala Gerai can directly set sakit/izin status for employees without approval workflow.
**Requirements:** REQ-M5-04
**Gap Closure:** Closes unsatisfied requirement from v1.1 audit
**Depends on:** Phase 1 (Rekap Harian badge rendering already works for sakit/izin)

**Plan Progress:** 2/2 complete

Plans:
- [x] 10-01-PLAN.md — Direct Supabase insert with offline fallback, edit mode, duplicate check, 30-day date range (DONE: caf166f)
- [x] 10-02-PLAN.md — Sakit/izin history list screen with edit/delete actions, employee card popup navigation (DONE: 6caaeb9, a95851a)

**Tasks:**
1. Admin employee detail → "Set Sakit/Izin" button with date picker, type selector (sakit/izin), optional notes
2. Direct insert to `attendance_logs` with type sakit/izin — no approval step needed
3. Edit/delete existing sakit/izin records from admin panel
4. Verify sakit/izin entries appear in Rekap Harian as badge (existing Phase 1 rendering)
5. Support backdated entries (yesterday, last week)

**UAT:**
- Kepala gerai set sakit untuk karyawan → langsung muncul di Rekap Harian hari itu
- Catatan (alasan) bisa diisi opsional
- Bisa di-set untuk tanggal lampau (kemarin, minggu lalu)
- Bisa di-hapus/edit jika salah
- Set sakit/izin dalam < 3 tap

---

### Phase 11: Employee Badge System (Gap Closure)
**Goal:** Employees can be assigned visual badges that display as colored rings on their profile photos.
**Requirements:** REQ-M5-05
**Gap Closure:** Closes unsatisfied requirement from v1.1 audit
**Depends on:** Phase 7 (widget library for consistent UI)

**Plan Progress:** 3/3 complete

Plans:
- [x] 11-01-PLAN.md — EmployeeBadge model, BadgeService singleton, BadgeAvatar widget (solid/gradient/glow ring + emoji chip) (DONE: 11ec0ce, ff3d94a, fa9cb1c)
- [x] 11-02-PLAN.md — BadgeAvatar integration across 6 avatar surfaces, badge label in scan success, badge emoji in overlay pill, Badge column in PDF (DONE: f2a037e, a832a14, abfc0bb, f13d677)
- [x] 11-03-PLAN.md — BadgeManagementScreen CRUD + badge picker bottom sheet + wired into admin employees screen (DONE: 41708c1, 35737e0)

**Tasks:**
1. Badge model + BadgeService: fetch from Supabase `badges` table, cache locally
2. BadgeAvatar widget: solid/gradient/glow ring rendering + emoji chip overlay
3. Admin employee detail: badge picker (list badges → tap assign → save active_badge_id)
4. Display badge in: kiosk scan success screen, employee list, rekap harian tile, overlay pill
5. Admin badge management: CRUD badge definitions (name, color, emoji, style)
6. Badge in PDF report: badge name column in per-employee table

**UAT:**
- Admin bisa assign badge ke karyawan dari layar employee detail
- Karyawan tanpa badge → foto tampil normal (no ring)
- Karyawan dengan badge → foto tampil dengan colored ring sesuai badge definition
- Ring style: solid / gradient / glow sesuai badge definition
- Emoji badge muncul di pojok avatar (small chip overlay)
- Badge label tampil di kiosk scan result
- Admin bisa buat badge custom dari admin panel
- Hapus badge dari karyawan → kembali ke avatar normal

---

## Future Backlog (Not Scheduled)
- Push notification when employee doesn't clock out by X hours
- Employee attendance streak tracking (gamification)
- Cross-outlet attendance comparison chart
- Keterlambatan (late arrival) automatic flagging vs shift start time
- Overtime tracking (> 8h kerja → overtime flag)
- WhatsApp/email daily attendance summary for outlet managers
- QR code backup when NFC fails (camera scan)
- Employee self-service portal (view own attendance history)

---

## Release Schedule Estimate
| Milestone | Phases | Estimated Effort |
|-----------|--------|-----------------|
| v1.1 — Bug Fixes | 1–2 | 2–3 days |
| v1.2 — Live Pill | 3 | 3–4 days |
| v1.3 — PDF Reports | 4–5 | 2–3 days |
| v1.4 — UI Polish | 6–7 | 3–4 days |
| v1.5 — Schedule + Advanced | 8–9 | 4–5 days |
| v1.1 Gap Closure | 10–11 | 2–3 days |
