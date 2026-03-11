# Project Research Summary

**Project:** Absensi Enakko v2.0 — Admin Tools + Live Activity
**Domain:** NFC Attendance Kiosk — Flutter/Android Production Enhancement
**Researched:** 2025-01-14
**Confidence:** HIGH

## Executive Summary

Absensi Enakko v2.0 represents a **low-risk, high-value** enhancement to a production NFC attendance kiosk serving 4 restaurants with 14 employees. The research reveals that this milestone requires **remarkably minimal new infrastructure** — only 2 new packages (csv + file_picker) for batch import, while the other 3 features build entirely on the existing, well-architected v1.1 foundation.

The v1.1 architecture already contains the extension points needed for this milestone: the persistent overlay system (`flutter_overlay_window` + Kotlin RemoteViews notification) already runs 24/7, the employee model already has soft-delete flags, and the auth system already handles Kepala Gerai role detection. What's needed is **content enhancement and lifecycle management**, not architectural rewrites. The existing foreground service's 30-second rotation timer becomes the data pipeline for break status and fun facts. The existing `is_active` flag becomes the foundation for soft-archive with proper audit trails.

**The key risk** is not technical complexity but **production data integrity**: 10 critical pitfalls have been identified, all centered on additive migrations in a live system (no column drops, no deletions). The database serves 4 active outlets — changes must be backward-compatible. Every query touching the `employees` table must be audited for proper `is_active`/`is_archived` filtering. The NFC cache must reject archived employees immediately, not after a 5-minute TTL. CSV imports must validate outlet names before touching the database. The recommended build order (Archive → CSV → SQL → Live Activity) directly addresses these pitfalls by starting with the foundational data model change and ending with the most complex (but isolated) overlay enhancement.

## Key Findings

### Recommended Stack

The v2.0 stack additions are minimal by design — the v1.1 architecture was built with extensibility in mind. Only CSV batch import requires new packages; the other features extend existing services.

**Core technologies:**
- **`csv: ^6.0.0`** (NEW) — RFC 4180-compliant CSV parsing for batch employee import. Handles BOM detection, quoted fields with commas, and encoding edge cases that Indonesian names with special characters require. The existing `_escapeCsv()` helper in reports is sufficient for export but insufficient for robust import.
- **`file_picker: ^8.1.0`** (NEW) — Native Android file picker using Storage Access Framework (SAF). Returns `PlatformFile` with bytes for in-memory parsing. Works on minSdk 24+ (matches existing requirements). No permissions needed beyond SAF's built-in access model.
- **`flutter_overlay_window: ^0.5.0`** (EXISTING) — No changes needed. The persistent overlay pill already renders via separate Dart isolate, receives data via `shareData()`, and has idle/event modes. The v2.0 enhancement extends the idle mode content to show break status and fun facts instead of static clock.
- **`flutter_foreground_task: ^8.14.0`** (EXISTING) — No changes needed. Foreground service keeps app alive 24/7. The existing `_rotateNotification()` timer (30s interval) becomes the data pipeline for pushing overlay state updates.
- **`supabase_flutter: ^2.8.4`** (EXISTING) — No changes needed. Realtime subscriptions for break detection use the same pattern as existing dashboard subscriptions. Direct SQL queries for archive/import use existing `SupabaseClientFactory.admin.from()` pattern.
- **Kotlin RemoteViews (EXISTING)** — `KioskNotificationHelper.kt` already shows Grab-style custom notification. Can be extended to show break status in notification body without structural changes.

**Why so few changes:** The v1.1 research document (`liveaction.md` — 1100 lines analyzing Live Activity patterns) led to a decision to build a custom overlay + notification system instead of using third-party packages. That investment now pays off: the persistent pill infrastructure exists, only the content layer needs enhancement.

### Expected Features

Research divided features into table stakes (users expect these), differentiators (competitive advantage), and anti-features (commonly requested but problematic).

**Must have (table stakes):**
- **Soft-archive with preserved history** — HR tools never truly delete employees. Audit trails are legally expected. The `is_active` flag exists but needs `archived_at`/`archived_by` columns for proper lifecycle tracking.
- **Restore archived employee** — Seasonal workers and rehires are common in restaurant chains. One-way archive is frustrating. Implementation is trivial: flip `is_active` back to `true`.
- **CSV import with error reporting** — Batch onboarding is expected when opening new outlets. Without it, admins manually enter 5-10 employees one-by-one for each new restaurant. Tedious and error-prone.
- **CSV duplicate detection** — Admins will inevitably upload the same file twice. Silent duplicates corrupt data. Show "already exists" per row with clear messaging.
- **Kepala Gerai quick setup** — Must promote outlet managers without code deploy. SQL script approach is correct for 4 outlets (simpler than building admin UI).

