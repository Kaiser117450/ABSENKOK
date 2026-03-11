# Feature Research: v2.0 Admin Tools + Live Activity

**Domain:** NFC Attendance Kiosk — Admin Lifecycle Management + Persistent Overlay
**Researched:** 2025-07-14
**Confidence:** HIGH (all four features analyzed against existing codebase)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features an admin tool for employee management simply must have. Missing = broken admin workflow.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Soft-archive with preserved history** | HR tools never truly delete employees — audit trail is legally expected. Admin needs to remove ex-employees from active lists without losing attendance records. | MEDIUM | `is_active` field already exists on `employees` table. Main work is UI: separate archived section, archive confirmation dialog, and ensuring archived employees are excluded from NFC scan, schedule assignment, and active lists. |
| **Restore archived employee** | Seasonal workers / rehires are common in restaurant chains. One-way archive is frustrating. | LOW | Trivial: flip `is_active` back to `true`. UI: "Restore" button in the archived list. |
| **Archived employees excluded from schedules** | Archived employee showing in schedule selector is a bug, not a feature. | LOW | Add `.eq('is_active', true)` filter to shift scheduler employee query. |
| **Archived employees excluded from NFC lookup** | Archived employee scanning NFC should not register attendance. | LOW | Filter in `EmployeeCacheService` or Supabase employee-by-NFC query. |
| **CSV import with error reporting** | Batch onboarding is expected when opening new outlets. Without it, admin manually enters 5-10 employees one-by-one — tedious. | MEDIUM | File picker + CSV parsing + validation + row-by-row error report. Flutter has `file_picker` + `csv` package (lightweight). |
| **CSV duplicate detection** | Admin will inevitably upload the same CSV twice or include existing employees. Silent duplicates = data corruption. | LOW | Check `employee_code` or `name + home_outlet_id` combo before insert. Show "already exists" per row. |
| **Persistent overlay showing kiosk status** | Kiosk runs 24/7 unattended. When tablet is on home screen, the admin/staff glancing at it should see "kiosk is alive and running." | LOW (exists) | Already built: `flutter_overlay_window` pill shows outlet name + time when idle, attendance type when event fires. Table-stakes baseline is met. |
| **Kepala Gerai quick setup** | Must be able to promote outlet manager without code deploy. | LOW | SQL script for Supabase Dashboard. No Flutter code needed. |

### Differentiators (Competitive Advantage)

