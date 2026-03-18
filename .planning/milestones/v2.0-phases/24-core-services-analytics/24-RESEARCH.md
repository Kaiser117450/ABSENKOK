# Phase 24: Core Services + Analytics — Research

**Researched:** 2026-03-18
**Phase Goal:** Admin/Kepala Gerai can see attendance rate metrics, overtime flags, and receive missing clock-out notifications — all powered by testable service layer

## 1. Phase 23 Foundation (What's Already Deployed)

### Supabase RPC Functions (production)
All 4 RPC functions are live in Supabase (`sql/phase23_rpc_functions.sql`):
- `get_attendance_rates(p_outlet_id, p_start, p_end)` → JSON `{total_employees, days_in_range, total_present, rate}`
- `get_weekly_trend(p_outlet_id, p_days)` → JSON array `[{date, count}]`
- `get_outlet_comparison(p_start, p_end)` → JSON array `[{outlet_id, outlet_name, total_employees, total_present, rate}]` (admin-only)
- `update_employee_streak(p_employee_id)` → JSON `{current_streak, longest_streak}`

All functions have:
- `SECURITY DEFINER` + role checks (`admin`, `kepala_gerai`)
- `kepala_gerai` scoped to `managed_outlet_id` from JWT
- Uses `employees.home_outlet_id` (NOT `outlet_id`)

### employee_streaks table (production)
- Schema: `employee_id (PK, FK→employees), current_streak, longest_streak, last_masuk_date, updated_at`
- RLS: admin sees all, kepala_gerai sees only their managed outlet's employees
- Insert/Update via RPC only (RLS blocks direct writes)

### Indexes (production, `sql/phase23_indexes.sql`)
- Likely covering `attendance_logs(scan_outlet_id, type, scanned_at)` for RPC performance

## 2. Codebase Patterns

### Service Layer Pattern
Existing services in `lib/services/`:
- Singleton pattern: `BadgeService._()` + `static final instance = BadgeService._();`
- Uses `SupabaseClientFactory.admin` for all Supabase calls
- Guards with `supabaseReady` global bool before any Supabase calls
- Error handling: try/catch with `debugPrint` for non-critical failures

### State Management
- Riverpod `AppProvider` with `AppState` immutable class + `copyWith()`
- `ConsumerStatefulWidget` for screens
- No existing pattern for async data providers (all inline in screens)

### Notification Infrastructure
- `KioskBackgroundService` in `lib/services/kiosk_background_service.dart`
- Uses `flutter_local_notifications` (already in pubspec)
- Notification channels: `absensi_enakko_kiosk` (scan), `absensi_enakko_pill` (live activity), `absensi_enakko_keepalive` (foreground service)
- MethodChannel `com.enakko.kiosk/notification` for custom RemoteViews
- **No background isolate or `compute()` usage exists yet** — this is a NEW pattern

### Shift Templates (for overtime calculation)
- `ShiftSlot` model: `name, startTime (TimeOfDay), endTime (TimeOfDay), color`
- Standard shifts: Pagi (09-17), Siang (12-20), Sore (14-22) — all 8 hours
- `ShiftTemplate` contains list of `ShiftSlot`s per outlet
- Schedule stored in SQLite (`ScheduleSQLiteService`) per outlet
- `ScheduleEntry` links employee to date + shift

### Dashboard Screen
- `AdminDashboardScreen` is a large `ConsumerStatefulWidget` (~1400+ lines)
- Currently shows: outlet selector, today's masuk/break/pulang/backup counts, total employees, open shifts, attendance logs list
- Already has realtime subscription via Supabase channels
- **Attendance rate card does NOT exist yet** — this is new

## 3. Technical Analysis Per Requirement

### ANLYT-01: Attendance Rate Card
- **RPC exists:** `get_attendance_rates` returns exactly what's needed
- **UI needed:** Card widget on admin dashboard with daily/weekly/monthly toggle
- **Format:** "Hadir 14/16 hari — 87.5%" (concrete counts + percentage)
- **Approach:** New `AttendanceRateService` calls RPC, dashboard embeds card widget
- **Scope:** kepala_gerai sees own outlet only (JWT-enforced by RPC)