**Should have (differentiators):**
- **Riwayat Karyawan history page** — Dedicated screen showing full attendance history of archived employees with summary stats (total days worked, attendance breakdown). Most attendance apps just "delete" — Enakko preserves complete records.
- **Smart CSV validation with outlet matching** — CSV includes outlet *names* (not UUIDs). System auto-resolves "Enakko Sudirman" → UUID. Shows friendly errors: "Row 3: outlet 'Enakko Margonda' not found." Preview before commit prevents disasters.
- **Live break status on overlay pill** — When employee is on break (istirahat), pill shows "🍽 Ahmad — Istirahat 12m" with orange accent. Staff glancing at kiosk tablet know who's on break without opening app. Unique feature — no competitor does this.
- **Fun facts when idle** — Pill rotates through messages when no breaks active: "Hari ini 12/14 karyawan hadir 🎉", motivational quotes. Makes kiosk feel alive instead of static.

**Defer (v2+):**
- Hard delete employees — destroys audit trail, illegal in many jurisdictions, breaks foreign keys
- CSV with NFC UID column — NFC UIDs are hex strings read from physical cards, admins don't know UIDs until tap
- Supabase Admin API for user creation — requires exposing service_role key (security risk) or Edge Function (over-engineered for 4 outlets)
- Complex animated overlay widgets — memory/battery drain, ANR risk on low-end tablets

### Architecture Approach

The architecture follows a **data-centric enhancement** pattern: minimal UI changes, maximum leverage of existing services. The codebase has no service layer abstraction — screens call Supabase directly via `SupabaseClientFactory.admin.from()`. This pattern continues for v2.0.

**Major components:**

1. **Soft-Archive System** — Extends existing `Employee` model with `isArchived`, `archivedAt`, `archivedBy` fields. Database migration adds nullable columns with defaults (backward-compatible). All queries touching `employees` table audited to add `.eq('is_archived', false)` filter where appropriate. New `ArchivedEmployeesScreen` shows archive history with restore capability. Archive action deletes future `schedule_entries` for the employee.

2. **CSV Import Pipeline** — New `CsvImportService` parses CSV client-side (no server processing needed for 200 employees), validates against `outlets` table to resolve names → UUIDs, shows preview table with per-row validation status, batch-inserts valid rows via `supabase.from('employees').insert(List<Map>)`. Graceful degradation: if batch fails, falls back to individual inserts with error collection.

3. **Live Activity Data Flow** — New `LiveActivityDataService` subscribes to `attendance_logs` INSERT events via Supabase Realtime (push-based, not polling). Maintains in-memory `Map<employeeId, BreakInfo>` of active breaks. Every 30s (via existing `KioskBackgroundService._rotateNotification` timer), builds `OverlayPillState` with break status or fun fact. Pushes to overlay via `FlutterOverlayWindow.shareData()`. Overlay isolate renders received state — no Supabase access in overlay process.

4. **Kepala Gerai Setup** — SQL script only, no app code changes. Script updates `auth.users.raw_app_meta_data` to set `app_role: 'kepala_gerai'` and `managed_outlet_id: '<uuid>'`. Existing `admin_login_screen.dart` already reads these fields and scopes dashboard accordingly.

**Critical constraint:** The overlay runs in a **separate Dart isolate** (`@pragma('vm:entry-point') overlayMain()`) with no access to main app's Supabase client, providers, or services. All data flows through `FlutterOverlayWindow.shareData()` string serialization. This architecture is immutable — the overlay is a dumb renderer, the main app is the data source.

### Critical Pitfalls

Research identified 10 critical pitfalls with specific code-level references and prevention strategies:

1. **Soft-archive breaks existing queries** — 6+ distinct query paths touch `employees` table. Some filter `is_active`, some don't. Adding archive semantics without auditing every query causes phantom employees in reports, schedule assignments to archived employees, NFC scans accepted for archived employees. **Prevention:** Audit every `.from('employees')` call, add `archived_at` timestamp column (not just reuse `is_active`), clean up future `schedule_entries` on archive.