Features that make Enakko's admin tools feel premium vs. basic attendance apps.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Riwayat Karyawan history page** | Dedicated screen showing full attendance history of archived employees. Most attendance apps just "delete" — Enakko preserves the complete record with date range, total days worked, attendance summary. Makes HR audits trivial. | MEDIUM | New screen: query `attendance_logs` for archived `employee_id`, group by date, show summary stats. Reuse existing Rekap Harian patterns. |
| **Smart CSV validation with outlet matching** | CSV includes outlet *name* (not UUID). System auto-resolves `"Enakko Sudirman"` → outlet UUID. Shows friendly errors: "Row 3: outlet 'Enakko Margonda' not found." | MEDIUM | Map outlet names to IDs with fuzzy tolerance (trimmed, case-insensitive). Preview screen before commit. |
| **Live break status on overlay pill** | When any employee at this outlet is on break (istirahat), the overlay pill shows "🍽 Ahmad — Istirahat" with orange accent. Staff can glance at the kiosk tablet and know who's on break without opening the app. | MEDIUM-HIGH | Requires data pipeline: Supabase query → foreground service → `shareData()` → overlay isolate. |
| **Fun facts / rotating messages when idle** | When no one is on break and kiosk is idle, pill rotates through fun facts: "Hari ini 12/14 karyawan hadir 🎉", motivational quotes. Makes the kiosk feel alive instead of a static clock. | LOW-MEDIUM | Array of pre-built messages + dynamic stats cached hourly. Existing 30-second rotation timer already cycles. |
| **Archive confirmation with impact summary** | Dialog shows "Karyawan ini ada di 3 jadwal mendatang yang akan dihapus" before archiving. | LOW-MEDIUM | Query `schedule_entries` count before showing confirm dialog. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Hard delete employees** | "Remove this person completely" | Destroys attendance history. Foreign key violations on `attendance_logs.employee_id`. No audit trail. Illegal in many jurisdictions. | Soft-archive: `is_active = false` + hidden from active lists. Data preserved forever. |
| **CSV with NFC UID column** | "Let me pre-assign NFC cards in the spreadsheet" | NFC UIDs are hex strings read from physical cards. Admins don't know the UID until they physically tap the card. Pre-filling UIDs leads to typos and mismatched cards. | CSV imports name/position/outlet only. NFC UID assigned separately via physical tap (existing `_AssignNfcDialog`). |
| **Supabase Admin API for Kepala Gerai** | "Use the admin API to create users programmatically" | Requires exposing `service_role` key in client-side code (massive security risk) or building an Edge Function. Over-engineered for 4 outlets. | SQL script in Supabase Dashboard SQL Editor. One line, copy-paste, done. Reconsider when >10 outlets. |
| **Real-time overlay via Supabase Realtime in overlay isolate** | "Just subscribe to attendance_logs changes from the overlay" | `overlayMain()` runs in a separate Dart isolate with no Supabase client, no ProviderScope, no shared memory. Initializing Supabase in overlay isolate doubles connections and breaks single-client architecture. | Foreground service (main isolate) polls/subscribes → builds state → pushes via `shareData()`. |
| **Android 16 ProgressStyle (native Live Updates)** | "Use the official API" | Requires API 36+ (Android 16). Current `minSdk` is 24. Zero field tablets run Android 16. | Keep `flutter_overlay_window` (SYSTEM_ALERT_WINDOW) — works on API 24+ and is already deployed at all 4 outlets. Enhance content, not infrastructure. |
| **Complex animated overlay widgets** | "Add charts, lists, scrolling" | Overlay is separate isolate. Complex widgets increase memory, battery drain, ANR risk on low-end tablets. | Keep it simple: 1-2 lines of text, color dot, time. Max info = name + status + time. |
| **Break notification push to admin phone** | Passive awareness | Requires FCM/push infra, out of scope | Overlay pill shows break status passively at the outlet. |
| **Inline CSV error correction** | Fix errors in-place during import | Significantly more complex UI (editable table cells) for rare edge case | Show errors clearly, let admin fix CSV file and re-upload. |

---

## Detailed Feature Analysis

### Feature 1: Soft-Archive Karyawan

**What HR/attendance apps typically do:**

1. **Soft-delete with status flag** (most common) — Employee row stays in database, `is_active = false`. Hidden from active lists, schedules, and NFC scan lookup. Attendance history preserved by foreign key.

2. **Separate "Archived" tab/section** — Admin sees two views: "Active Employees" (default) and "Archived Employees" (accessible via tab or filter chip). This is the pattern used by BambooHR, Homebase, Deputy, and When I Work.

3. **Restore capability** — All major HR tools allow restoring archived employees. Common in restaurant industry where seasonal/part-time workers leave and return.

**Expected UX flow (based on industry patterns):**

```
Admin Employee List
├── Filter chips: [Aktif ✓] [Arsip (2)] [Semua]
├── Employee Card (active)
│   └── PopupMenu → "Arsipkan" (with confirmation dialog)
│       ├── "Apakah Anda yakin ingin mengarsipkan [Name]?"
│       ├── "Karyawan akan dihapus dari daftar aktif dan jadwal."
│       ├── "Riwayat absensi tetap tersimpan."
│       └── [Batal] [Arsipkan]
└── Employee Card (archived) — grayed out, "Arsip" badge
    └── PopupMenu → "Pulihkan" (restore) | "Riwayat Karyawan" (history)
```

**What happens to scheduled shifts on archive:**

| Approach | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| Auto-remove from future schedules | Clean — no ghost entries | Destructive, may lose scheduling intent | ✅ **Use this** — archive means "gone from active operations" |
| Keep in schedules with "archived" badge | Non-destructive | Confusing — appears in scheduler but can't work | ❌ |
| Prompt admin to reassign | Most thorough | Over-engineered for 14 employees | ❌ |