### ANLYT-02: Overtime Tracking
- **Need:** Compare actual hours worked vs shift template duration
- **Data available:** `attendance_logs` has masuk/pulang timestamps, `ScheduleEntry` has shift slot times
- **Calculation:** For each employee/day: `pulang_time - masuk_time > shift.endTime - shift.startTime`
- **Challenge:** Schedule is in SQLite, attendance in Supabase. Must join locally or create RPC.
- **Recommendation:** New RPC `get_overtime_flags(p_outlet_id, p_date)` that compares masuk/pulang duration vs a configurable threshold (default 8 hours). Simpler than joining with local SQLite schedule data.
- **Alternative:** Compute client-side since employee count is small (14 per outlet max)

### ANLYT-03 + ANLYT-04: Missing Clock-Out Notification (Batched)
- **Trigger:** Employee has masuk but no pulang after configurable threshold (default 10 hours)
- **Batching:** Per outlet: "3 karyawan belum pulang di Outlet A"
- **Notification channel:** New channel `absensi_enakko_missing_clockout`
- **Timer approach:** Periodic check (e.g., every 30 minutes) via existing foreground service or a dedicated Timer
- **Query:** `SELECT employee_id FROM attendance_logs WHERE type='masuk' AND scanned_at::date = CURRENT_DATE AND NOT EXISTS (SELECT 1 FROM attendance_logs a2 WHERE a2.employee_id = attendance_logs.employee_id AND a2.type='pulang' AND a2.scanned_at > attendance_logs.scanned_at)`
- **RPC recommendation:** `get_missing_clockouts(p_outlet_id, p_threshold_hours)` — returns JSON array of employees missing pulang
- **Local notification:** Use existing `flutter_local_notifications` infrastructure

### SMART-01 + SMART-04: Pattern Detection (Median Arrival Times)
- **Algorithm:** For each employee, for each day-of-week (1-7), get last 30 masuk timestamps, compute median
- **Skip rule:** Fewer than 5 data points for a day-of-week → skip
- **Storage:** Cache results in memory or SharedPreferences (small data: ~14 employees × 7 days = 98 values)
- **RPC recommendation:** `get_arrival_patterns(p_outlet_id)` — compute server-side for efficiency
- **Alternative:** `compute()` isolate with raw attendance data (see SMART-03)

### SMART-02: Late Pattern Notification
- **Trigger:** Employee masuk time > median_for_day_of_week + 5 minutes
- **When:** After each NFC masuk scan, check if employee is late vs pattern
- **Notification:** Local notification to admin/kepala_gerai device
- **Challenge:** Kiosk device is shared — notification goes to the kiosk tablet, not admin's personal phone
- **Practical approach:** Show late flag on dashboard, send notification on the kiosk that admin will see

### SMART-03: Background Isolate for Pattern Detection
- **No existing isolate/compute usage** in the codebase
- **Flutter `compute()` function** is the simplest approach — runs a function in a separate isolate
- **Pattern:** `final result = await compute(analyzePatterns, attendanceData);`
- **Constraint:** `compute()` function must be top-level or static (not a closure)
- **Data transfer:** Pass serializable data (List<Map>) to isolate, return serializable result
- **Integration point:** After NFC scan success in `KioskScanScreen`, trigger pattern check in background
- **Performance guarantee:** NFC scan completes immediately, pattern detection runs post-scan via `compute()`

## 4. New Supabase RPC Functions Needed

### `get_overtime_flags(p_outlet_id UUID, p_date DATE, p_threshold_hours NUMERIC DEFAULT 8)`
Returns employees who worked longer than threshold:
```sql
-- Compare pulang - masuk duration vs threshold
-- Only for employees who have both masuk and pulang on p_date
```