2. **Employee cache serves stale data** — `EmployeeCacheService` has 5-minute TTL. Archived employee can still NFC scan for up to 5 minutes. **Prevention:** Add `is_active` check at scan validation point (`kiosk_scan_screen`), not just at cache time. Show "Karyawan tidak aktif" message.

3. **CSV import creates orphan employees** — Batch insert with invalid `home_outlet_id` (typo in outlet name) fails FK constraint or sets NULL, creating "Belum punya gerai" employees. **Prevention:** Two-pass validation (parse → validate → preview → insert). Fuzzy outlet name matching with confirmation dialog. Never insert without previewing.

4. **CSV encoding corruption** — Excel on Windows exports with Windows-1252 or UTF-8 BOM. Indonesian names generally safe but comma-in-name ("Muhammad, S.Pd") breaks naive parsing. **Prevention:** Use `csv` package (handles quotes/escaping), detect and strip BOM, provide CSV template download.

5. **Service role key exposed in client** — Creating Supabase Auth users programmatically requires service_role key. Embedding in APK = security breach. **Prevention:** Use SQL script in Supabase Dashboard (planned approach). Never ship service_role key in client app.

6. **RLS policy conflicts** — New `kepala_gerai` role needs outlet-scoped policies. Existing queries might be client-side filtered in Dart, not DB-enforced. **Prevention:** Audit RLS policies before deployment, test with actual kepala_gerai user, set `managed_outlet_id` in `raw_app_meta_data` (server-controlled), not `raw_user_meta_data` (user-modifiable).

7. **Overlay memory leak** — Adding Supabase Realtime subscription inside overlay isolate creates second connection that never closes. Timers not disposed. **Prevention:** Zero Supabase initialization in overlay. All realtime subscriptions in main app. Dispose all timers in `overlay_task.dart` dispose method (already done correctly).

