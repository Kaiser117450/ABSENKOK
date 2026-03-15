# Codebase Concerns

**Analysis Date:** 2024-12-29

## Tech Debt

**Schedule Balancing Algorithm (Deferred Feature):**
- Issue: Schedule generator uses basic round-robin algorithm; advanced balancing is stubbed out
- Files: `lib/services/schedule_generator.dart:173`
- Impact: Generated schedules may not distribute workload fairly; manual adjustment still needed
- Fix approach: Implement the TODO at line 173 — add workload balancing logic that redistributes shifts when variance between employee work-days exceeds threshold

**Massive Python Fix Script Collection:**
- Issue: 66 Python scripts (`fix_*.py`) in root directory indicate repeated manual code repairs during development
- Files: Root directory contains `fix_admin_dashboard.py`, `fix_outlets_proper*.py` (24 variations), `fix_final*.py` (18 variations), `fix_shimmer*.py`, `fix_snackbar*.py`, etc.
- Impact: Suggests past code quality issues with shimmer widgets, container widgets, outlet screens, and snackbar implementations that required automated fixing
- Fix approach: Delete these scripts after verifying they're no longer needed; add linting rules to prevent similar issues (e.g., enforce const constructors, validate widget patterns)

**Hardcoded Admin Name:**
- Issue: Login screen greeting hardcoded to specific person
- Files: `lib/screens/admin/admin_login_screen.dart:139`
- Impact: Greeting displays "Halo, Akmal 👋" for all admin users — unprofessional for multi-admin deployment
- Fix approach: Remove hardcoded name or fetch from user profile metadata

**Build Logs Committed to Repository:**
- Issue: 6 build log files present in root directory
- Files: `adb_install.log`, `adb_install_utf8.log`, `build.log`, `flutter_01.log`, `flutter_02.log`, `flutter_build.log`
- Impact: Clutters repository with temporary files; `.gitignore` already excludes `*.log` but these were committed before rule was added
- Fix approach: Delete log files and commit removal

**Missing .env.example Template:**
- Issue: `.env` file exists but no `.env.example` template for new developers
- Files: `.env` (exists), `.env.example` (missing)
- Impact: New developers/deployments don't know which environment variables are required
- Fix approach: Create `.env.example` with placeholder values for `SUPABASE_URL` and `SUPABASE_ANON_KEY`

**Debug Print Statements in Production:**
- Issue: 40+ debug/print statements scattered throughout codebase
- Files: `lib/services/sync_service.dart:63,69,80`, `lib/services/kiosk_background_service.dart`, `lib/providers/app_provider.dart:125,127`, and others
- Impact: Console spam in production builds; minor performance overhead
- Fix approach: Replace with proper logging framework or wrap in `kDebugMode` checks

**No README Documentation:**
- Issue: README.md contains only default Flutter template text
- Files: `README.md`
- Impact: No setup instructions, architecture overview, or deployment guide for new team members
- Fix approach: Document app architecture, environment setup, Supabase configuration, and deployment process

## Known Bugs

**Schedule UI Grid Redesign Deferred (REQ-M5-02):**
- Symptoms: Schedule grid not optimized for mobile viewing; known gap from milestone v1.1
- Files: `lib/screens/admin/shift_scheduler_screen.dart`
- Trigger: Mentioned in user's context as deferred feature
- Workaround: Current grid works but may require horizontal scrolling on small screens

**Scroll Synchronization Fragility:**
- Problem: Synchronized scrolling between employee list and schedule grid uses boolean flag
- Files: `lib/screens/admin/shift_scheduler_screen.dart:55,71-86`
- Cause: Manual sync with `_isSyncing` flag to prevent infinite loop — can desync if widgets rebuild during scroll
- Improvement path: Use `ScrollController.position.pixels` listener with debouncing instead of jumpTo

## Security Considerations