**Recommendation:** On archive, run `DELETE FROM schedule_entries WHERE employee_id = $id AND date >= CURRENT_DATE`. Past schedule entries preserved for audit. Future entries removed.

**Riwayat Karyawan screen — what to show:**

| Section | Content |
|---------|---------|
| Header | Employee name, position, outlet, badge, archive date |
| Summary card | Total hari kerja, total hadir, total sakit, total izin, tenure (first attendance → last attendance) |
| Attendance timeline | Scrollable list of attendance logs, grouped by date, reusing existing Rekap Harian UI patterns |
| Export | PDF/CSV of this employee's full history (reuse PdfReportService) |

**Codebase impact:**

| File | Change |
|------|--------|
| `employee.dart` | Add `archivedAt` field (nullable DateTime). Already has `isActive`. |
| `admin_employees_screen.dart` | Add filter chips (Aktif/Arsip). Add "Arsipkan"/"Pulihkan" to PopupMenu. Gray styling for archived cards. Currently fetches ALL employees without `is_active` filter — need to add. |
| Employee query | Active tab = `.eq('is_active', true)`, archive tab = `.eq('is_active', false)`. |
| NFC scan lookup | `EmployeeCacheService` must only return `is_active = true` employees. **Verify this.** |
| Schedule assignment | Scheduler employee list must filter `is_active = true` only. |
| New screen | `riwayat_karyawan_screen.dart` — attendance history for a specific employee |

**Complexity: MEDIUM** — Data layer mostly exists (`is_active` flag). Work is primarily UI: filter chips, archive confirmation dialog, history screen.

---

### Feature 2: Batch CSV Import

**Typical upload flow (BambooHR, Homebase, Gusto pattern):**

```
Step 1: Upload
├── "Import Karyawan" button on employee list (next to existing "Tambah")
├── File picker → select .csv file
└── Parse CSV immediately (client-side)

Step 2: Preview + Validate
├── Table showing parsed rows with status column
│   ├── ✅ Row 1: Ahmad — Kasir — Enakko Sudirman → ready
│   ├── ✅ Row 2: Budi — Chef — Enakko Margonda → ready
│   ├── ⚠️ Row 3: Citra — Kasir — Enakko Bandung → outlet not found
│   ├── ⚠️ Row 4: Ahmad — Kasir — Enakko Sudirman → duplicate (already exists)
│   └── ❌ Row 5: [empty] — [empty] — [empty] → missing required fields
├── Error summary: "3 valid, 1 warning, 1 error"
└── Admin can skip problem rows (not edit inline)

Step 3: Confirm Import
├── "Import 3 Karyawan" button (only valid rows)
├── Progress indicator during batch insert
└── Result: "3 imported, 1 skipped (duplicate), 1 skipped (error)"
```

**CSV format — keep it minimal:**

```csv
nama,jabatan,gerai,kode_karyawan
Ahmad Fauzi,Kasir,Enakko Sudirman,EMP-001
Budi Santoso,Chef,Enakko Margonda,EMP-002
Citra Dewi,Waiter,,
```

| Column | Required | Maps to | Notes |
|--------|----------|---------|-------|
| `nama` | ✅ Yes | `employees.name` | Non-empty string |
| `jabatan` | No | `employees.position` | Nullable |
| `gerai` | ✅ Yes | `employees.home_outlet_id` | Resolved by name match (case-insensitive, trimmed) |
| `kode_karyawan` | No | `employees.employee_code` | Nullable, used for duplicate detection |

**NFC UID is NOT in CSV** — assigned physically after import via existing `_AssignNfcDialog`.

**Validation rules:**

| Rule | Type | Behavior |
|------|------|----------|
| Name empty | ERROR | Row cannot be imported |
| Outlet name not found | ERROR | Row cannot be imported |
| Duplicate `employee_code` in DB | WARNING | Skip with message "sudah terdaftar" |
| Duplicate `name + outlet` in DB | WARNING | Skip with message "mungkin sudah terdaftar" |
| Duplicate within CSV itself | WARNING | Skip second occurrence |
| Extra/unknown columns | IGNORE | Silently skip |
| BOM / encoding issues | HANDLE | Strip UTF-8 BOM, handle common encodings |