### `get_missing_clockouts(p_outlet_id UUID, p_threshold_hours NUMERIC DEFAULT 10)`
Returns employees with masuk but no pulang after threshold hours:
```sql
-- Employees with today's masuk > p_threshold_hours ago and no subsequent pulang
```

### `get_arrival_patterns(p_outlet_id UUID, p_days INT DEFAULT 30)`
Returns median arrival times per employee per day-of-week:
```sql
-- For each active employee in outlet:
--   For each day_of_week (0-6):
--     Get masuk timestamps from last p_days
--     If count >= 5: compute median extract(epoch from scanned_at::time)
--     Else: null (skip)
```

## 5. Architecture Recommendation

### New Files to Create
```
lib/services/
├── analytics_service.dart        # Calls get_attendance_rates, get_weekly_trend, get_overtime_flags
├── pattern_detection_service.dart # Background isolate for pattern analysis
├── missing_clockout_service.dart  # Periodic check + notification for missing pulang
```

### Service Layer Design
- Each service: singleton pattern matching `BadgeService`
- All Supabase calls through `SupabaseClientFactory.admin`
- Guard with `supabaseReady` before calls
- Return typed Dart objects, not raw JSON

### Notification Strategy
- **Missing clock-out:** Timer-based (every 30 min) in `KioskBackgroundService` or standalone service
- **Late pattern:** Triggered after NFC masuk scan success
- Both use `flutter_local_notifications` with new dedicated channel
- **Batching:** Collect per-outlet, send single notification with count

### Dashboard Integration
- Add attendance rate card as new widget at top of `AdminDashboardScreen`
- Overtime flags as alert/warning section
- Minimal UI in Phase 24 — full chart dashboard is Phase 25

## 6. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Schedule data in SQLite, attendance in Supabase | Can't join for overtime | Use time-based threshold (8h default) instead of schedule-aware comparison |
| Kiosk is shared device — notifications go to tablet | Admin may not see alerts | Show flags on dashboard prominently; consider flag counter in app bar |
| `compute()` isolate can't access Supabase client | Pattern detection needs data | Fetch data first, pass raw List<Map> to isolate, process in isolate |
| Small dataset (14 employees × 4 outlets) | Patterns may not be statistically significant | SMART-04 skip rule (< 5 data points) already handles this |
| Production database — no destructive migrations | Must be additive only | All new RPC functions use CREATE OR REPLACE, no table alterations |

## 7. Dependency Analysis

### Phase 23 (COMPLETE) → Phase 24
- `get_attendance_rates` RPC ✅ deployed
- `get_weekly_trend` RPC ✅ deployed
- `employee_streaks` table ✅ deployed
- `update_employee_streak` RPC ✅ deployed

### Phase 24 → Phase 25 (downstream)
- Phase 25 needs: analytics service layer, fl_chart integration, streak leaderboard
- Phase 24 delivers: service layer + attendance rate card + overtime flags
- fl_chart dependency should be added in Phase 25 (not needed for Phase 24)

### New Dependencies
- **None for Phase 24** — all notification + isolate capabilities are built into Flutter SDK
- fl_chart is Phase 25 scope

## Validation Architecture

### Testable Boundaries
1. **Service methods** — can be unit tested with mock Supabase responses
2. **RPC functions** — tested via SQL with known test data
3. **Background isolate** — `compute()` function is a pure function, easily testable
4. **Notification triggers** — timer-based, can verify with mock clock

### Key Validation Points
- Attendance rate calculation matches RPC output
- Overtime flag triggers at correct threshold
- Missing clock-out batches correctly per outlet
- Pattern median computation is accurate
- `compute()` does not block main isolate (< 2s per SC-5)
- Notifications use correct channels and content format

---

## RESEARCH COMPLETE

Research covers all 8 requirements (ANLYT-01 through ANLYT-04, SMART-01 through SMART-04) with concrete implementation paths, RPC function designs, and architectural recommendations grounded in the existing codebase patterns.
