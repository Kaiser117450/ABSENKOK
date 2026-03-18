# Pitfalls Research

**Domain:** Smart Attendance + Admin Dashboard features added to existing Flutter NFC kiosk app
**Researched:** 2026-03-18
**Confidence:** HIGH (based on project history, codebase analysis, and verified external sources)

## Critical Pitfalls

### Pitfall 1: Chart Library Memory Leak in 24/7 Kiosk

**What goes wrong:**
Adding chart widgets (fl_chart, syncfusion_flutter_charts, or similar) to the admin dashboard causes progressive memory growth. The kiosk runs 24/7 -- every time an admin opens the dashboard, chart widgets allocate paint objects, animation controllers, and data buffers. If the admin screen is navigated to/from repeatedly, or if charts auto-refresh with live data, memory accumulates until the Android system kills the app. Syncfusion's SfCartesianChart has a documented memory leak when charts are rebuilt frequently.

**Why it happens:**
Chart libraries create complex render objects with animation controllers, gradient shaders, and cached paths. In a normal app (opened for minutes, then closed), this is harmless. In a 24/7 kiosk with GoRouter navigation, widgets may be created and disposed hundreds of times per day. Many chart libraries do not fully release GPU-side resources on dispose. Flutter itself has a known graphics memory leak on Android with Impeller enabled for graphically heavy widgets (issue #161861).

**How to avoid:**
- Use `fl_chart` (lightweight, pure Dart Canvas, no native dependencies) instead of Syncfusion or graphic_flutter.
- Wrap chart widgets in `AutomaticKeepAliveClientMixin` within the admin shell to REUSE instead of recreate on each navigation.
- Disable Impeller on Android (`--no-enable-impeller` flag) if using Flutter 3.22+ -- Skia is more stable for long-running apps.
- Set `swapAnimationDuration: Duration.zero` in fl_chart after the first render to avoid animation controller re-creation.
- Add a periodic memory check -- log heap size every 30 minutes to detect gradual growth in production.
- Limit data points displayed: show last 7 days only on charts, not all historical data.

**Warning signs:**
- App restarts itself after several hours of admin use.
- Android logcat shows `GC_FOR_ALLOC` entries increasing over time.
- Dashboard screens become sluggish after the tablet has been running for days.

**Phase to address:**
Chart/Dashboard implementation phase. Must verify memory stability with a 4-hour stress test (navigate to dashboard 100+ times) before shipping.

---

### Pitfall 2: Supabase Admin User Creation Exposes service_role Key

**What goes wrong:**
The "Kepala Gerai onboarding via app" feature requires creating Supabase Auth users programmatically. The obvious approach is `supabase.auth.admin.createUser()` -- but this requires the `service_role` key. Embedding this key in the Flutter APK means anyone who decompiles the APK (trivial with `apktool`) gets superuser access to the entire Supabase project -- bypassing all RLS, reading/deleting all data across all 4 outlets.

**Why it happens:**
Supabase's Dart SDK makes admin methods look easy to call from client code. The `admin` namespace is right there on the client. Developers building internal tools (not public apps) often think "it's only used by our admins, so it's safe." But the APK is distributed to 4+ tablets in restaurant outlets -- any employee or visitor could extract it.

**How to avoid:**
- Create a Supabase Edge Function (`create-kepala-gerai`) that holds the `service_role` key server-side.
- The Edge Function accepts: email, outlet_id, role. It creates the user with `supabase.auth.admin.createUser()`, sets `app_role` in metadata, and returns credentials.
- Call from Flutter via `Supabase.instance.client.functions.invoke('create-kepala-gerai', body: {...})`.
- The Edge Function must validate: (a) caller is authenticated, (b) caller has `app_role: admin` in their JWT, (c) rate limit (max 5 creations per hour).
- NEVER put `SUPABASE_SERVICE_ROLE_KEY` in `.env` of the Flutter app, even for "development."

**Warning signs:**
- Any import of `serviceRoleKey` or `service_role` in Dart files.
- Direct calls to `supabase.auth.admin.*` anywhere in the Flutter codebase.
- The `.env` file containing more than `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

**Phase to address:**
Kepala Gerai onboarding phase. The Edge Function must be built and deployed BEFORE any client-side user creation code. This is a hard dependency.

---

### Pitfall 3: Push Notifications Conflict with Existing 3-Tier Notification System

**What goes wrong:**
Adding FCM push notifications (for "missing clock-out" alerts) into an app that already has 3 notification layers (MethodChannel custom RemoteViews ID=300, flutter_local_notifications fallback ID=300, flutter_overlay_window pill) causes: duplicate notifications, notification ID collisions, channel conflicts, and the FCM SDK auto-displaying notifications that flutter_local_notifications also tries to display.

**Why it happens:**
FCM on Android automatically displays notifications when the app is in the background -- you cannot suppress this with firebase_messaging alone. If the app also uses flutter_local_notifications (which this app does as fallback), and both try to show a notification for the same event, the user sees duplicates. The existing system uses notification ID=300 for the kiosk notification -- if FCM accidentally uses the same channel or ID range, it can dismiss the kiosk notification.

**How to avoid:**
- Use FCM **data-only messages** (no `notification` payload, only `data` payload). This prevents Android from auto-displaying notifications and gives full control.
- Reserve notification ID ranges: 300 = kiosk live activity (existing), 101 = scan alert (existing), 400-499 = push notifications (new). Document these in `constants.dart`.
- Create a dedicated notification channel `absensi_enakko_push` (separate from existing `absensi_enakko_pill` and `absensi_enakko_kiosk_scan` channels).
- Handle all FCM messages in `onMessage` (foreground) and `onBackgroundMessage` (background) handlers -- manually create local notifications via flutter_local_notifications with reserved ID range.
- Test: send a push notification while the kiosk is showing its live activity notification. Verify neither is dismissed or replaced.
- Do NOT add `awesome_notifications` -- it is explicitly incompatible with `flutter_local_notifications`.

**Warning signs:**
- Kiosk live activity notification (ID=300) disappears when a push notification arrives.
- Users see the same alert twice.
- `firebase_messaging` auto-displays a notification AND your handler creates another one.

**Phase to address:**
Push notification phase. Must be built AFTER the NFC double-scan fix phase (don't add complexity to the notification stack while fixing existing bugs).

---

### Pitfall 4: Smart Attendance Algorithm Runs on Main Isolate, Blocks NFC Scan

**What goes wrong:**
The smart attendance pattern detection algorithm needs to analyze historical attendance logs (89+ and growing) per employee to compute "usual check-in time," detect anomalies, and calculate streaks. If this computation runs synchronously on the main isolate, it blocks the NFC scan handler. An employee taps their NFC card and waits 3-5 seconds instead of <2 seconds because the pattern algorithm is crunching data.

**Why it happens:**
With 14 employees and 89 logs, the data is small and the algorithm feels instant in development. But: (a) logs grow daily (89 now, 500+ in 3 months, 2000+ in a year), (b) the algorithm might be triggered per-scan to show "you're early/late" feedback, (c) Dart's single-threaded model means any CPU work >16ms causes frame drops and NFC handler delays.

**How to avoid:**
- Run ALL pattern detection in a separate Dart `Isolate` using `Isolate.run()` or `compute()`.
- Pre-compute patterns on a schedule (once per hour via a timer, or on admin dashboard open) -- NOT on every NFC scan.
- Store computed patterns in SQLite (`employee_patterns` table with fields: `employee_id`, `usual_checkin_time`, `streak_count`, `computed_at`). The NFC scan handler just reads the pre-computed result.
- Set a hard budget: NFC scan -> attendance log -> response must complete in <500ms. Pattern display is optional and loads asynchronously after the scan confirmation screen appears.
- For the "you're late" notification: compare `scanned_at` against pre-computed `usual_checkin_time` -- a simple subtraction, not a re-computation.

**Warning signs:**
- NFC scan response time increases from <1s to >2s.
- `FlutterJank` or frame drops visible in DevTools Performance tab during scan.
- `attendance_logs` table grows past 500 rows and the pattern algorithm hasn't been benchmarked.

**Phase to address:**
Smart attendance algorithm phase. Pattern computation must be an isolated background service from day one -- never prototype it as synchronous code with "we'll optimize later."

---

### Pitfall 5: Gamification Streak Breaks Due to Noon Rule Misalignment

**What goes wrong:**
The attendance streak feature counts consecutive days an employee clocked in. But this app uses the "noon rule" for cross-day shift handling -- a shift starting at 22:00 and ending at 06:00 groups both scans under the same logical day. If the streak calculator uses calendar dates naively (midnight-to-midnight), a night-shift employee who scans at 22:05 on Monday and 06:10 on Tuesday has scanned on two calendar days but it's one shift. The streak logic must align with the existing noon rule, or streaks will be wrong.

**Why it happens:**
Streak logic is "obviously simple" -- check if there's an attendance log for each consecutive date. But the app's definition of "a day" is not midnight-to-midnight; it's noon-to-noon (the established cross-day grouping rule). A developer who doesn't deeply understand the noon rule will write streak logic that breaks for all night-shift workers across all 4 outlets.

**How to avoid:**
- Reuse the existing cross-day grouping logic (noon rule) as the source of truth for "which day did this attendance belong to."
- The streak calculator must operate on **logical attendance days** (noon-to-noon), not calendar dates.
- Write streak tests specifically for: night shift (22:00-06:00), shift spanning midnight, employee who only has `masuk` but no `pulang` (still counts as present), weekend/off-day gaps (if outlets are closed, streaks should not break).
- Store the computed streak in SQLite, not just in memory. Kiosks reboot -- the streak must survive.
- Grace period: if an employee scans at 12:05 (5 minutes after noon boundary), this should still count for the previous logical day. Use a 30-minute grace window.

**Warning signs:**
- Night-shift employees always show streak=1 despite working every day.
- Streaks reset on app restart.
- Streaks differ between what the employee sees on scan and what the admin sees on the dashboard.

**Phase to address:**
Gamification streak phase. Must be built AFTER the smart pattern algorithm (which also needs noon-rule alignment), and share the same logical-day computation function.

---

### Pitfall 6: Supabase RLS Policies Block New Dashboard Queries

**What goes wrong:**
The new dashboard features (attendance rate card, cross-outlet comparison, charts) need aggregate queries across multiple outlets and employees. Existing RLS policies were designed for single-outlet kiosk access and per-employee queries. The new dashboard queries fail silently -- returning empty results instead of errors -- because RLS blocks the admin from reading cross-outlet data they should have access to.

**Why it happens:**
Supabase RLS returns empty results (not errors) when a policy blocks access. A developer writes a `SELECT` that works perfectly in the Supabase SQL editor (which bypasses RLS) but returns no data from the Flutter app. They spend hours debugging the Dart code when the issue is a missing RLS policy. This is the single most common Supabase debugging pitfall.

**How to avoid:**
- Before writing ANY new dashboard query in Dart, write and test the RLS policy in Supabase SQL editor first.
- Use the established pattern: `DROP POLICY IF EXISTS "policy_name" ON table; CREATE POLICY "policy_name" ON table FOR SELECT USING (...)`.
- For admin dashboard: create a policy that grants `SELECT` on `attendance_logs` where `auth.jwt() -> 'app_metadata' ->> 'app_role' IN ('admin', 'kepala_gerai')`.
- For kepala_gerai cross-outlet comparison: the policy must scope to the outlets they manage.
- Test every query as both `admin` and `kepala_gerai` roles -- not just in the SQL editor.
- Add a debug helper: if a query returns 0 rows unexpectedly, log `Supabase.instance.client.auth.currentUser?.appMetadata` to verify the JWT contains the expected role.

**Warning signs:**
- Dashboard shows "No data" despite having 89+ attendance logs in the database.
- A query works in Supabase SQL editor but returns empty from Flutter.
- New features work for the main admin but not for kepala_gerai accounts.

**Phase to address:**
Every phase that adds new Supabase queries. RLS policy creation should be the FIRST task in any phase that touches the database -- before writing Dart code.

---

### Pitfall 7: Firebase/FCM Adds Kotlin 2.x Dependency That Breaks nfc_manager

**What goes wrong:**
Adding `firebase_messaging` (FCM) to the project pulls in `firebase_core`, which may require a newer Kotlin version or Android Gradle Plugin version than the project supports. The project is locked to Kotlin 1.9.25 because nfc_manager breaks on Kotlin 2.x. If a developer runs `flutter pub upgrade` or adds firebase packages without pinning versions, the build breaks with Kotlin compilation errors.

**Why it happens:**
Firebase Flutter plugins are on an aggressive update cycle. The `firebase_core` plugin and its transitive dependencies may require Kotlin 2.0+. AGP version conflicts are also common -- the project uses AGP 8.11.1, and Firebase may pull in dependencies compiled with a different AGP.

**How to avoid:**
- Before adding ANY Firebase package, check its `android/build.gradle` for Kotlin version requirements.
- Pin specific versions in `pubspec.yaml` -- do NOT use `^` for Firebase packages. Example: `firebase_core: 3.3.0` (not `^3.3.0`).
- **Strong alternative: skip FCM entirely.** Use Supabase Realtime + flutter_local_notifications for push-like behavior. The kiosk is always online (or offline-first with sync). When the sync service detects a missing clock-out, it triggers a local notification immediately -- no FCM server round-trip needed.
- If FCM is required for admin's personal phone (not kiosk tablet), isolate it to a separate admin companion app.
- After adding Firebase, immediately run `./gradlew dependencies` and verify no Kotlin 2.x transitive dependency was pulled in.

**Warning signs:**
- Build errors mentioning `kotlin-stdlib-jdk8` version conflicts.
- `nfc_manager` stops compiling after adding Firebase packages.
- Gradle sync takes significantly longer after adding Firebase (many transitive dependencies).

**Phase to address:**
Push notification phase. Evaluate Supabase Realtime vs FCM BEFORE committing to FCM. If FCM is chosen, version pinning and Kotlin compatibility check must be the very first step.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Computing streaks on every NFC scan | Simple, always fresh data | Blocks NFC handler as logs grow past 500 | Never -- pre-compute on schedule |
| Storing patterns in AppProvider memory only | Fast, no schema changes | Lost on app restart (24/7 kiosk reboots regularly) | Never -- persist in SQLite |
| Using `service_role` key in Flutter .env | Quick user creation works | Full database compromise possible via APK decompile | Never |
| Adding charts without dispose stress-testing | Dashboard looks great in demo | Memory leak kills kiosk after days of running | Only if 4-hour stress test passes |
| Skipping RLS for new dashboard queries | Queries return data immediately | Data leaks between outlets/roles in production | Never in production |
| Using FCM notification payload (not data-only) | Automatic display, less code | Duplicate notifications with existing 3-tier system | Never in this app |
| Inline pattern computation in widget build() | Easy to prototype | Jank, frame drops, NFC delays | Only in throwaway prototype that is never merged |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Supabase Auth admin.createUser() | Calling from Flutter client with service_role key | Create Edge Function, call via functions.invoke() |
| Supabase RLS + new dashboard queries | Writing queries that work in SQL editor but fail in app (empty results, no error) | Write RLS policies FIRST, test with actual user JWT from Flutter |
| Firebase Messaging + flutter_local_notifications | Both showing same notification (duplicates) because FCM auto-displays in background | Use data-only FCM messages, handle display manually via flutter_local_notifications |
| Firebase + Kotlin 1.9.25 | Transitive dependency pulls Kotlin 2.x, breaks nfc_manager build | Pin Firebase versions explicitly, verify gradle dependencies after adding |
| fl_chart + GoRouter navigation | Chart widgets created/destroyed on every navigation, leaking AnimationControllers | Use AutomaticKeepAliveClientMixin or cache chart data in Riverpod provider |
| Supabase Realtime for live dashboard | Opening too many Realtime channels (one per widget/chart) hits connection limits | Single channel with multiplexed events, or use periodic polling for dashboard data |
| SharedPreferences for streak data | Writing complex nested JSON objects to SharedPrefs | Use SQLite for structured data (streaks, patterns). SharedPrefs only for simple flags/booleans |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Pattern algorithm on main isolate | NFC scan latency >2s, UI jank during scan | Use Isolate.run() or compute() | >200 attendance logs |
| Full history chart rendering | Dashboard takes 3s+ to load, frame drops | Limit to 7-30 days of data, paginate older data | >500 attendance logs |
| Supabase query without index for cross-outlet report | Report generation takes 5-10s | Add composite index on attendance_logs(scan_outlet_id, scanned_at) | >1000 logs per outlet |
| Rebuilding chart widgets on every setState | Memory grows linearly, frames drop progressively | Separate chart data from UI state, use Riverpod select() to minimize rebuilds | After 50+ dashboard visits in a session |
| Storing all employee photos in memory | OOM crash on tablets with 2GB RAM | Use cached_network_image with maxCacheWidth constraint | >50 employees with photo_url set |
| Supabase Realtime subscription leak | Connection limit hit, dashboard stops updating | Dispose subscriptions in widget dispose(), use ref.onDispose in Riverpod | After navigating admin screens 20+ times |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| service_role key in Flutter APK .env | Complete database takeover -- read/delete all data, bypass all RLS | Edge Function for all admin operations, anon key only in APK |
| Kepala Gerai credentials displayed in plain text on screen | Other employees/customers see login credentials on tablet | Show credentials once in a modal, copy-to-clipboard only, never persist in UI state |
| Auto-generated passwords too weak | Brute-force login to admin panel | Generate 12+ char passwords with mixed case, digits, symbols |
| Push notification content leaks employee data | Lock screen shows "Ahmad terlambat 15 menit" visible to anyone | Use generic notification text ("Ada notifikasi baru"), details only visible inside authenticated app |
| Edge Function without caller validation | Anyone who discovers function name can create admin users | Verify JWT exists AND app_role = admin in Edge Function before processing |
| Dashboard routes accessible in kiosk mode | Employee at kiosk tablet navigates to admin dashboard | GoRouter guard: dashboard routes require isAnyAdmin AND valid authenticated session |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Showing streak count on NFC scan result screen via live computation | Adds 1-2s delay to scan feedback | Pre-compute streak, display instantly from SQLite cache. Scan confirmation must remain <500ms |
| Chart tooltips using hover interaction on tablet | Fingers are imprecise on 10" tablet, tooltips flicker and misfire | Use tap-to-select data points, show details in a panel below the chart |
| Attendance rate as raw percentage | "87.5% attendance" is abstract and meaningless to kepala gerai | Show "Hadir 14/16 hari" -- concrete numbers they can act on |
| Cross-outlet comparison as a data table only | Walls of numbers, hard to visually compare 4 outlets | Use horizontal bar chart -- outlets ranked visually side by side |
| Gamification streak as just a number | "Streak: 12" without context feels pointless | "12 hari berturut-turut tepat waktu!" with visual badge/emoji reward |
| One push notification per missing employee clock-out | Admin gets 14 separate notifications at end of day | Batch into one per outlet: "3 karyawan belum pulang di Outlet A" |

## "Looks Done But Isn't" Checklist

- [ ] **Chart dashboard:** Often missing dispose of AnimationController -- verify heap doesn't grow after 50+ dashboard visits via DevTools Memory tab
- [ ] **Streak calculation:** Often missing noon-rule alignment -- verify night-shift employee (22:00-06:00 shift) gets correct consecutive streak
- [ ] **User creation via Edge Function:** Often missing error handling for duplicate email -- verify graceful error message when creating user with existing email
- [ ] **Push notifications:** Often missing notification ID range separation -- verify kiosk notification (ID=300) remains visible when push notification arrives
- [ ] **Attendance rate card:** Often missing sakit/izin day handling -- verify sick/permit days don't count against attendance rate percentage
- [ ] **Cross-outlet comparison:** Often missing RLS policy for kepala_gerai role -- verify kepala_gerai sees only their managed outlet(s) data
- [ ] **Smart pattern algorithm:** Often missing new employee handling (0 historical logs) -- verify graceful "data belum cukup" empty state
- [ ] **Overtime tracking:** Often missing break time deduction -- verify overtime = (pulang - masuk - break_duration), not just (pulang - masuk)
- [ ] **Gamification badge display:** Often missing offline-first -- verify streak badge renders correctly from SQLite when device is offline
- [ ] **Edge Function deployment:** Often missing CORS configuration -- verify Flutter app can invoke Edge Function from the kiosk tablet network

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| service_role key leaked in APK | HIGH | Rotate all Supabase keys immediately, redeploy all 4 tablets with new anon key, audit database for unauthorized access, check Supabase logs |
| Chart memory leak discovered in production | MEDIUM | Disable chart feature via feature flag in SharedPrefs, push OTA update with dispose fix, restart all tablets |
| Streak calculation wrong for night shifts | LOW | Recompute all streaks from attendance_logs using corrected noon-rule algorithm, update SQLite cache -- no data loss |
| FCM dependency breaks nfc_manager build | MEDIUM | Revert firebase packages from pubspec.yaml, fall back to Supabase Realtime + local notification approach, re-pin all dependency versions |
| RLS blocks dashboard queries silently | LOW | Add missing policies via Supabase SQL editor -- no app update needed, immediate fix |
| Push notification duplicates | LOW | Switch to data-only FCM messages, update onBackgroundMessage handler, redeploy |
| Pattern algorithm blocking NFC scans | MEDIUM | Move computation to Isolate, add 200ms timeout wrapper, store pre-computed results in SQLite, deploy update to all tablets |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Chart memory leak | Dashboard/Chart implementation phase | 4-hour stress test: navigate dashboard 100+ times, heap size stays within 20% of baseline |
| service_role key exposure | Kepala Gerai onboarding phase | `grep -r "service_role" lib/` returns zero hits. Edge Function deployed and tested |
| Notification system conflicts | Push notification phase | Send push while kiosk notification (ID=300) is active -- both remain visible simultaneously |
| Pattern algorithm blocks NFC | Smart attendance algorithm phase | Benchmark: NFC scan completes in <500ms with 2000 synthetic logs in attendance_logs table |
| Streak noon-rule misalignment | Gamification streak phase | Unit test: night-shift employee with 7 consecutive 22:00-06:00 shifts shows streak = 7 |
| RLS blocks dashboard queries | Every phase adding new Supabase queries | Test each new query as admin role AND kepala_gerai role from actual Flutter app (not SQL editor) |
| Firebase breaks Kotlin 1.9.25 | Push notification phase | `./gradlew dependencies` output contains zero Kotlin 2.x artifacts after adding Firebase |
| Overtime missing break deduction | Overtime tracking phase | Employee with 1-hour break: computed overtime = total_hours - 1hr_break - scheduled_shift_duration |

## Sources

- [Flutter Impeller graphics memory leak (issue #161861)](https://github.com/flutter/flutter/issues/161861)
- [Syncfusion chart memory leak on rebuild](https://www.syncfusion.com/forums/173730/memory-leak-on-rebuilding-charts)
- [Supabase Auth rate limits documentation](https://supabase.com/docs/guides/auth/rate-limits)
- [Supabase admin.createUser() -- must use server-side](https://supabase.com/docs/reference/dart/auth-admin-createuser)
- [Supabase API keys and service_role security](https://supabase.com/docs/guides/api/api-keys)
- [FCM foreground notification blocking behavior](https://firebase.flutter.dev/docs/messaging/notifications/)
- [awesome_notifications incompatible with flutter_local_notifications](https://pub.dev/packages/awesome_notifications)
- [Timezone edge cases in gamification streaks](https://trophy.so/blog/handling-time-zones-gamification)
- [Flutter memory management and DevTools](https://docs.flutter.dev/tools/devtools/memory)
- [Flutter performance best practices](https://docs.flutter.dev/perf/best-practices)
- [Supabase Edge Functions invocation from Flutter](https://supabase.com/docs/reference/dart/functions-invoke)
- Project CLAUDE.md: architecture rules, ANR history, notification system, Kotlin 1.9.25 constraint
- Codebase analysis: AppProvider state shape, existing notification IDs, noon rule pattern, service file structure

---
*Pitfalls research for: Smart Attendance + Admin Dashboard additions to Flutter NFC Kiosk App*
*Researched: 2026-03-18*