**Implementation approach:**

Use `csv` Dart package (handles quoting, escaping, BOM) + `file_picker` for native file selection. No server-side processing needed — everything client-side for 14-200 employees.

**Dependencies needed:**
- `file_picker: ^8.x` — native file selector
- `csv: ^6.x` — robust CSV parsing

**Codebase impact:**

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `file_picker` and `csv` |
| `admin_employees_screen.dart` | Add "Import CSV" button next to "Tambah" |
| New: `csv_import_screen.dart` | Full-screen sheet with preview table, validation, import button |
| New: `csv_import_service.dart` | CSV parsing, validation, outlet resolution, batch insert |

**Complexity: MEDIUM** — CSV parsing is straightforward. Real work is preview/validation UI and edge case handling.

---

### Feature 3: Persistent Live Activity Pill Enhancement

**Current state (already built):**

The overlay pill is fully functional with two modes:
- **Idle mode:** Shows outlet name + current time, rotates every 30 seconds via `_rotateNotification()`
- **Event mode:** Shows attendance type + accent color + badge emoji after NFC scan, auto-expires after 8 seconds

The pill uses `flutter_overlay_window` (SYSTEM_ALERT_WINDOW permission), renders via a separate Dart isolate (`overlayMain()`), and receives data via `FlutterOverlayWindow.shareData()`.

**What needs enhancement:**

| Current | Target |
|---------|--------|
| Idle shows: outlet name + time (alternating) | Idle shows: fun facts, attendance stats, motivational messages (rotating) |
| No break awareness | When employee on break: show "🍽 Ahmad — Istirahat" with orange accent |
| Event for 8 seconds after scan | Same (keep this — it works well) |
| Two states: idle / event | Three states: idle / breakActive / event |

**How apps like Grab, Uber, GoFood implement persistent floating UI on Android:**

1. **Grab:** Custom notification with RemoteViews (Kotlin). NOT a floating overlay. Appears in notification drawer + lock screen. Updates in-place using same notification ID. This is exactly what `KioskNotificationHelper.kt` already does.

2. **Uber / GoFood:** Same notification-based approach. Ongoing notification that updates status text.

3. **Food delivery countdown timers:** Some use `SYSTEM_ALERT_WINDOW` floating widgets — same approach as Enakko.

**Key insight: Enakko already has the most advanced approach** — it uses BOTH a custom Kotlin notification AND a Flutter floating overlay. The enhancement is about **content richness**, not infrastructure changes.

**Break status — data flow architecture:**

```
Supabase Query (attendance_logs WHERE type='break' AND scan_outlet_id=X)
    │
    ▼
Main Isolate — foreground service timer (_rotateNotification, every 30s)
    │ Checks cached break status (refreshed every 60s from Supabase)
    │ Builds OverlayPillState with mode=breakActive or idle
    │
    ▼
FlutterOverlayWindow.shareData(state.toWirePayload())
    │
    ▼
Overlay Isolate (overlayMain) receives via overlayListener
    │ Renders break pill UI or fun fact
    ▼
```

**Break detection approach:**

| Approach | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| Supabase Realtime in main isolate | Real-time, instant updates | Main app might be backgrounded; foreground service is Kotlin | ⚠️ Works if Dart isolate active |
| Periodic poll from foreground service timer | Works reliably even when Dart sleeps | 30-60s delay, extra Supabase calls | ✅ **Best for reliability** |

**Recommended:** Extend `_rotateNotification()` timer (already fires every 30s) to:
1. Every 60 seconds: query `attendance_logs` for unresolved breaks at this outlet (type='break' with no subsequent 'kembali')
2. Cache result in memory
3. Every 30 seconds: if break active → push break state to overlay; else → push fun fact/idle

**Fun facts — content strategy:**

