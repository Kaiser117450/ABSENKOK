# Stack Research — v2.0 Admin Tools + Live Activity

**Domain:** NFC attendance kiosk (Flutter/Android) — subsequent milestone additions
**Researched:** 2025-07-14
**Confidence:** HIGH

## Executive Summary

The v2.0 milestone requires remarkably few new dependencies. Of the 4 features, only **CSV import** needs new packages (`csv` + `file_picker`). The other 3 features — persistent live activity pill, soft-archive, and Kepala Gerai setup — build entirely on the existing stack. This is the correct outcome: the v1.1 architecture was well-designed with extension points in the right places.

**Key insight:** The existing `flutter_overlay_window` + `KioskNotificationHelper.kt` (Kotlin RemoteViews) + `flutter_foreground_task` trio already provides persistent overlay + notification infrastructure. The v2.0 "persistent live activity pill" is an **extension of existing behavior**, not a new system. The overlay already runs persistently; what's new is the *content* it displays (break status, fun facts).

---

## Recommended Stack Additions

### New Dependencies (ADD to pubspec.yaml)

| Package | Version | Purpose | Why This One |
|---------|---------|---------|--------------|
| `csv` | ^6.0.0 | CSV parsing for batch employee import | Standard Dart CSV parser — handles quoted fields, BOM detection, configurable delimiters. Used by 1000+ packages. The existing manual `_escapeCsv()` in reports is fine for *export* but insufficient for robust *import* (edge cases: Indonesian names with commas, UTF-8 BOM from Excel). |
| `file_picker` | ^8.1.0 | File selection dialog for CSV file | De facto Flutter file picker. Supports Android 7+ (minSdk 24 ✓). No iOS needed. Returns platform file with bytes + path. |

### Existing Dependencies (NO CHANGES — already sufficient)

| Existing Package | Version | v2.0 Usage | Why No Change |
|------------------|---------|------------|---------------|
| `flutter_overlay_window` | ^0.5.0 | Persistent break status pill | Already shows overlay with `SYSTEM_ALERT_WINDOW`. Already updates via `shareData()`. Already has idle/event modes. Just extend `OverlayPillState` model. |
| `flutter_foreground_task` | ^8.14.0 | Background service for pill lifecycle | Already keeps kiosk alive. 10s event loop (`_rotateNotification`) already updates both notification and overlay. Add break status + fun fact rotation to this loop. |
| `flutter_local_notifications` | ^18.0.0 | Fallback notification | No change — existing fallback pattern preserved. |
| `supabase_flutter` | ^2.8.4 | Realtime break status subscription | Already has realtime subscriptions for `attendance_logs` and `employees`. Add new channel for break status queries. |
| `shared_preferences` | ^2.3.3 | Fun facts cache, session state | Already used for kiosk session. Can store fun facts list locally. |
| `intl` | ^0.19.0 | Date formatting for archive timestamps | Already used for `id_ID` locale formatting. |

### Native Code Additions (Kotlin — NOT new packages)

| Component | Location | What Changes | Why |
|-----------|----------|--------------|-----|
| `KioskNotificationHelper.kt` | `android/.../kotlin/` | Add break status fields to RemoteViews `show()` | Notification needs to display "🍽️ Ahmad sedang istirahat" — extend existing `title`/`body` params, no structural change. |
| `notification_kiosk.xml` | `res/layout/` | Optional: add break status row | Compact view can show break employee name. Current layout already has title + body + time — body text is sufficient. |
| `notification_kiosk_expanded.xml` | `res/layout/` | Optional: add break count or break employee list | Expanded view has room for additional status info below the divider. |

### Database Schema Additions (Supabase SQL)

| Change | Table | What | Why |
|--------|-------|------|-----|
| ADD COLUMN | `employees` | `archived_at TIMESTAMPTZ DEFAULT NULL` | Soft-archive audit trail. `is_active = false` already exists but doesn't record *when*. `archived_at` is the timestamp. All existing `is_active = true` filters already exclude archived employees — zero query changes needed. |
| ADD COLUMN | `employees` | `archived_by TEXT DEFAULT NULL` | Records who archived (admin user ID). Useful for audit log. |
| NO CHANGE | `attendance_logs` | — | Foreign key to `employees.id` stays intact. Archived employee logs remain visible in reports (filter by employee_id, not is_active). |
| NO CHANGE | `schedule_entries` | — | Existing entries for archived employees remain. New schedules already filter `is_active = true` (verified: `shift_scheduler_screen.dart` line 103). |

