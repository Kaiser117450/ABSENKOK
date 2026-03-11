# Pitfalls Research

**Domain:** Adding admin tools + persistent overlay to production Flutter NFC attendance kiosk
**Researched:** 2025-07-14
**Confidence:** HIGH — based on direct codebase analysis of 19K+ LOC, production schema with 4 outlets/14 employees

---

## Critical Pitfalls

### Pitfall 1: Soft-Archive Breaks Existing Queries That Don't Filter `is_active`

**What goes wrong:**
Setting `employees.is_active = false` for archived employees causes them to vanish from 5+ screens that currently fetch `SELECT * FROM employees` **without** filtering `is_active`. The employee list on `admin_employees_screen.dart` line 80-86 fetches ALL employees (`select('*')`) and only visually dims inactive ones. But the dashboard (`admin_dashboard_screen.dart` line 99-102) filters `.eq('is_active', true)` — meaning archived employees' attendance logs still reference them via `attendance_logs.employee_id`, but they're invisible in the employee count. The shift scheduler (`shift_scheduler_screen.dart` line 103) filters `.eq('is_active', true)` — archived employees with **future** `schedule_entries` become phantom entries: assigned to shifts but invisible in the UI.

**Why it happens:**
The current `is_active` toggle is a soft boolean used in exactly 2 places (dashboard count + scheduler load). It was never designed for "archive" semantics. Developers assume flipping `is_active = false` is the complete solution without auditing every query that touches `employees`.

**How to avoid:**
1. **Audit every Supabase query that touches `employees` table.** There are at least 6 distinct query paths:
   - `admin_employees_screen.dart` line 80 — `select('*')` with NO `is_active` filter (shows all)
   - `admin_dashboard_screen.dart` line 99 — `.eq('is_active', true)` (correct for count)
   - `shift_scheduler_screen.dart` line 103 — `.eq('is_active', true)` (correct for assignment)
   - `admin_reports_screen.dart` — joins `employees` via attendance_logs (must still show archived employee names in historical reports)
   - `employee_cache_service.dart` — NFC lookup cache (must reject scans from archived employees)
   - `admin_dashboard_screen.dart` line 126 — attendance_logs join includes `employees(id, name, photo_url, active_badge_id)` — archived employees' names must still render in today's log if they scanned before being archived
2. **Add an `archived_at` timestamp column** instead of relying solely on `is_active = false`. This gives you a clear "when" and distinguishes "manually deactivated" from "archived into history."
3. **Clean up future schedule_entries** at archive time — DELETE entries where `date >= CURRENT_DATE` for the archived employee, or warn the admin that future shifts exist.
4. **Keep the FK relationship intact** — `attendance_logs.employee_id` must still resolve. NEVER delete employee rows.

**Warning signs:**
- Employee name shows as "null" or "Unknown" in attendance reports
- Dashboard employee count doesn't match employees list count
- Schedule grid shows empty rows for slots assigned to archived employees
- NFC scan accepts card for archived employee (attendance_logs records created for ghost employee)

**Phase to address:**
Phase 1 (Soft-Archive) — this is the foundational database migration, must be rock-solid before anything else.

---

### Pitfall 2: Employee Cache Serves Stale Data After Archive — NFC Scans Still Work for Archived Employees

**What goes wrong:**
`EmployeeCacheService` (line 15) has a 5-minute TTL. If an admin archives an employee, the NFC cache on the kiosk tablet still holds the old `Employee` object with `isActive: true` for up to 5 minutes. During this window, the archived employee can still tap their NFC card and successfully clock in. The attendance log gets created and synced to Supabase with a valid `employee_id` pointing to a now-archived employee.

**Why it happens:**
The cache was designed for performance (avoid Supabase lookup per scan), not for access control. There's no cache invalidation mechanism — it relies entirely on TTL expiry. The kiosk tablet runs autonomously without real-time push from admin actions.