| Category | Example | Update Frequency |
|----------|---------|------------------|
| Attendance stats | "Hari ini 12/14 karyawan hadir 🎉" | Hourly from Supabase |
| Streak | "3 hari berturut-turut full hadir! 🔥" | Hourly |
| Time-based greeting | "Selamat pagi! ☀️ Semangat bekerja!" | Based on hour |
| Motivational | "Kerja keras, hasil manis! 💪" | Static pool, rotate |
| Outlet-specific | "Enakko Sudirman — 0 keterlambatan minggu ini" | Hourly |

Cache stats in SharedPreferences, refresh via Supabase query once per hour.

**OverlayPillState model changes needed:**

```dart
enum OverlayPillMode { idle, event, breakActive }  // Add breakActive

class OverlayPillState {
  // Existing fields...
  final String funFact;      // NEW: "12/14 karyawan hadir hari ini"
  final String breakName;    // NEW: "Ahmad" (who's on break)
}
```

**Info density for the pill:**

Existing pill dimensions:
- **Expanded:** ~380px wide, 56px tall — fits: icon + outlet name + status label + time chip
- **Collapsed:** ~220px wide, 38px tall — fits: dot + status text + time

For break status: `🟠 Ahmad · Istirahat · 12:34`
For fun facts: `🟢 🎉 12/14 hadir hari ini`

**Keep it to ONE line of meaningful text + time.** No paragraphs, no lists.

**Complexity: MEDIUM-HIGH** — Infrastructure exists. Work is:
1. Break detection logic (Supabase query in foreground service)
2. Fun fact content system (static + dynamic)
3. New `breakActive` mode in OverlayPillState + overlay rendering
4. Testing overlay ↔ foreground service data flow reliability

---

### Feature 4: Quick Kepala Gerai SQL Script

**How the auth system currently works (verified from codebase):**

```
Supabase Auth (auth.users table)
├── raw_user_meta_data OR raw_app_meta_data:
│   { "app_role": "admin" }  
│   OR  
│   { "app_role": "kepala_gerai", "managed_outlet_id": "uuid-here" }
│
└── Login Screen (admin_login_screen.dart) reads both:
    role = user.userMetadata?['app_role'] ?? user.appMetadata['app_role']
    outletId = user.appMetadata['managed_outlet_id'] ?? user.userMetadata?['managed_outlet_id']
```

**Simplest pattern — UPDATE raw_app_meta_data:**

```sql
-- Promote user to Kepala Gerai for specific outlet
UPDATE auth.users
SET raw_app_meta_data = jsonb_set(
  jsonb_set(
    COALESCE(raw_app_meta_data, '{}'::jsonb),
    '{app_role}', '"kepala_gerai"'
  ),
  '{managed_outlet_id}', '"<OUTLET_UUID_HERE>"'
)
WHERE email = 'kepala@example.com';
```

**Why NOT alternatives:**

| Approach | Pros | Cons |
|----------|------|------|
| SQL UPDATE (recommended) | Instant, no code deploy, works today | Must use Supabase Dashboard (admin access required) |
| `supabase.auth.admin.updateUserById()` | Programmatic | Requires `service_role` key — MUST NEVER be in client code. Needs Edge Function. Over-engineered. |
| `INSERT INTO auth.users` | Creates new users | Passwords need hashing, bypasses email confirmation. Fragile. Don't do this. |

**Pre-requisite:** User must already exist in `auth.users` (signed up via Supabase Auth or Dashboard → Authentication → Add User). Script promotes existing account.

**Deliverable:** A `.sql` file in the repo with template script + step-by-step comments.

**Complexity: LOW** — Documentation + SQL file. No Flutter code changes.

---

## Feature Dependencies