---

## Feature-by-Feature Stack Analysis

### Feature 1: Persistent Live Activity Pill

**Verdict: NO new packages. Extend existing overlay + notification system.**

#### What Already Works (verified in codebase)
- `flutter_overlay_window ^0.5.0` creates system overlay with `SYSTEM_ALERT_WINDOW` permission
- `KioskOverlayUI` (`overlay_task.dart`) renders Dynamic Island pill with idle/event modes
- `OverlayPillState` model carries mode, outlet, time, attendanceType, accentHex, badgeEmoji
- `KioskBackgroundService._rotateNotification()` updates notification + overlay every 5 seconds
- `KioskNotificationHelper.kt` shows Grab-style RemoteViews notification with compact/expanded layouts
- `FlutterOverlayWindow.shareData()` pushes state updates to overlay isolate
- Overlay persistence: `ensureOverlayVisible()` has OEM matchParent fallback (line 380)
- Notification persistence: `setOngoing(true)` makes it non-dismissible

#### What Needs to Change (code, not packages)

1. **Extend `OverlayPillState` model** — add fields:
   - `breakEmployeeName` (String) — who's on break right now
   - `breakCount` (int) — how many on break
   - `funFact` (String) — idle-mode fun fact text
   - `contentMode` enum: `kiosk_idle | break_status | fun_fact`

2. **Supabase Realtime for break status** — new subscription:
   ```dart
   // Query current break employees (type='break' with no matching 'kembali')
   // Subscribe to attendance_logs INSERT for break/kembali events
   ```
   Uses existing `supabase_flutter` realtime — no new package.

3. **Fun facts data source** — hardcoded list or fetched from Supabase:
   - Simplest: `List<String>` constant in Dart code
   - Better: small `fun_facts` table in Supabase (easy to update without app release)
   - `_rotateNotification()` cycles through fun facts during idle periods

4. **Overlay UI extension** — `KioskOverlayUI._buildExpanded()` and `_buildCollapsed()`:
   - When someone is on break: show "🍽️ Ahmad istirahat" with amber accent
   - When idle: cycle fun facts instead of just "Kiosk aktif"
   - Existing `AnimatedSwitcher` handles transitions already

#### Integration Points
```
Supabase Realtime (attendance_logs INSERT)
    ↓ break/kembali event
BreakStatusService (new Dart service)
    ↓ current break employees list
KioskBackgroundService._rotateNotification()
    ↓ update payload
    ├── FlutterOverlayWindow.shareData() → KioskOverlayUI
    └── KioskNotificationHelper.show() → Android notification
```

#### Approaches Evaluated and Rejected

| Approach | Why Rejected |
|----------|--------------|
| **Android Bubble API** (API 30+) | Bubbles are for messaging/chat apps. Google Play policy restricts bubbles to conversation-type notifications. Attendance kiosk is not a conversation. Also, minSdk 24 would need fallback. |
| **Android 16 ProgressStyle** (API 36+) | Requires API 36 minimum. Kiosk tablets run API 24-35. Not available yet. Future-proof option for 2027+. |
| **`live_activities` Flutter package** | Designed for iOS ActivityKit + basic Android notification. The project is Android-only, already has a superior custom RemoteViews notification. Adding this package would duplicate existing Kotlin infrastructure. |
| **New foreground service for pill** | Existing `flutter_foreground_task` service already runs. Adding another service = battery drain + Android process limits. Extend existing service instead. |
| **Replace overlay with notification-only** | Overlay provides always-visible pill on top of other apps. Notification can be hidden in shade. Keep both (overlay = primary, notification = backup per existing pattern). |

---

### Feature 2: Batch CSV Import

**Verdict: 2 new packages (`csv` + `file_picker`)**

