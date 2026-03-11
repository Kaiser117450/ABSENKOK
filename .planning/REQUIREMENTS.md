# Requirements: Absensi Enakko v2.0

**Defined:** 2026-03-11
**Core Value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.

## v2.0 Requirements

Requirements for v2.0 Admin Tools + Live Activity. Each maps to roadmap phases.

### Employee Archive

- [x] **ARCH-01**: Admin can archive (soft-delete) a karyawan from the active employee list
- [x] **ARCH-02**: Archived karyawan is excluded from NFC scan lookup (cannot clock in)
- [x] **ARCH-03**: Archived karyawan is excluded from schedule assignment and shift selector
- [x] **ARCH-04**: Archive confirmation dialog shows impact summary (jumlah jadwal mendatang yang terdampak)
- [x] **ARCH-05**: Admin can restore (un-archive) a previously archived karyawan
- [x] **ARCH-06**: Admin can view Riwayat Karyawan page showing archived employees with full attendance history

### Batch CSV Import

- [x] **CSV-01**: Admin can upload a CSV file to batch-add multiple karyawan at once
- [x] **CSV-02**: CSV format supports columns: nama, jabatan, gerai (nama outlet), photo_url (link)
- [x] **CSV-03**: System auto-resolves outlet name to outlet UUID (case-insensitive match)
- [x] **CSV-04**: System shows preview screen with parsed rows before committing to database
- [x] **CSV-05**: System detects and reports duplicate karyawan (by name + outlet combination)
- [x] **CSV-06**: System shows per-row validation errors (missing fields, unknown outlet, duplicates)

### Kepala Gerai Setup

- [ ] **ADMIN-01**: SQL script template available for Supabase SQL editor to promote any Gmail to Kepala Gerai role for a specific outlet

### Live Activity Pill

- [ ] **LIVE-01**: Persistent Dynamic Island-style overlay pill visible outside the app when kiosk is running
- [x] **LIVE-02**: Overlay pill shows real-time break status (nama karyawan yang sedang istirahat)
- [x] **LIVE-03**: Overlay pill shows fun facts / rotating idle messages when no one is on break (e.g. "Hari ini 12/14 hadir 🎉")
- [ ] **LIVE-04**: Overlay pill updates automatically without user interaction

## Future Requirements

Deferred from v2.0. Tracked but not in current roadmap.

### Schedule & Time

- **SCHED-01**: Schedule UI full grid redesign (week-view grid, tap-to-assign cells)
- **TIME-01**: Time-off request approval workflow
- **TIME-02**: Keterlambatan (late arrival) automatic flagging vs shift start time
- **TIME-03**: Overtime tracking (> 8h kerja → overtime flag)

### Notifications

- **NOTIF-01**: Push notification for missing clock-out
- **NOTIF-02**: Attendance rate card on admin dashboard

## Out of Scope

| Feature | Reason |
|---------|--------|
| Hard delete karyawan | Destroys attendance history, FK violations on attendance_logs, no audit trail |
| CSV with NFC UID column | NFC UIDs read from physical cards — admin doesn't know UID until tap. Pre-filling leads to typos |
| Supabase Admin API for Kepala Gerai | Requires service_role key client-side (security risk). SQL script sufficient for 4 outlets |
| Supabase Realtime in overlay isolate | Overlay runs in separate Dart isolate — cannot access main Supabase client. Data flows via shareData() |
| Android 16 ProgressStyle (native Live Updates) | Requires API 36+, current minSdk=24, no field tablets run Android 16 |
| Complex animated overlay widgets | Memory/battery/ANR risk on kiosk tablets. Keep pill simple: 1-2 lines text |
| Break notification push to admin phone | Requires FCM infrastructure, out of scope for v2.0 |
| Inline CSV error correction | Complex editable table UI for rare edge case — admin can fix CSV and re-upload |
| iOS app | Android-only kiosk, no iOS target |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ARCH-01 | Phase 13 | In Progress |
| ARCH-02 | Phase 13 | Complete |
| ARCH-03 | Phase 13 | Complete |
| ARCH-04 | Phase 13 | Complete |
| ARCH-05 | Phase 13 | In Progress |
| ARCH-06 | Phase 13 | Complete |
| CSV-01 | Phase 14 | Complete |
| CSV-02 | Phase 14 | Complete |
| CSV-03 | Phase 14 | Complete |
| CSV-04 | Phase 14 | Complete |
| CSV-05 | Phase 14 | Complete |
| CSV-06 | Phase 14 | Complete |
| ADMIN-01 | Phase 15 | Pending |
| LIVE-01 | Phase 16 | Pending |
| LIVE-02 | Phase 16 | Complete |
| LIVE-03 | Phase 16 | Complete |
| LIVE-04 | Phase 16 | Pending |

**Coverage:**
- v2.0 requirements: 17 total
- Mapped to phases: 17 ✓
- Unmapped: 0

---
*Requirements defined: 2026-03-11*
*Last updated: 2026-03-11 after roadmap creation*