```
[Soft-archive Karyawan]
    ├──requires──> [is_active flag on employees table] ✅ EXISTS
    ├──requires──> [Archive confirmation dialog] 🆕
    ├──requires──> [Employee list filter chips] 🆕
    ├──requires──> [Archive filter in schedule picker] 🆕
    ├──requires──> [Archive filter in NFC lookup] 🆕 (verify)
    └──enables──> [Riwayat Karyawan History Screen] 🆕
                      └──reuses──> [Rekap Harian UI patterns] ✅ EXISTS
                      └──reuses──> [PdfReportService for export] ✅ EXISTS

[Batch CSV Import]
    ├──requires──> [file_picker package] 🆕
    ├──requires──> [csv package] 🆕
    ├──requires──> [Outlet name → ID resolution] 🆕
    └──optional──> [Soft-archive awareness] (imported employees = is_active: true)

[Live Activity Enhancement]
    ├──requires──> [overlay_task.dart] ✅ EXISTS
    ├──requires──> [KioskBackgroundService._rotateNotification()] ✅ EXISTS
    ├──requires──> [OverlayPillState model extension] 🆕
    ├──requires──> [Break detection query] 🆕
    └──requires──> [Fun fact content system] 🆕

[Quick Kepala Gerai Setup]
    ├──requires──> [Supabase Dashboard access] ✅ EXISTS
    └──independent of all other features
```

### Dependency Notes

- **All four features are independent** — no cross-dependencies. Can be built in any order or in parallel.
- **Soft-archive should precede CSV import** (logical ordering: manage existing employees before batch-adding new ones, but no technical dependency).
- **Live Activity Enhancement is purely kiosk-side** — no admin UI dependency.
- **Kepala Gerai is documentation only** — can ship at any point.

---

## v2.0 Milestone Definition

### Launch With (v2.0 Core) — P1

- [x] **Soft-archive karyawan** — Essential for employee lifecycle. `is_active` field exists, needs UI.
- [x] **Riwayat Karyawan screen** — Proves archive isn't "delete." Full attendance history.
- [x] **Batch CSV import with preview** — Unlocks multi-outlet onboarding.
- [x] **Quick Kepala Gerai SQL script** — Unblocks new outlet setup.

### Add After Core (v2.0 Polish) — P2

- [ ] **Live break status on pill** — Requires careful testing of foreground service ↔ overlay data flow. Ship admin tools first, then enhance overlay.
- [ ] **Fun fact rotating messages** — Nice polish after break status works reliably.

### Future Consideration (v3+)

- [ ] **Android 16 ProgressStyle notifications** — When tablets run API 36+
- [ ] **CSV import with photo upload** — Complex (storage, resizing, CDN)
- [ ] **In-app Kepala Gerai creation** — Edge Function + admin UI, not worth it for 4 outlets
- [ ] **Inline CSV error correction** — Editable preview cells, significant UI complexity

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Risk | Priority |
|---------|------------|---------------------|------|----------|
| Soft-archive + Riwayat | HIGH | MEDIUM | LOW | **P1** |
| Batch CSV import | HIGH | MEDIUM | LOW | **P1** |
| Kepala Gerai SQL script | MEDIUM | LOW | VERY LOW | **P1** |
| Live break status on pill | MEDIUM | MEDIUM-HIGH | MEDIUM | **P2** |
| Fun fact messages | LOW | LOW-MEDIUM | LOW | **P2** |

---

## Concrete UX Patterns

### Soft-Archive: UI Mockups

**Archive Confirmation Dialog:**
```
┌─────────────────────────────────────┐
│        Arsipkan Karyawan?           │
│                                     │
│  Ahmad Fauzi akan diarsipkan:       │
│                                     │
│  • Dihapus dari daftar aktif        │
│  • Dihapus dari jadwal mendatang    │
│  • Tidak bisa absen NFC             │
│  • Riwayat absensi tetap tersimpan  │
│                                     │
│         [Batal]  [Arsipkan]         │
└─────────────────────────────────────┘
```

**Employee List with Filter Chips:**
```
┌─────────────────────────────────────┐
│ Total: 16  Aktif: 14  Tanpa Kartu: 2│  [+ Tambah] [📄 Import]
│                                     │
│  [Aktif ✓]  [Arsip (2)]  [Semua]   │
│                                     │
│  🔍 Cari nama atau jabatan...       │
│                                     │
│  ┌─ Ahmad Fauzi ────── Kasir ──┐   │
│  │  📍 Enakko Sudirman   [NFC][⋮]│  │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

**Archived Employee Card (grayed out):**
```
┌─────────────────────────────────────┐
│  🔘 Citra Dewi ─── [ARSIP] ───────│
│     Kasir · Enakko Sudirman        │
│     Diarsipkan: 15 Jan 2025        │
│                     [Pulihkan] [⋮] │
└─────────────────────────────────────┘
   PopupMenu: Pulihkan | Riwayat Karyawan