**Environment Variables in .env File:**
- Risk: `.env` file contains `SUPABASE_URL` and `SUPABASE_ANON_KEY` — must never be committed
- Files: `lib/main.dart:54,60-61`
- Current mitigation: `.gitignore` excludes `.env` files
- Recommendations: Verify `.env` is NOT in git history; add pre-commit hook to block `.env` commits; document secret rotation procedure

**Anon Key in Kiosk Mode:**
- Risk: Kiosks use Supabase anon key without per-device JWT
- Files: `lib/core/supabase_client.dart:11-13`
- Current mitigation: Password verification happens server-side via RPC `verify_kiosk_password`; outlet identity stored in SharedPreferences; RLS policies enforce outlet-scoped access
- Recommendations: Acceptable for kiosk use case where device is physically secured; ensure RLS policies are tested

**No Rate Limiting on Auth Endpoints:**
- Risk: Admin login has no client-side rate limiting
- Files: `lib/screens/admin/admin_login_screen.dart:31-111`
- Current mitigation: 15-second timeout on auth requests
- Recommendations: Add exponential backoff after failed login attempts; rely on Supabase built-in rate limiting

**Location Data Best-Effort Only:**
- Risk: GPS coordinates captured with 1-second timeout; can be null
- Files: `lib/screens/kiosk/kiosk_scan_screen.dart:144-148`
- Current mitigation: Lat/lng are nullable; attendance logs still created without GPS
- Recommendations: Acceptable trade-off for kiosk use case (attendance must succeed even if GPS fails)

**Sensitive Error Details Exposed:**
- Risk: Admin login shows full error messages including stack traces
- Files: `lib/screens/admin/admin_login_screen.dart:104-106`
- Current mitigation: Only shown in debug context
- Recommendations: Remove stack trace exposure in production builds; wrap in `kDebugMode` check

**SharedPreferences for Session Storage:**
- Risk: Kiosk session stored in SharedPreferences (not encrypted)
- Files: `lib/providers/app_provider.dart:90`
- Current mitigation: Comment notes this replaced SecureStorage to avoid ANR; session only contains `outlet_id`, `outlet_name`, `device_id` — no passwords
- Recommendations: Acceptable — session data is not sensitive; physical kiosk security is primary defense

## Performance Bottlenecks

**24-Hour Attendance Query Window:**
- Problem: Dashboard loads all attendance logs from past 24 hours (covers overnight shifts)
- Files: `lib/screens/admin/admin_dashboard_screen.dart:117-134`
- Cause: Query includes 24-hour lookback with 200-record limit; can be slow with many scans
- Improvement path: Add pagination; cache dashboard stats; index `scanned_at` column in Supabase

**Real-time Subscription Overhead:**
- Problem: Dashboard subscribes to attendance_logs and employees tables; rebuilds on every insert
- Files: `lib/screens/admin/admin_dashboard_screen.dart:37,44`
- Cause: Realtime channels trigger full reload on any change
- Improvement path: Debounce realtime updates; only reload affected rows instead of full list

**Employee Cache TTL Too Short:**
- Problem: NFC employee cache expires after 5 minutes; refetches frequently
- Files: `lib/services/employee_cache_service.dart:15`
- Cause: Conservative TTL to detect when employee changes outlets
- Improvement path: Increase TTL to 15 minutes or use Supabase realtime to invalidate cache when employee records change

**Backup Mode Cache 5 Hour TTL:**
- Problem: Backup mode persists for 5 hours; stale if employee changes outlet mid-day
- Files: `lib/services/employee_cache_service.dart:16`
- Cause: Long TTL to avoid repeated backup confirmations
- Improvement path: Add manual "End Backup" button; allow admin to force-clear backup mode

**No List Virtualization:**
- Problem: Dashboard renders all logs (up to 200) without ListView.builder virtualization
- Files: `lib/screens/admin/admin_dashboard_screen.dart`
- Cause: List is built all at once; no lazy loading
- Improvement path: Already using ListView — verify it's using `.builder()` for large lists

