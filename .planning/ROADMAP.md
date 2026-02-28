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
- [ ] 02-01-PLAN.md — Fix 24h shift cycle: replace isSameDay with 24h window query in kiosk_scan_screen.dart _loadLastAttendance
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
**Goal:** After each NFC scan, a floating pill appears over all apps showing outlet + employee + status.
This is the signature UX feature — "Dynamic Island" feel for kiosk attendance.

### Phase 3: Overlay Pill Implementation
**Goal:** Floating attendance pill overlay shows correctly on scan success with premium animation.

**Tasks:**
1. Design overlay widget in `overlay_task.dart`:
   - Dark semi-transparent pill container (rounded, ~56dp tall)
   - Left accent bar (colored by attendance type)
   - Brand micro-logo (24dp) + outlet name
   - Employee name (bold) + status label + time
2. Add slide-down + fade entrance animation (spring physics, 300ms)
3. Add auto-dismiss timer (3s) with fade-out
4. Wire MethodChannel events from `kiosk_idle_screen.dart` → overlay:
   - `show_overlay` with payload: {outletName, employeeName, type, time}
   - `hide_overlay` for manual dismiss
5. Request SYSTEM_ALERT_WINDOW permission on first kiosk setup if not already granted
6. Tap-to-dismiss: overlay window click → hide immediately
7. Test on real kiosk device (emulator behavior differs for overlays)

**UAT:**
- Setelah NFC scan sukses → pil muncul dalam 300ms
- Pil menampilkan nama gerai, nama karyawan, jenis absen, jam yang benar
- Pil auto-hilang setelah 3 detik
- Animasi masuk halus (slide down + fade in)
- Pil tidak memblokir interaksi kiosk
- Warna aksen sesuai jenis absen (hijau=masuk, abu=pulang, amber=istirahat)

---

## Milestone 3 — PDF Reports + Export (v1.3)
**Goal:** Professional PDF attendance report with insights. Export both CSV (per-scan + summary) and PDF.

### Phase 4: PDF Export Engine
**Goal:** Generate branded PDF report with summary insights and per-employee table.

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