```

### CSV Import: UI Mockups

**Import Preview Screen:**
```
┌─────────────────────────────────────┐
│  ← Import Karyawan                  │
│                                     │
│  📄 karyawan_baru.csv (5 baris)     │
│                                     │
│  ✅ 3 siap import                   │
│  ⚠️ 1 duplikat (akan dilewati)      │
│  ❌ 1 error                         │
│                                     │
│  ┌───────────────────────────────┐  │
│  │ ✅ Ahmad · Kasir · Sudirman   │  │
│  │ ✅ Budi · Chef · Margonda     │  │
│  │ ⚠️ Citra · Kasir · Sudirman   │  │
│  │    ↳ Sudah terdaftar          │  │
│  │ ❌ [kosong] · [kosong]        │  │
│  │    ↳ Nama wajib diisi         │  │
│  │ ✅ Diana · Waiter · Sudirman  │  │
│  └───────────────────────────────┘  │
│                                     │
│      [Import 3 Karyawan]           │
└─────────────────────────────────────┘
```

### Live Activity Pill: Content States

**Idle — fun fact rotation (NEW):**
```
┌──────────────────────────────────┐
│ [A] Enakko Sudirman        14:30 │  ← every 30s
│     🟢 Kiosk aktif               │
└──────────────────────────────────┘
         ↓ rotate ↓
┌──────────────────────────────────┐
│ [A] 🎉 12/14 hadir hari ini     │  ← fun fact
│     🟢 Kiosk aktif               │
└──────────────────────────────────┘
```

**Break active (NEW):**
```
┌──────────────────────────────────┐
│ [A] Enakko Sudirman        14:30 │
│     🟠 Ahmad · Istirahat         │
└──────────────────────────────────┘
```

**Event after NFC scan (UNCHANGED):**
```
┌──────────────────────────────────┐
│ [A] Enakko Sudirman    🏅 14:30  │
│     🟢 Masuk · Event aktif       │
└──────────────────────────────────┘
```

---

## Competitor Feature Analysis

| Feature | BambooHR | Deputy / Homebase | When I Work | **Enakko v2.0 Approach** |
|---------|----------|-------------------|-------------|--------------------------|
| Employee archive | Soft-delete, "Inactive" tab | Soft-delete, filter by status | Archive with restore | Soft-archive with filter chips + Riwayat Karyawan history screen |
| Batch import | Full CSV wizard with column mapping | CSV import with template download | CSV with preview | CSV with preview + outlet name auto-resolution. No NFC UID (physical assignment). |
| Live status display | Dashboard-only (web) | Mobile app notifications | Push notifications | **Unique**: Android floating overlay pill visible outside app. No competitor does this for kiosk attendance. |
| Role management | Full RBAC admin panel | Admin panel with role assignment | Web-based roles | SQL script (pragmatic for 4 outlets, zero complexity) |

---

## Sources

- **Codebase analysis (HIGH confidence):** `employee.dart` (model with `isActive`), `admin_employees_screen.dart` (current CRUD + PopupMenu), `overlay_task.dart` (overlay rendering + OverlayPillState), `kiosk_background_service.dart` (foreground service + overlay data pipeline), `overlay_pill_state.dart` (state model), `admin_login_screen.dart` (auth role reading), `app.dart` (auth state listener), `kiosk_scan_screen.dart` (event overlay push)
- **Existing reference doc (HIGH confidence):** `liveaction.md` — comprehensive Grab-style Live Activity implementation guide in repo
- **HR tool patterns (MEDIUM confidence):** BambooHR soft-delete, Deputy employee archiving, Homebase CSV import — industry-standard patterns from training data
- **Supabase Auth metadata (HIGH confidence):** Verified from codebase — reads `app_role` and `managed_outlet_id` from both `userMetadata` and `appMetadata`

---
*Feature research for: Absensi Enakko v2.0 Admin Tools + Live Activity*
*Researched: 2025-07-14*