**Synchronous Scroll Sync:**
- Problem: Scroll controllers use `jumpTo` which can cause jank
- Files: `lib/screens/admin/shift_scheduler_screen.dart:74,82`
- Cause: Immediate jump instead of smooth animation
- Improvement path: Use `animateTo` with short duration or implement CustomScrollView with single controller

**Background Service Polling:**
- Problem: Overlay activation polls every 120ms for up to 1600ms
- Files: `lib/services/kiosk_background_service.dart:23-24`
- Cause: Checking if overlay window is ready
- Improvement path: Acceptable for one-time activation; not a continuous poll

## Fragile Areas

**NFC Service Platform-Specific UID Extraction:**
- Files: `lib/services/nfc_service.dart:40-118`
- Why fragile: Tries 8 different NFC technology types in sequence; depends on platform-specific identifiers
- Safe modification: Always test with multiple card types (e-KTP, bank cards, e-Toll) when changing UID extraction logic
- Test coverage: No unit tests for NFC service

**Foreground Service Notification Management:**
- Files: `lib/services/kiosk_background_service.dart`
- Why fragile: Manages 3 different notification types (foreground service, custom pill, heads-up scan); Android version-specific behavior
- Safe modification: Test on Android 13+ (needs POST_NOTIFICATIONS permission) and Android 10-12 (no permission required)
- Test coverage: No automated tests for notification display

**SQLite Migration Logic:**
- Files: `lib/services/sqlite_service.dart:58-88`
- Why fragile: Recreates table on schema changes; migrates only 'pending' and 'failed' logs
- Safe modification: Always verify migration doesn't lose unsynced logs; test upgrade from all previous versions (v1→v5)
- Test coverage: No migration tests

**Scroll Synchronization State:**
- Files: `lib/screens/admin/shift_scheduler_screen.dart:71-86`
- Why fragile: Boolean flag prevents infinite loop; can desync if controllers rebuild
- Safe modification: Always test scroll in both directions; verify no janky behavior on fast scrolling
- Test coverage: No scroll tests

**Kiosk Session Restoration:**
- Files: `lib/providers/app_provider.dart:87-112`
- Why fragile: Catches all exceptions to prevent splash screen hang; clears corrupt session data silently
- Safe modification: Never throw in `loadSession()`; always call `forceUnblockLoading()` safety-net
- Test coverage: No session restoration tests

**Admin Role Detection:**
- Files: `lib/screens/admin/admin_login_screen.dart:61-74`
- Why fragile: Checks both `userMetadata` and `appMetadata` for `app_role`; different Supabase Auth versions store role in different locations
- Safe modification: Always test with both admin and kepala_gerai roles; verify RLS policies match role checks
- Test coverage: No auth tests

## Scaling Limits

**200-Log Dashboard Limit:**
- Current capacity: Dashboard shows max 200 logs per day
- Limit: With 4 outlets × 10 employees × 4 scans/day = 160 logs/day (under limit); breaks if expanding to 10+ outlets
- Scaling path: Add pagination; filter by outlet; lazy load older logs

**Sync Service Batch Size:**
- Current capacity: Syncs all pending logs in parallel via `Future.wait()`
- Limit: `AppConstants.syncBatchSize = 50` defined but not used; all pending logs sync at once
- Scaling path: Implement batch processing; sync in chunks of 50 to avoid memory issues with 1000+ pending logs

**Schedule Generator Complexity:**
- Current capacity: Generates schedules for monthly periods with all employees
- Limit: O(days × shifts × employees²) — becomes slow with 50+ employees or 90-day periods
- Scaling path: Memoize availability checks; pre-filter employees by home_outlet_id

**In-Memory Employee Cache:**
- Current capacity: Caches all NFC UID lookups in memory
- Limit: No max size; could grow unbounded with 1000+ unique scans
- Scaling path: Implement LRU eviction; cap cache at 500 entries

**Realtime Subscriptions:**
- Current capacity: Dashboard subscribes to 2 realtime channels
- Limit: Supabase free tier allows 200 concurrent connections; each open dashboard = 2 connections
- Scaling path: Unsubscribe when dashboard not visible; implement connection pooling