#### Why `csv` ^6.0.0
- The existing `_escapeCsv()` in `admin_reports_screen.dart` is a 4-line export helper. It handles commas and quotes for output.
- **Import is harder than export**: need to handle BOM (Excel on Windows adds BOM to UTF-8 CSV), detect delimiters (semicolons in European locales), handle multi-line quoted fields, handle encoding issues from Indonesian names with special characters.
- The `csv` package provides `CsvToListConverter` with configurable `fieldDelimiter`, `textDelimiter`, `textEndDelimiter`, and `eol` settings.
- Alternative considered: `fast_csv` (faster but less configurable, doesn't handle BOM). For a 200-employee file, speed is irrelevant. Correctness matters.

#### Why `file_picker` ^8.1.0
- De facto Flutter file picker with 5000+ likes on pub.dev
- Supports `FileType.custom` with `allowedExtensions: ['csv']`
- Returns `PlatformFile` with `bytes` (in-memory) or `path` (file system)
- Android: storage access works on API 24+ via SAF (Storage Access Framework)
- Alternative considered: `open_file` (lighter but less maintained), manual `Intent` via MethodChannel (unnecessary complexity for a file picker)

#### Import Flow Architecture
```
Admin taps "Import CSV"
    ↓
file_picker → PlatformFile (bytes or path)
    ↓
csv package → List<List<dynamic>>
    ↓
Validation (required fields: nama, jabatan, gerai)
    ↓
Map to Employee insert payloads (lookup outlet by name → id)
    ↓
Supabase batch INSERT (existing supabase_flutter .insert(List<Map>))
    ↓
Show results (success count, error rows with reasons)
```

#### CSV Format (expected)
```csv
nama,jabatan,gerai,photo_url
Ahmad Fauzi,Kasir,Gerai Rungkut,https://...
Budi Santoso,Cook,Gerai Darmo,
```
- `nama` — required
- `jabatan` — required (maps to `position`)
- `gerai` — required (maps to outlet name → lookup `outlets.id` for `home_outlet_id`)
- `photo_url` — optional
- `nfc_uid` — NOT in CSV (set manually per kiosk later, as per requirement)
- `employee_code` — auto-generated or omitted

---

### Feature 3: Soft-Archive Karyawan

**Verdict: NO new packages. Database schema change + Dart code only.**

#### Why This Is Straightforward
The codebase already has the soft-delete mechanism:
- `employees.is_active` boolean exists (verified in Employee model + DB schema)
- `admin_employees_screen.dart` line 92: `.eq('is_active', true)` — active list already filtered
- `shift_scheduler_screen.dart` line 103: `.eq('is_active', true)` — schedules already filtered
- `employee_cache_service.dart` caches by NFC UID — cache auto-expires in 5 min (archived employee naturally drops out)
- Reports query by `employee_id`, not by `is_active` — archived employee attendance remains visible

#### What's Needed (code only)
1. **SQL migration**: `ALTER TABLE employees ADD COLUMN archived_at TIMESTAMPTZ DEFAULT NULL`
2. **SQL migration**: `ALTER TABLE employees ADD COLUMN archived_by TEXT DEFAULT NULL`
3. **Archive action**: `UPDATE employees SET is_active = false, archived_at = NOW(), archived_by = :userId WHERE id = :empId`
4. **Unarchive action**: `UPDATE employees SET is_active = true, archived_at = NULL, archived_by = NULL WHERE id = :empId`
5. **Riwayat Karyawan screen**: Query `employees WHERE is_active = false ORDER BY archived_at DESC`
6. **Attendance logs**: No change needed — existing reports already query by `employee_id` without `is_active` filter

#### PostgreSQL Pattern: Soft-Delete with Cascade Visibility
```sql
-- Already enforced by existing code queries:
-- Active list: WHERE is_active = true  (admin_employees_screen.dart:92)
-- Schedule:    WHERE is_active = true  (shift_scheduler_screen.dart:103)
-- Attendance:  WHERE employee_id = X   (no is_active filter — logs preserved)
-- Reports:     JOIN employees ON ...   (show all, including archived)

-- Optional: Convenience view for Riwayat Karyawan
CREATE OR REPLACE VIEW archived_employees AS
SELECT e.*, o.name as outlet_name
FROM employees e
LEFT JOIN outlets o ON e.home_outlet_id = o.id
WHERE e.is_active = false
ORDER BY e.archived_at DESC NULLS LAST;
```

#### Important: No Separate `is_archived` Column Needed
Previous research suggested adding `is_archived` boolean separate from `is_active`. This is **unnecessary complexity**. The existing `is_active = false` + new `archived_at TIMESTAMPTZ` is sufficient:
- `is_active = false AND archived_at IS NOT NULL` → archived employee
- `is_active = false AND archived_at IS NULL` → legacy inactive employee (if any)
- `is_active = true` → active employee

No existing queries need modification. All active queries already filter `is_active = true`.

---

### Feature 4: Quick Kepala Gerai SQL Setup

**Verdict: NO new packages. SQL script only.**

#### How It Already Works (verified in codebase)
- `admin_login_screen.dart` lines 59-89: Login reads `app_role` from `userMetadata` or `appMetadata`
- Accepted roles: `'admin'` or `'kepala_gerai'`
- `managed_outlet_id` read from `appMetadata` for Kepala Gerai
- `AppProvider.setKepalaGeraiMode(outletId)` restricts dashboard to single outlet

#### SQL Script Pattern (Two-Step — Safer)
```sql
-- Step 1: Create user via Supabase Dashboard → Authentication → Users → "Create user"
-- Set email + password via UI (handles password hashing correctly)

-- Step 2: Set role metadata via SQL Editor
-- Ganti email dan outlet_id di bawah:
UPDATE auth.users
SET raw_app_meta_data = raw_app_meta_data
  || '{"app_role": "kepala_gerai", "managed_outlet_id": "OUTLET-UUID-HERE"}'::jsonb,
    raw_user_meta_data = raw_user_meta_data
  || '{"app_role": "kepala_gerai", "managed_outlet_id": "OUTLET-UUID-HERE"}'::jsonb
WHERE email = 'kepala.rungkut@enakko.com';
```

**Why two-step**: Direct `INSERT INTO auth.users` requires manual `crypt()` for password hashing. Supabase Dashboard handles this correctly. The SQL step only adds metadata.

---

## Installation

```yaml
# Add to pubspec.yaml dependencies section:
  # NEW for v2.0 — CSV batch import
  csv: ^6.0.0
  file_picker: ^8.1.0
```

```bash
flutter pub get
```

**That's it.** No Android manifest changes. No Kotlin dependency changes. No Gradle modifications.

`file_picker` uses Android SAF (Storage Access Framework) which is available on API 24+ — matches existing `minSdk: 24`. No `READ_EXTERNAL_STORAGE` permission needed for SAF picker.

## Alternatives Considered

| Feature | Recommended | Alternative | Why Not Alternative |
|---------|-------------|-------------|---------------------|
| CSV parsing | `csv` ^6.0.0 | `fast_csv` ^0.9.0 | Faster but no BOM handling, less configurable for edge cases. 200-employee file doesn't need speed. |
| CSV parsing | `csv` ^6.0.0 | Manual `String.split(',')` | Breaks on commas in names ("Sari, S.Pd"), quoted fields, multi-line values. Already have `_escapeCsv()` — import needs full parser. |
| File picker | `file_picker` ^8.1.0 | `open_file` ^3.5.0 | Less maintained, fewer platform features. `file_picker` is the standard. |
| File picker | `file_picker` ^8.1.0 | MethodChannel + Android Intent | Unnecessary complexity for a single file picker use case. |
| Live activity | Extend `flutter_overlay_window` | `live_activities` package | iOS-focused. Android support is basic notification — inferior to existing Kotlin RemoteViews. Would duplicate existing infrastructure. |
| Live activity | Extend existing notification | New foreground service | Android limits concurrent foreground services. Battery drain. Existing service has 10s event loop. |
| Soft-delete | `is_active` + `archived_at` | Separate `archived_employees` table | Moving rows between tables = foreign key nightmares. `attendance_logs.employee_id` would break. Column flag is standard pattern. |
| Soft-delete | Reuse `is_active` | Add separate `is_archived` boolean | Unnecessary — `is_active = false` already gates everything. Adding `archived_at` timestamp gives the audit trail without a redundant boolean. |
| Kepala Gerai | SQL script in dashboard | Supabase Edge Function API | Over-engineered for "run once per outlet setup". SQL editor is faster. |
| Break status | Supabase Realtime subscription | Polling timer | Wastes bandwidth, battery, Supabase quota. Realtime is push-based and already proven in existing dashboard subscriptions. |
| Bulk insert | Supabase `.insert(List<Map>)` | Individual inserts in loop | 100 employees = 100 HTTP requests. Batch = 1-2 requests. |

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------------|
| `live_activities` package | Duplicates existing Kotlin RemoteViews notification. Adds iOS boilerplate for an Android-only project. | Extend `KioskNotificationHelper.kt` and `OverlayPillState` model. |
| `firebase_messaging` / FCM | Live activity pill is LOCAL (same device kiosk). No remote push needed. Break status comes from Supabase Realtime, not push notifications. | Use existing `supabase_flutter` Realtime subscriptions. |
| `flutter_background_service` | Competes with existing `flutter_foreground_task`. Two background services = OEM battery killers will terminate one. | Extend existing `KioskBackgroundService` which uses `flutter_foreground_task`. |
| `excel` / `spreadsheet_decoder` | Over-engineered for CSV import. If Excel `.xlsx` format needed later, add then. CSV is the requirement. | Use `csv` package for `.csv` files only. |
| `supabase` service_role key in app | Service role key in client APK = security breach. Never expose admin API key in distributed app. | Use Supabase SQL editor for admin operations (Kepala Gerai setup). |
| `flutter_secure_storage` | Removed in v1.0 due to ANR issues on kiosk tablets (see PROJECT.md constraints). | `shared_preferences` (existing, proven stable). |
| Separate `is_archived` boolean column | Redundant with existing `is_active` flag. Creates confusion about which boolean is canonical. | Use `is_active = false` + `archived_at IS NOT NULL` to identify archived employees. |

## Version Compatibility

| New Package | Compatible With | Notes |
|-------------|-----------------|-------|
| `csv` ^6.0.0 | Dart >=3.0.0 | Pure Dart, no native code. No Android manifest changes. Zero platform dependencies. |
| `file_picker` ^8.1.0 | Flutter 3.x, Android minSdk 21+ (project uses 24) | Uses Android SAF internally. No special permissions needed — SAF handles file access natively. |
| `file_picker` ^8.1.0 | Kotlin 1.9.25 | Pure plugin with no Kotlin version constraint. |
| `csv` ^6.0.0 | `supabase_flutter` ^2.8.4 | No interaction — csv parses in memory, Supabase handles database insert. |

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `file_picker` SAF fails on specific OEM tablet | LOW | MEDIUM | `share_plus` uses similar SAF mechanisms for export and already works across 4 outlets. Fallback: manual file path input. |
| `flutter_overlay_window` killed by OEM battery optimization | MEDIUM (known issue) | LOW | Already mitigated in v1.1: `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` + MIUI permission handler + `flutter_foreground_task`. Code has matchParent fallback for restrictive OEMs. |
| CSV with wrong encoding from Excel | MEDIUM | LOW | `csv` package handles most cases. Add manual UTF-8 BOM stripping before parsing. Show preview before import confirmation. |
| Supabase Realtime subscription for break status drops | LOW | LOW | Existing pattern: realtime subscriptions in dashboard already handle reconnection. Break status is nice-to-have on overlay, not critical for attendance. |
| Supabase `auth.users` SQL schema changes in future versions | LOW | HIGH | The SQL script for Kepala Gerai setup touches `auth.users` directly. Supabase gotrue schema is generally stable but pin to current Supabase project version. Document exact column names. |

## Sources

- **Codebase analysis** (HIGH confidence): `overlay_task.dart`, `kiosk_background_service.dart`, `KioskNotificationHelper.kt`, `MainActivity.kt`, `admin_login_screen.dart`, `admin_employees_screen.dart`, `shift_scheduler_screen.dart`, `employee.dart`, `overlay_pill_state.dart`, `notification_kiosk.xml`, `notification_kiosk_expanded.xml`, `AndroidManifest.xml`
- **liveaction.md** (HIGH confidence): Project's own 1100-line research document on Live Activity patterns, Grab architecture, Android notification approaches — confirms existing RemoteViews approach is correct
- **Existing working code** (HIGH confidence): Current overlay + notification + foreground service stack verified operational across 4 outlets with 14 employees
- **pub.dev packages** (MEDIUM confidence): `csv` and `file_picker` versions based on training data — verify latest version at `flutter pub add` time
- **Supabase Auth patterns** (MEDIUM confidence): `auth.users` metadata pattern verified against existing `admin_login_screen.dart` — app already reads `app_role` and `managed_outlet_id` from metadata fields

---
*Stack research for: Absensi Enakko v2.0 Admin Tools + Live Activity*
*Researched: 2025-07-14*