8. **OEM battery optimization kills service** — Xiaomi MIUI, Samsung One UI, Oppo ColorOS kill foreground services despite `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. **Prevention:** MIUI detection already exists (`MainActivity.kt`), must be actively called during setup. Add setup guide for OEM-specific whitelisting. Notification is reliable fallback.

9. **Realtime subscription leak** — Creating subscriptions in `KioskBackgroundService.start()` without cleanup in `stop()` leaks connections. **Prevention:** Store `RealtimeChannel?` field, call `_channel?.unsubscribe()` in `stop()`, follow pattern in `admin_employees_screen.dart` line 58-68.

10. **Additive migration breaks inserts** — Adding NOT NULL column without DEFAULT causes existing INSERT statements (from v1.1 kiosks) to fail. **Prevention:** ALL new columns must be NULLABLE or have DEFAULT. Test migration against current app version before deploying.

## Implications for Roadmap

Based on research, the optimal phase structure follows a **foundation-first** approach: start with the data model change that everything depends on, end with the most complex but isolated enhancement.

### Phase 1: Soft-Archive Karyawan + Riwayat

**Rationale:** Foundation phase. Modifies the `Employee` model and database schema that all subsequent features depend on. Small, testable, shippable independently. Addresses Pitfalls 1, 2, 10.

**Delivers:**
- Database migration: `ALTER TABLE employees ADD COLUMN is_archived BOOLEAN DEFAULT false, archived_at TIMESTAMPTZ, archived_by TEXT`
- `Employee` model updated with new fields
- Archive action in `AdminEmployeesScreen` with confirmation dialog
- Archived employees excluded from: active list, schedule assignment, NFC lookup
- New `ArchivedEmployeesScreen` showing archive history
- Restore capability

**Addresses features:**
- Soft-archive with preserved history (table stakes)
- Restore archived employee (table stakes)
- Archived employees excluded from schedules/NFC (table stakes)
- Riwayat Karyawan history page (differentiator)

**Avoids pitfalls:**
- P1: Query audit ensures all `employees` queries handle archive state
- P2: NFC cache validation rejects archived employees immediately
- P10: Migration uses NULLABLE columns, tested against v1.1 kiosk inserts

**Critical success criteria:**
- Archive an employee → disappears from active list within 5 seconds
- Archived employee NFC scan → rejected with clear message
- Attendance report still shows archived employee's historical data
- Schedule grid has no phantom shifts for archived employees

---

### Phase 2: Batch CSV Import

**Rationale:** Builds on Phase 1 — imported employees set `is_archived: false`. Admin tool that doesn't require kiosk changes (admin-only feature). Moderate complexity (parsing + validation). Addresses Pitfalls 3, 4.

**Delivers:**
- `file_picker` + `csv` package added to pubspec.yaml
- New `CsvImportScreen` with file picker → preview table → batch insert flow
- New `CsvImportService` with parsing, validation, outlet name resolution
- Preview table showing per-row validation status
- Batch insert with graceful degradation to individual inserts on conflict
- Result summary: "N berhasil, M gagal" with error details

**Addresses features:**
- CSV import with error reporting (table stakes)
- CSV duplicate detection (table stakes)
- Smart CSV validation with outlet matching (differentiator)

**Avoids pitfalls:**
- P3: Two-pass validation, outlet name → UUID lookup before insert
- P4: `csv` package handles BOM/encoding, provide template download

**Critical success criteria:**
- CSV with 10 employees → preview shows validation status → import succeeds
- CSV with typo'd outlet name → preview shows error, prevents insert
- CSV with duplicate employee → flagged, skipped gracefully
- Excel-exported CSV with Indonesian names → imports correctly

---

### Phase 3: Quick Kepala Gerai SQL Setup

**Rationale:** Independent of all other features. Zero app code changes. Can be developed in parallel with Phase 2. Addresses Pitfalls 5, 6.

**Delivers:**
- SQL script: `scripts/setup_kepala_gerai.sql` with template + comments
- Documentation: step-by-step guide for running script in Supabase Dashboard
- RLS policy audit and verification checklist

**Addresses features:**
- Kepala Gerai quick setup (table stakes)

**Avoids pitfalls:**
- P5: SQL script approach, never exposes service_role key in client
- P6: Script sets `raw_app_meta_data`, RLS policies audited before deployment

**Critical success criteria:**
- Run SQL script → user can log in with kepala_gerai role
- Kepala Gerai sees only their outlet's data (dashboard, employees, reports)
- Existing admin user still has full access
- Kiosk NFC scanning unaffected by auth changes

---

### Phase 4: Persistent Live Activity Pill

**Rationale:** Largest scope but completely isolated from admin tools (Phases 1-3). Touches sensitive overlay/background systems — benefits from earlier phases being stable. Addresses Pitfalls 7, 8, 9.

**Delivers:**
- `OverlayPillState` model extended with `liveIdle` mode, break status fields
- New `LiveActivityDataService` with Supabase Realtime subscription for break detection
- `KioskBackgroundService` integration: rotation timer consults LiveActivityDataService
- `overlay_task.dart` rendering for `liveIdle` mode (break status + fun facts)
- Fun facts content pool (hardcoded + dynamic stats from Supabase)
- Break timer display in overlay (elapsed time calculated locally)

**Addresses features:**
- Live break status on overlay pill (differentiator)
- Fun facts when idle (differentiator)

**Avoids pitfalls:**
- P7: Zero Supabase init in overlay, all data via `shareData()`
- P8: OEM battery optimization guide, heartbeat monitoring
- P9: Realtime channel cleanup in `KioskBackgroundService.stop()`

**Critical success criteria:**
- Employee starts break → overlay shows "Ahmad · Istirahat" within 30s
- No breaks active → overlay cycles fun facts every 30s
- Overlay survives 24+ hours without memory growth
- Foreground service not killed by OEM battery optimization on target tablets

---

### Phase Ordering Rationale

- **Archive first** — Modifies foundational data model. All subsequent queries (CSV import, dashboard) must account for `is_archived` field. Testing archive in isolation prevents cascading issues.
- **CSV second** — Depends on archive field existing (sets `is_archived: false` on import). Admin-only feature, no kiosk impact. Can be tested thoroughly in staging before kiosk rollout.
- **Kepala Gerai third (or parallel with CSV)** — Zero code changes, just SQL + docs. No dependencies. Logical grouping with "admin tools" but can ship anytime.
- **Live Activity last** — Most complex, touches overlay + main process + realtime. No dependency on admin tools. Benefits from admin features (Phases 1-3) being stable and stress-tested in production before touching background service.

**Why NOT parallel development of all phases:** The `Employee` model change in Phase 1 touches 8+ files. Developing CSV import (Phase 2) in parallel creates merge conflicts and testing complexity. Serial development with short phases (1-2 weeks each) is safer for a production system.

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 4 (Live Activity):** Overlay isolate data flow is complex. Needs research into Supabase Realtime reconnection behavior, overlay memory profiling on target hardware, OEM-specific battery optimization patterns. Plan for 2-3 days of prototyping and profiling.

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Archive):** Soft-delete is a standard pattern. Database migration is straightforward. Query auditing is tedious but not complex.
- **Phase 2 (CSV):** CSV parsing + validation + preview UI is well-documented. BambooHR/Homebase patterns are clear references.
- **Phase 3 (Kepala Gerai):** SQL script is trivial. RLS policy patterns are documented in Supabase docs.

**When to use `/gsd-research-phase` command:**
- If Phase 4 reveals unexpected memory behavior during prototyping
- If OEM battery optimization requires platform-specific workarounds
- If Supabase Realtime subscription model proves unreliable on Android

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | Only 2 new packages needed. Existing packages verified in production across 4 outlets. `csv` and `file_picker` are pub.dev top packages with 5000+ likes. No native code changes needed. |
| Features | **HIGH** | All 4 features grounded in codebase analysis. Table stakes vs differentiators derived from BambooHR/Homebase industry patterns. Anti-features list prevents scope creep. |
| Architecture | **HIGH** | Full codebase analysis (47 Dart files, 19K LOC). Integration points verified via line-number references. Overlay isolate constraint is immutable — data flow pattern is forced by `flutter_overlay_window` architecture. |
| Pitfalls | **HIGH** | 10 pitfalls mapped to specific code locations. All pitfalls have concrete prevention strategies and phase assignments. Production incident scenarios grounded in existing constraints (4 outlets, 14 employees, additive migrations only). |

**Overall confidence:** **HIGH**

### Gaps to Address

- **OEM-specific battery optimization** — Research lists MIUI, Samsung, Oppo, Vivo patterns, but real-world reliability depends on *actual deployment tablet models*. Must test Phase 4 on the exact hardware used at the 4 outlets. **Mitigation:** Add requirement during Phase 4 planning to test on 1 production tablet before rollout.

- **Supabase Realtime reconnection on network interruption** — Dashboard already uses realtime successfully, but kiosk tablets may have intermittent WiFi. Break status subscription robustness on reconnect is unverified. **Mitigation:** Phase 4 should include 24-hour stress test with forced WiFi disconnects.

- **CSV template format** — Research assumes standard Excel export, but Indonesian Excel locales might use semicolons instead of commas. **Mitigation:** Phase 2 should include configurable delimiter detection in `csv` package usage.

- **Migration rollback strategy** — Research assumes forward-only migrations (additive), but doesn't specify rollback process if Phase 1 database migration causes production issues. **Mitigation:** Document rollback SQL (`ALTER TABLE DROP COLUMN`) before deploying Phase 1.

- **Archive restore permissions** — Research doesn't specify if Kepala Gerai can restore archived employees or only admins. **Mitigation:** Phase 1 requirements should clarify role-based restore permissions.

## Sources

### Primary (HIGH confidence)
- **Codebase analysis** — 47 Dart files totaling 19K+ LOC: `employee.dart`, `admin_employees_screen.dart`, `overlay_task.dart`, `kiosk_background_service.dart`, `overlay_pill_state.dart`, `admin_login_screen.dart`, `shift_scheduler_screen.dart`, `employee_cache_service.dart`, `sync_service.dart`, `supabase_client.dart`, `MainActivity.kt`, `KioskNotificationHelper.kt`, `pubspec.yaml`
- **Project documentation** — `liveaction.md` (1100-line Live Activity research), `PROJECT.md` (constraints: 4 outlets, 14 employees, production system), `CONCERNS.md` (tech debt, fragile areas), `INTEGRATIONS.md` (auth model, realtime subscriptions)
- **Database schema** — Verified `employees` table has `is_active` boolean, `attendance_logs` has FK to `employees.id`, `schedule_entries` uses employee foreign keys

### Secondary (MEDIUM confidence)
- **Pub.dev packages** — `csv` ^6.0.0, `file_picker` ^8.1.0 versions and capabilities from training data (should verify latest stable versions at implementation time)
- **HR tool patterns** — BambooHR soft-delete, Deputy CSV import, Homebase employee archiving patterns from training data
- **Supabase Auth metadata** — `raw_app_meta_data` vs `raw_user_meta_data` security model from Supabase docs (training data)

### Tertiary (LOW confidence)
- **OEM battery optimization** — MIUI/Samsung/Oppo patterns from training data, needs real-world verification on actual deployment tablets
- **Indonesian CSV locale** — Assumption that Excel exports use commas, but Indonesian locale might use semicolons (needs validation with actual admin CSV exports)

---
*Research completed: 2025-01-14*
*Ready for roadmap: yes*