## Dependencies at Risk

**flutter_overlay_window (v0.5.0):**
- Risk: Unmaintained package; last update 8 months ago; limited Android OEM support
- Impact: Overlay pill may not work on Xiaomi/Oppo/Vivo devices with aggressive background restrictions
- Migration plan: Fallback to notification-only mode if overlay fails; acceptable since custom notification is primary UI

**nfc_manager (v3.5.0):**
- Risk: Platform-specific NFC APIs change frequently across Android versions
- Impact: NFC scanning could break on new Android releases
- Migration plan: Test on Android 15 beta; consider switching to platform channels for direct NFC control

**supabase_flutter (v2.8.4):**
- Risk: Rapid version updates; breaking changes between minor versions
- Impact: Auth flow, realtime, or RLS behavior changes
- Migration plan: Pin to current version; test thoroughly before upgrading; monitor Supabase changelog

## Missing Critical Features

**No Offline Dashboard:**
- Problem: Admin dashboard requires internet; cannot view cached attendance data offline
- Blocks: Reviewing logs during network outages
- Priority: Medium — kiosk has offline queue; admin can wait for connectivity

**No Export to Excel:**
- Problem: PDF export only; many users prefer Excel for further analysis
- Blocks: Importing attendance data into payroll systems
- Priority: Medium — PDF is readable but not editable

**No Audit Log:**
- Problem: No tracking of who edited which records (manual attendance, schedule changes)
- Blocks: Accountability for data changes
- Priority: High — needed for production system integrity

**No Shift Swap Requests:**
- Problem: Employees cannot request shift swaps through app; must contact admin manually
- Blocks: Self-service schedule management
- Priority: Low — acceptable for v1.1; defer to v1.2+

**No Push Notifications:**
- Problem: Admins don't get notified of time-off requests, sakit/izin submissions
- Blocks: Timely approval workflow
- Priority: Medium — admins must manually check dashboard

## Test Coverage Gaps

**NFC Service:**
- What's not tested: UID extraction logic across 8 card types
- Files: `lib/services/nfc_service.dart`
- Risk: Breaking change could prevent card reading in production
- Priority: High — core business function

**Sync Service:**
- What's not tested: Duplicate log handling, network failure retry, batch sync
- Files: `lib/services/sync_service.dart`
- Risk: Lost attendance logs if sync fails silently
- Priority: High — data integrity critical

**SQLite Migrations:**
- What's not tested: Schema upgrades from v1→v2→v3→v4→v5
- Files: `lib/services/sqlite_service.dart:58-88`
- Risk: Data loss during app update
- Priority: High — migration bugs only surface in production

**Schedule Generator:**
- What's not tested: Fairness algorithm, understaffing warnings, time-off integration
- Files: `lib/services/schedule_generator.dart`
- Risk: Unbalanced schedules or OPEN slots not detected
- Priority: Medium — admin reviews before publishing

**Kiosk Session Restore:**
- What's not tested: Corrupt session data recovery, SharedPreferences failure
- Files: `lib/providers/app_provider.dart:87-112`
- Risk: App stuck on splash screen if session restore throws
- Priority: High — blocks app startup

**Admin Auth Flow:**
- What's not tested: Role detection (admin vs kepala_gerai), RLS policy enforcement
- Files: `lib/screens/admin/admin_login_screen.dart:61-90`
- Risk: Unauthorized access if role check fails
- Priority: High — security-critical

**Employee Cache Race Conditions:**
- What's not tested: Concurrent cache access, lock contention
- Files: `lib/services/employee_cache_service.dart:25-42`
- Risk: Cache corruption with simultaneous NFC scans
- Priority: Medium — mutex implemented but not stress-tested

**PDF Generation:**
- What's not tested: Schedule rendering with OPEN slots, multi-page overflow, Indonesian characters
- Files: `lib/services/pdf_service.dart`
- Risk: Malformed PDFs or crashes with edge-case data
- Priority: Low — visual bugs, not data loss

---

*Concerns audit: 2024-12-29*