**How to avoid:**
1. **Add `is_active` check in the NFC scan flow**, not just at cache time. After cache hit, verify `employee.isActive` before proceeding.
2. **Subscribe to employee realtime changes on the kiosk** — the kiosk already has Supabase connectivity. Subscribe to `employees` table changes and invalidate the cache entry when `is_active` flips.
3. **Immediate cache clear** on archive action — but this only works if admin and kiosk share the same Dart isolate (they don't — kiosk is a separate device).
4. **Best approach:** Add the `is_active` check at the scan validation point (kiosk_scan_screen), and show a friendly "Karyawan tidak aktif" message instead of recording attendance.

**Warning signs:**
- Attendance logs appear for employees who were archived hours ago
- Reports show activity from "non-aktif" employees

**Phase to address:**
Phase 1 (Soft-Archive) — must be part of the archive feature, not an afterthought.

---

### Pitfall 3: CSV Import Inserts Orphan Employees with Invalid `home_outlet_id`

**What goes wrong:**
Batch CSV import accepts outlet names (e.g., "Enakko Sudirman") but the database uses UUIDs for `home_outlet_id`. If the CSV contains a typo ("Enakko Sudirmann") or an outlet name that doesn't match exactly, the insert either: (a) fails with FK constraint violation and potentially rolls back the entire batch, or (b) sets `home_outlet_id = null`, creating employees visible in the "Belum punya gerai" state (see `admin_employees_screen.dart` line 680).

**Why it happens:**
CSV data comes from spreadsheets maintained by restaurant managers who type outlet names, not UUIDs. String matching is always fuzzy. Indonesian names with typos are common.

**How to avoid:**
1. **Two-pass validation:** First pass parses and validates ALL rows, builds a list of errors. Second pass inserts only validated rows. Never insert-as-you-go.
2. **Fuzzy outlet matching:** Use Levenshtein distance or `toLowerCase().trim()` normalization. Show a confirmation dialog: "Did you mean 'Enakko Sudirman'?"
3. **Preview screen before commit:** Show parsed CSV data in a table with red/yellow indicators for issues. Let admin fix outlet assignments in a dropdown before confirming import.
4. **No partial failures silently:** If 8 of 10 rows succeed and 2 fail, the admin must know WHICH 2 failed and WHY. Show results summary with per-row status.
5. **Outlet name → ID lookup map:** Pre-load all `outlets` rows, build `Map<String, String>` (lowercase name → id). Reject rows where outlet name doesn't match.

**Warning signs:**
- Employees appear with "Belum punya gerai" after CSV import
- Import "succeeds" but employee count doesn't match expected
- Employees assigned to wrong outlet

**Phase to address:**
Phase 2 (CSV Import) — validation and preview UI are table stakes, not nice-to-haves.

---

### Pitfall 4: CSV Encoding Corruption — Indonesian Names with Special Characters

**What goes wrong:**
Indonesian names like "Siti Nurhaliza", "Ahmad Syahrizal", or names with apostrophes ("M. Nur'ain") are generally ASCII-safe. BUT: CSV files exported from Excel on Windows use Windows-1252 encoding by default, not UTF-8. If the CSV is opened/re-saved in a different tool, characters can get mangled. More critically, the `csv` Dart package or raw string splitting on `,` will break on names containing commas (e.g., "Muhammad, S.Pd") if not properly quoted.

**Why it happens:**
Excel is the universal spreadsheet tool for Indonesian restaurant managers. Excel's CSV export behavior varies by locale and version. BOM (Byte Order Mark) handling differs across platforms.

**How to avoid:**
1. **Force UTF-8 with BOM detection:** When reading the file, check for UTF-8 BOM (`\xEF\xBB\xBF`) and strip it. Try decoding as UTF-8 first; fall back to Latin-1 if decode fails.
2. **Use a proper CSV parser**, not `String.split(',')`. Dart's `csv` package handles quoted fields correctly.
3. **Validate each field after parse:** Check for mojibake patterns (sequences like `Ã©` or `â€™` which indicate encoding corruption).
4. **Provide a CSV template download** with correct encoding and header row — this prevents 90% of format issues.
5. **Limit to 50 rows per import** — this is a 14-employee company scaling to 200. Batch import of thousands is not the use case; keep it simple.

**Warning signs:**
- Employee names display garbled characters after import
- Import crashes with `FormatException` on certain rows
- CSV with Indonesian names looks correct in Notepad but fails in app

**Phase to address:**
Phase 2 (CSV Import) — encoding handling must be tested with real Excel-exported CSVs.

---

### Pitfall 5: Supabase Auth `admin.createUser()` Requires Service Role Key — Exposing It in Client App

**What goes wrong:**
Creating Supabase Auth users programmatically (for Quick Kepala Gerai setup) requires the **service_role** key, which has full database access bypassing all RLS. Developers embed this key in the Flutter app to call `supabase.auth.admin.createUser()`. This exposes the service_role key in the APK, which is extractable via reverse engineering — effectively giving anyone full database access.

**Why it happens:**
The Supabase client SDK's `auth.admin` namespace requires service_role privileges. The current app uses only the anon key (`SUPABASE_ANON_KEY` in `.env`). Developers unfamiliar with Supabase's security model think they can just switch keys.

**How to avoid:**
1. **Do NOT put service_role key in the Flutter app.** Period.
2. **Use the SQL Editor approach** (already planned in PROJECT.md): Provide a SQL script that the developer runs in Supabase Dashboard's SQL Editor. The script:
   ```sql
   -- Create auth user
   INSERT INTO auth.users (email, encrypted_password, email_confirmed_at, raw_app_meta_data)
   VALUES ('kepala@enakko.com', crypt('password', gen_salt('bf')), now(),
           '{"app_role": "kepala_gerai", "managed_outlet_id": "<OUTLET_UUID>"}');
   ```
3. **Or use a Supabase Edge Function** that accepts admin credentials, validates them, and creates the user server-side.
4. **For the v2.0 scope:** SQL script is the right approach — it's a one-time setup per Kepala Gerai, not a frequent action. Don't over-engineer.

**Warning signs:**
- `SUPABASE_SERVICE_ROLE_KEY` appears anywhere in Dart code or `.env`
- Auth operations fail with "service_role required" error
- Attempting `supabase.auth.admin.createUser()` with anon key

**Phase to address:**
Phase 3 (Quick Kepala Gerai Setup) — must use SQL script approach, never client-side admin API.

---

### Pitfall 6: RLS Policy Conflicts When Adding `kepala_gerai` Role

**What goes wrong:**
Current RLS policies (if any) on the `employees`, `attendance_logs`, and `schedule_entries` tables likely use `auth.uid()` or `auth.jwt() ->> 'app_role'` for access control. When adding a new Kepala Gerai user with `app_role = 'kepala_gerai'` and `managed_outlet_id`, the RLS policies must scope their access to ONLY their outlet's data. But the current app uses `SupabaseClientFactory.admin` (which is just `Supabase.instance.client`) for ALL queries — so the Kepala Gerai's authenticated session must be properly scoped by RLS.

Common mistakes:
- RLS policy allows `kepala_gerai` to see ALL employees (missing `home_outlet_id = managed_outlet_id` check)
- RLS policy blocks `kepala_gerai` from writing attendance logs (kiosk still uses anon key, separate from admin auth)
- Adding RLS policies retroactively locks out the existing admin user
- `managed_outlet_id` stored in `raw_user_meta_data` vs `raw_app_meta_data` — the login screen checks BOTH (line 61-62, 77-79), but new SQL must set the right one

**Why it happens:**
The codebase already handles `kepala_gerai` role in Dart (`admin_login_screen.dart` line 65, `app_provider.dart` line 143). But the actual RLS policies in Supabase may not enforce outlet scoping at the database level — it's currently done client-side in Dart (`if (isKepalaGerai) q = q.eq('home_outlet_id', managedOutletId)`).

**How to avoid:**
1. **Audit existing RLS policies** on all tables before adding new ones. Use `SELECT * FROM pg_policies` in Supabase SQL Editor.
2. **Test with the actual kepala_gerai user** — log in as them and verify they can ONLY see their outlet's data.
3. **The SQL script must set `raw_app_meta_data`** (not `raw_user_meta_data`), because `appMetadata` is server-controlled and secure. `userMetadata` can be modified by the user via `auth.updateUser()`.
4. **Don't break the kiosk:** Kiosk uses anon key without auth. RLS policies for authenticated users must not affect unauthenticated kiosk operations. Verify kiosk INSERT into `attendance_logs` still works after policy changes.

**Warning signs:**
- Kepala Gerai sees employees from all outlets
- Admin loses access after RLS policy change
- Kiosk stops recording attendance after policy change
- Login works but dashboard shows empty data

**Phase to address:**
Phase 3 (Quick Kepala Gerai Setup) — RLS verification is mandatory before deploying the SQL script.

---

### Pitfall 7: Persistent Overlay Memory Leak from Undisposed Timers and Stream Subscriptions

**What goes wrong:**
The current `overlay_task.dart` creates multiple `Timer` objects (`_clockTimer`, `_eventResetTimer`, `_autoCollapseTimer`) and a `StreamSubscription` (`_dataSub`). These are properly disposed in `dispose()` (line 289-295). BUT: for the v2.0 "persistent live activity pill" with Supabase realtime subscription (break status, fun facts), adding a `RealtimeChannel` subscription inside the overlay isolate creates a **second Supabase connection** that never gets cleaned up. The overlay runs in a separate Dart isolate (`@pragma('vm:entry-point') overlayMain()`) which doesn't have access to the main app's Supabase client.

**Why it happens:**
`flutter_overlay_window` runs `overlayMain()` in an **isolated Flutter engine** — it has its own widget tree, its own `main()`, and NO access to the main app's providers, services, or Supabase client. Developers assume they can `import` Supabase and use it in the overlay, but initializing a second Supabase instance creates a persistent connection that's never properly torn down.

**How to avoid:**
1. **Do NOT initialize Supabase inside the overlay.** The overlay is a pure UI renderer.
2. **Pass data to the overlay via `FlutterOverlayWindow.shareData()`** — this is already the pattern used (line 400, 419). The main app fetches realtime data and pushes it to the overlay as serialized strings.
3. **For break status:** Subscribe to `attendance_logs` realtime in the **main app** (kiosk_background_service), detect break/kembali events, then push updated `OverlayPillState` to overlay via `shareData()`.
4. **For fun facts:** Generate/fetch fun facts in the main app's `_rotateNotification()` timer (already runs every 5 seconds), push to overlay.
5. **Memory budget:** The overlay window is tiny (380x96px). Keep it stateless as possible. No network calls, no database, no heavy computation.

**Warning signs:**
- Overlay starts consuming >50MB memory after hours of operation
- `Supabase.initialize()` called in `overlayMain()`
- Memory grows linearly over time (leak)
- Device becomes sluggish after 12+ hours

**Phase to address:**
Phase 4 (Persistent Live Activity) — architecture must be decided upfront: main app is the data source, overlay is a dumb renderer.

---

### Pitfall 8: Android OEM Battery Optimization Kills Foreground Service After Hours

**What goes wrong:**
The existing foreground service (`flutter_foreground_task`) with `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission works on stock Android. But Xiaomi (MIUI/HyperOS), Samsung (One UI), Oppo (ColorOS), and Vivo (Funtouch OS) have **additional proprietary battery optimization** that kills foreground services regardless of the standard Android permission. The app already has a MIUI detection MethodChannel (`miuiChannel` in `MainActivity.kt` line 13, `isMiuiOrHyperOs()` line 104), but it's unclear if it's actively used to prompt users.

On these OEM devices:
- MIUI: "Battery saver" kills apps not in the "No restrictions" list
- Samsung: "Sleeping apps" and "Deep sleeping apps" kill background services
- Oppo/Vivo: "App Quick Freeze" terminates foreground services after inactivity

This means the persistent overlay AND the foreground service (NFC scanning) can die silently. The kiosk becomes unresponsive.

**Why it happens:**
Chinese OEMs aggressively optimize battery to extend device battery life. Standard Android `IGNORE_BATTERY_OPTIMIZATIONS` is necessary but NOT sufficient on these devices.

**How to avoid:**
1. **The app already handles MIUI** — `tryOpenMiuiPermissions()` in `MainActivity.kt` opens MIUI's per-app permission editor. This pattern needs to be **actively called** during kiosk setup, not just available.
2. **Add Samsung detection** — check for `com.samsung.android.lool` (Device Care app) and guide user to whitelist.
3. **Add a "Setup Guide" screen** shown once during kiosk setup that walks through OEM-specific steps with screenshots.
4. **Implement a heartbeat watchdog:** The `_rotateTimer` (5-second interval) already serves this purpose. If the overlay stops receiving updates for >30 seconds, show a recovery notification.
5. **For kiosk tablets:** Since these are company-owned tablets deployed at restaurants, do a ONE-TIME manual setup per device: disable battery optimization, add to autostart, disable adaptive battery. Document this in a deployment checklist.
6. **Don't rely on overlay alone** — the notification (Kotlin `KioskNotificationHelper`) is the reliable fallback. It survives OEM battery optimization because it's tied to the foreground service.

**Warning signs:**
- Overlay disappears after 30-60 minutes on Xiaomi/Samsung tablets
- NFC scanning stops working after device is idle for hours
- `FlutterOverlayWindow.isActive()` returns false unexpectedly
- Users report "app died" on specific device brands

**Phase to address:**
Phase 4 (Persistent Live Activity) — must include OEM-specific setup flow and heartbeat monitoring.

---

### Pitfall 9: Supabase Realtime Subscription Leak — Multiple Channels Never Unsubscribed

**What goes wrong:**
The dashboard already subscribes to 2 realtime channels (`dashboard:attendance_logs` and `dashboard:employees` per INTEGRATIONS.md). Adding a third subscription for break status monitoring (to feed the overlay) creates cumulative connection pressure. Worse: if the realtime subscription is created in `KioskBackgroundService.start()` but never cleaned up on `stop()`, navigating between screens or restarting the service creates **duplicate subscriptions** — each consuming a Supabase connection.

Current code pattern — `_subscribeRealtime()` in `admin_employees_screen.dart` line 58-68:
```dart
_channel?.unsubscribe(); // ← Good: cleans up before re-subscribing
_channel = SupabaseClientFactory.admin.channel('employees:realtime')...
```

But `KioskBackgroundService` (static class) has NO realtime subscription cleanup mechanism — `stop()` cancels timers and notifications but doesn't unsubscribe from any channels.

**Why it happens:**
Supabase realtime subscriptions are easy to create but easy to forget to clean up, especially in static service classes. The free tier allows 200 concurrent connections, and each channel consumes one.

**How to avoid:**
1. **Single subscription point:** Create the break-status realtime subscription in `KioskBackgroundService.start()` and store it as a static `RealtimeChannel?` field. Unsubscribe in `stop()`.
2. **Channel naming convention:** Use unique channel names per session (e.g., `kiosk:break_status:${outletId}`) to avoid duplicate subscriptions.
3. **Add `_channel?.unsubscribe()` to `KioskBackgroundService.stop()`** — follow the same try-catch pattern used for `stopService()`, `cancel()`, `dismissLiveNotification()`, and `hideOverlayPill()`.
4. **Connection audit:** Add a debug counter for active realtime channels. At 4 outlets × 2 dashboard channels = 8 connections. Adding break-status per kiosk = 12 total. Well within limits, but monitor.

**Warning signs:**
- `Supabase Realtime: max connections reached` error in console
- Dashboard stops updating in real-time
- Multiple identical log entries from realtime callbacks

**Phase to address:**
Phase 4 (Persistent Live Activity) — realtime subscription management is core to the overlay data pipeline.

---

### Pitfall 10: Additive Database Migration Creates Column Without Default — Breaks Existing Inserts

**What goes wrong:**
Adding a new column to `employees` (e.g., `archived_at TIMESTAMP`) or `attendance_logs` (e.g., `overlay_shown BOOLEAN`) without a DEFAULT value causes existing INSERT statements to fail with `NOT NULL constraint violation`. The sync service (`sync_service.dart` line 39-51) inserts attendance logs with a fixed set of columns — any new NOT NULL column without a default breaks ALL kiosk attendance recording.

**Why it happens:**
Developers add columns via Supabase SQL Editor or migrations and forget that production kiosks are still running the OLD app version that doesn't include the new column in its INSERT payload.

**How to avoid:**
1. **ALL new columns must be NULLABLE or have a DEFAULT value.** No exceptions for a production system.
2. **Never add NOT NULL without DEFAULT** — use `ALTER TABLE employees ADD COLUMN archived_at TIMESTAMP DEFAULT NULL`.
3. **Test migrations against the current app version:** After running the migration, verify that the v1.1 app (still deployed at kiosks) can still insert attendance logs.
4. **Use Supabase's migration system** or maintain a `migrations/` folder with numbered SQL files.
5. **Never ALTER or DROP existing columns** — this is already a stated constraint, enforce it.

**Warning signs:**
- Kiosk sync starts failing with PostgrestException after database change
- `sync_service.dart` reports all logs as "failed"
- New attendance logs stop appearing in dashboard

**Phase to address:**
Phase 1 (Soft-Archive) — the very first database migration sets the pattern for all subsequent ones.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using `is_active = false` instead of proper `archived_at` + `archived_by` columns | No migration needed | Can't distinguish "deactivated" from "archived", no audit trail of who archived | Never — the migration is trivial, do it right |
| CSV import without preview screen | Faster to build | Admins import bad data, must manually fix | Never — preview is table stakes for batch operations |
| Hardcoding Kepala Gerai SQL script without parameterization | Quick one-off setup | Must edit SQL for each new Kepala Gerai, error-prone | Acceptable for v2.0 (≤5 Kepala Gerai) — add proper tooling in v3.0 |
| Passing all overlay data via string serialization through `shareData()` | Simple, no IPC framework needed | Fragile parsing, no type safety, limited payload size | Acceptable — overlay payloads are tiny (<500 bytes) |
| No unit tests for archive/import logic | Ship faster | Regressions caught in production | Never — these touch production data, test the happy AND error paths |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Supabase Auth — user creation | Using `auth.admin.createUser()` from client app (requires service_role key) | SQL Editor script: `INSERT INTO auth.users` directly, or use Edge Function |
| Supabase Auth — role in metadata | Setting `app_role` in `raw_user_meta_data` (user-modifiable) | Set in `raw_app_meta_data` (server-controlled, not modifiable by user via `updateUser()`) |
| Supabase Realtime — overlay data | Initializing Supabase in overlay isolate for realtime subscription | Main app subscribes, pushes data to overlay via `FlutterOverlayWindow.shareData()` |
| `flutter_overlay_window` — state sharing | Assuming overlay can access main app providers/services | Overlay is an isolated engine — communicate ONLY via `shareData()` string payloads |
| `flutter_foreground_task` — service restart | Assuming `startService()` is idempotent (calling it twice creates duplicate services) | Check `FlutterForegroundTask.isRunningService` before calling `startService()` |
| Supabase FK constraints — CSV import | Inserting employees with `home_outlet_id` that doesn't exist in `outlets` table | Pre-validate all outlet names against `outlets` table before any INSERT |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Realtime subscription per screen + per service | Connection count grows linearly with open screens | Centralize subscriptions, unsubscribe on dispose | >50 concurrent connections (25 kiosk+admin pairs) |
| CSV import loading entire file into memory | OOM crash on large CSV | Stream-parse CSV line by line; but for 200 employees, in-memory is fine | >10,000 rows (not realistic for this app) |
| Overlay timer firing every 5 seconds for 24/7 operation | Timer callbacks accumulate if overlay widget rebuilds | Use single `Timer.periodic`, cancel in `dispose()`, verify `mounted` in callback | After 30+ days without restart |
| Employee cache never evicts | Memory grows with every unique NFC scan | Current `_cache` Map has no size limit | >500 unique employees (not realistic for 200 target) |
| Full `_loadData()` on every realtime change | Database hammered on every INSERT into attendance_logs | Debounce realtime callbacks (e.g., 500ms), or only reload affected rows | >50 scans/minute (busy outlet during shift change) |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Embedding `SUPABASE_SERVICE_ROLE_KEY` in Flutter app | Full database access for anyone who decompiles APK | Never ship service_role key in client apps; use SQL Editor or Edge Functions |
| `kepala_gerai` role scoping done only in Dart, not in RLS | Kepala Gerai can use Supabase client directly to access other outlets' data | Add RLS policies: `WHERE home_outlet_id = (auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id')` |
| CSV import without sanitization | SQL injection via crafted employee names (unlikely with Supabase SDK, but defense in depth) | Use parameterized inserts (Supabase SDK does this), trim/validate all fields |
| Archived employee NFC card still works during cache TTL | Ex-employee can clock in for up to 5 minutes after being archived | Check `is_active` at scan time, not just cache time |
| Admin login exposes stack traces in production | Attacker learns internal structure from error messages | Wrap error display in `kDebugMode` check (already flagged in CONCERNS.md) |
| Hardcoded admin name "Akmal" on login screen | Social engineering risk — reveals admin name | Replace with generic greeting or fetch from user profile |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Archive employee without confirmation of consequences | Admin archives employee, future schedule entries become orphaned, admin doesn't know | Show dialog: "Andi has 3 future shift entries. Archive will remove them. Continue?" |
| CSV import with no preview | Admin imports 15 employees, 3 have wrong outlet, discovers days later | Show preview table with validation status per row before committing |
| Silently succeeding with partial CSV import | Admin thinks all 15 imported, actually only 12 succeeded | Show clear summary: "12 berhasil, 3 gagal" with error details per failed row |
| Overlay blocks touch input on screen edge | Users can't tap UI elements near top of screen because overlay captures touch | Use `OverlayFlag.focusPointer` (already set) and keep overlay area small (380x96) |
| No undo for archive | Admin accidentally archives wrong employee, no way to restore | Add "Restore" action in Riwayat Karyawan history page |

## "Looks Done But Isn't" Checklist

- [ ] **Soft-Archive:** Employee removed from active list, but attendance report still shows their historical data with correct name — verify reports JOIN still works
- [ ] **Soft-Archive:** Schedule entries for archived employee are cleaned up — verify no phantom shifts in scheduler grid
- [ ] **Soft-Archive:** NFC scan for archived employee is rejected within seconds (not 5-minute cache TTL) — verify kiosk-side validation
- [ ] **Soft-Archive:** Realtime subscription on `employees` table triggers dashboard refresh when `is_active` changes — verify badge count updates
- [ ] **CSV Import:** File with Windows-1252 encoding imports correctly — test with real Excel CSV export
- [ ] **CSV Import:** Duplicate employee name in CSV is detected and flagged — verify name collision handling
- [ ] **CSV Import:** Row with missing required field (name) doesn't crash parser — verify per-row error handling
- [ ] **CSV Import:** Outlet name with extra whitespace still matches — verify trim/normalize in matching
- [ ] **Kepala Gerai:** After SQL script, user can log in AND see only their outlet data — verify both auth AND data scoping
- [ ] **Kepala Gerai:** `managed_outlet_id` is in `raw_app_meta_data` (not `raw_user_meta_data`) — verify SQL script sets correct field
- [ ] **Kepala Gerai:** Existing admin user still works after RLS policy changes — verify no lockout
- [ ] **Persistent Overlay:** Overlay survives 24+ hours without memory growth — verify with profiler
- [ ] **Persistent Overlay:** Overlay survives device sleep/wake cycle — verify on target tablet hardware
- [ ] **Persistent Overlay:** Foreground service still running after 8 hours on target OEM device — verify on actual deployment tablet
- [ ] **Persistent Overlay:** Supabase realtime subscription doesn't leak on service restart — verify channel count

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Archived employee's attendance lost in reports | MEDIUM | Historical logs are never deleted (FK preserved); fix report query to join on `employee_id` regardless of `is_active` |
| CSV import created duplicate employees | LOW | Identify duplicates by name+outlet combo, merge attendance logs, delete duplicates manually in Supabase |
| CSV import orphaned employees (no outlet) | LOW | Update `home_outlet_id` via Supabase Dashboard for affected employees |
| Service role key leaked in APK | HIGH | Immediately rotate key in Supabase Dashboard → Settings → API; all deployed kiosks need `.env` update |
| RLS policy locks out all users | MEDIUM | Connect via Supabase Dashboard SQL Editor (bypasses RLS), fix/drop the offending policy |
| Overlay memory leak after days of operation | LOW | Restart kiosk app (kiosk tablet can be set to auto-restart daily via Android DeviceOwner API or Tasker) |
| Database migration breaks kiosk sync | HIGH | Revert migration via `ALTER TABLE DROP COLUMN` (if additive column added); or emergency deploy new APK to all 4 tablets |
| Kepala Gerai sees all outlets' data | MEDIUM | Fix RLS policy; no data was modified (read-only leak); audit logs if any writes occurred |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| P1: Queries don't filter is_active | Phase 1 (Soft-Archive) | Grep all `.from('employees')` calls, verify each handles archived state |
| P2: NFC cache serves stale archive data | Phase 1 (Soft-Archive) | Test: archive employee → NFC scan within 30 seconds → should be rejected |
| P3: CSV orphan employees (bad outlet) | Phase 2 (CSV Import) | Test: CSV with typo'd outlet name → error shown, no insert |
| P4: CSV encoding corruption | Phase 2 (CSV Import) | Test: CSV exported from Windows Excel with Indonesian names → imports correctly |
| P5: Service role key in client | Phase 3 (Kepala Gerai) | Code review: grep for `service_role`, `SERVICE_ROLE`, ensure zero matches |
| P6: RLS policy conflicts | Phase 3 (Kepala Gerai) | Test: login as kepala_gerai → verify ONLY managed outlet data visible; login as admin → verify full access; kiosk scan → verify still works |
| P7: Overlay memory leak | Phase 4 (Live Activity) | Run overlay for 4+ hours, check memory in Android Profiler |
| P8: OEM battery kills service | Phase 4 (Live Activity) | Test on actual deployment tablet brand for 24 hours |
| P9: Realtime subscription leak | Phase 4 (Live Activity) | Verify `RealtimeChannel?.unsubscribe()` in `stop()`, count active channels |
| P10: Migration breaks existing inserts | Phase 1 (Soft-Archive) | After migration, verify v1.1 kiosk can still INSERT attendance_logs |

## Production Incident Scenarios

These are the specific incidents that could happen at the 4 restaurants if pitfalls are not addressed:

| Scenario | Trigger | Impact | Severity |
|----------|---------|--------|----------|
| Kiosk stops recording attendance silently | New column added without DEFAULT | ALL 4 outlets lose attendance data until emergency APK deploy | 🔴 CRITICAL |
| Ex-employee clocks in after being fired | NFC cache TTL allows 5-minute window | Incorrect attendance records, payroll confusion | 🟡 MODERATE |
| Kepala Gerai sees all outlets' employee data | RLS not enforced at DB level | Privacy violation across outlets | 🟡 MODERATE |
| Admin locked out of dashboard | RLS policy change blocks admin role | Cannot manage attendance for any outlet until SQL fix | 🔴 CRITICAL |
| Overlay disappears on Xiaomi tablet | MIUI battery optimization kills service | Managers lose real-time visibility (notification still works as fallback) | 🟢 LOW |
| CSV import creates 10 ghost employees | No validation before INSERT | Employees without outlet assignment appear in all outlets' lists | 🟡 MODERATE |

## Sources

- Direct codebase analysis: `admin_employees_screen.dart` (1400+ LOC), `kiosk_background_service.dart` (500+ LOC), `overlay_task.dart` (587 LOC), `sync_service.dart`, `employee_cache_service.dart`
- `admin_login_screen.dart` lines 61-79 — role detection and managed_outlet_id extraction
- `shift_scheduler_screen.dart` line 103 — `.eq('is_active', true)` filter confirming scheduler excludes inactive employees
- `admin_dashboard_screen.dart` lines 99-102, 126-134 — employee count and attendance log queries
- Supabase Auth documentation — service_role vs anon key, `raw_app_meta_data` vs `raw_user_meta_data`
- `flutter_overlay_window` architecture — separate Dart isolate for overlay entry point
- `KioskNotificationHelper.kt` and `MainActivity.kt` — Kotlin notification and MIUI detection implementation
- `CONCERNS.md` — existing tech debt and fragile areas (scroll sync, notification management, admin role detection)
- `INTEGRATIONS.md` — current realtime subscriptions, auth model, sync service behavior

---
*Pitfalls research for: v2.0 Admin Tools + Live Activity — Absensi Enakko Flutter*
*Researched: 2025-07-14*
