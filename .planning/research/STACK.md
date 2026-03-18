# Stack Research — v4.0 Smart Attendance + Admin Dashboard

**Project:** Absensi Enakko (ABSENKOK)
**Researched:** 2026-03-18
**Confidence:** MEDIUM-HIGH
**Scope:** NEW additions only for smart attendance patterns, charts/dashboard, gamification, push notifications, Supabase Auth user management, and cross-outlet reporting.

---

## Recommended Stack Additions

### Charts & Data Visualization

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `fl_chart` | ^0.70.2 | Line charts, bar charts, pie charts for attendance dashboard | Most popular open-source Flutter chart library (6,200+ GitHub stars). Supports line, bar, pie, radar charts -- exactly what's needed for attendance rate cards, mini chart dashboard, and cross-outlet comparison. Declarative API integrates cleanly with Riverpod state. No commercial license needed (MIT). Lightweight compared to Syncfusion. |

**Why fl_chart over Syncfusion:** This project serves 4 outlets / 14 employees. We need 3-4 simple chart types (bar chart for daily attendance, line chart for trends, pie chart for on-time/late ratios). fl_chart handles all of these. Syncfusion's 30+ chart types and commercial licensing are unnecessary overhead. The free community license has revenue/employee caps that create future ambiguity.

**Why fl_chart over graphic/charts_flutter:** `charts_flutter` is abandoned (Google archived it). `graphic` is newer but has a smaller community and less documentation. fl_chart has the best balance of features, maintenance, and community support.

**Confidence:** MEDIUM -- version 0.70.2 found via pub.dev search results; version 1.1.0 also exists but may be a pre-release or fork. Pin to `^0.70.2` as the stable line. Verify exact latest stable with `flutter pub add fl_chart` at implementation time.

---

### Push Notifications (Missing Clock-Out Alert)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `firebase_core` | ^3.13.0 | Firebase initialization (required by firebase_messaging) | Required base dependency for any Firebase service in Flutter. |
| `firebase_messaging` | ^15.2.3 | FCM push notification token management + foreground handling | Industry standard for Android push notifications. Supabase has no native push notification service -- FCM is the recommended integration path per Supabase's own documentation. |

**Architecture for missing clock-out notifications:**

1. **Flutter app** registers FCM device token on admin login, stores token in Supabase `device_tokens` table
2. **Supabase Database Webhook** triggers on attendance_logs INSERT -- a pg_cron job or Edge Function checks at shift-end time if employee has `masuk` but no `pulang`
3. **Supabase Edge Function** (`push-missing-clockout`) calls FCM HTTP v1 API with the admin's device token to send the alert
4. **Flutter app** receives push via `firebase_messaging` and shows notification using existing `KioskNotificationHelper.kt` or `flutter_local_notifications`

**Important:** Firebase requires `google-services.json` in `android/app/`. This is the first time Firebase is introduced to this project. Requires creating a Firebase project and registering the Android app.

**Alternative considered -- local-only notification:** For MVP, could skip Firebase entirely and use a local periodic check with `flutter_foreground_task` (already installed) + `flutter_local_notifications` (already installed). The foreground service already runs 24/7. Add a periodic timer that checks at shift-end times if clock-out is missing, then fire a local notification. This avoids Firebase setup entirely.

**Recommendation:** Start with the **local-only approach** (zero new dependencies). Add Firebase later only if remote push from server is truly needed (e.g., kepala gerai needs notification on their personal phone, not the kiosk tablet).

**Confidence:** HIGH for local approach (uses existing dependencies), MEDIUM for Firebase approach (versions from training data, verify at implementation).

---

### Supabase Auth User Management (Kepala Gerai Onboarding)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Supabase Edge Functions (Deno) | N/A (server-side) | Secure admin user creation endpoint | `supabase.auth.admin.createUser()` requires `service_role` key which MUST NEVER be in the Flutter app. Edge Function is the official Supabase-recommended pattern for client-initiated admin operations. |
| `supabase` CLI | latest | Deploy Edge Functions, manage migrations | Required for creating and deploying Edge Functions. Install via `npm install -g supabase` or `scoop install supabase` on Windows. |

**Architecture for kepala gerai onboarding:**

```
Flutter App                    Supabase Edge Function
    |                               |
    |-- POST /create-kepala-gerai ->|
    |   { email, outlet_id }        |
    |                               |-- auth.admin.createUser()
    |                               |-- Set app_role: 'kepala_gerai'
    |                               |-- Generate random password
    |                               |<- { email, password }
    |<- { email, password } --------|
    |
    |-- Copy to WhatsApp (share_plus)
```

**No new Flutter dependencies needed.** The existing `supabase_flutter: ^2.8.4` can invoke Edge Functions via `Supabase.instance.client.functions.invoke('create-kepala-gerai', body: {...})`. The `share_plus: ^10.1.4` (already installed) handles copy-to-WhatsApp.

**Confidence:** HIGH -- this is the documented Supabase pattern for admin user creation from client apps. Verified via official Supabase docs.

---

### Smart Attendance Pattern Algorithm

**No new dependencies needed.** Pure Dart computation.

The pattern detection algorithm operates on `attendance_logs` data already available via Supabase and SQLite:

| Component | Implementation | Dependencies |
|-----------|---------------|--------------|
| Usual check-in time calculation | Statistical mean/median of last N scan times per employee | Pure Dart (`DateTime` math) |
| Late detection | Compare scan time vs calculated pattern or scheduled shift start | Pure Dart |
| Overtime calculation | `pulang` time minus `masuk` time minus break duration, compare to shift template duration | Pure Dart |
| Streak calculation | Count consecutive days with attendance, reset on absence | Pure Dart |

**Why no ML/stats library:** The "pattern" is a simple median of historical clock-in times. For 14 employees with ~90 attendance records, this is basic arithmetic. No need for `ml_linalg`, `statistics`, or any stats package. Keep it simple:

```dart
// Pseudocode for pattern detection
List<DateTime> recentCheckins = logs
    .where((l) => l.type == 'masuk' && l.employeeId == id)
    .map((l) => l.scannedAt)
    .toList();

Duration medianTime = _calculateMedianTimeOfDay(recentCheckins);
bool isLate = todayCheckin.timeOfDay > medianTime + tolerance;
```

**Confidence:** HIGH -- pure Dart, no external dependencies.

---

### Gamification (Attendance Streaks)

**No new dependencies needed.**

| Component | Implementation | Dependencies |
|-----------|---------------|--------------|
| Streak counter | Query attendance_logs for consecutive days | Pure Dart + existing Supabase |
| Streak display | Custom widget with existing `confetti: ^0.8.0` for milestone celebrations | Already installed |
| Streak badge | Extend existing badge system (`badges` table) | Existing `flutter_colorpicker`, `cached_network_image` |

The existing badge system (`badges` table + `active_badge_id` on employees) already supports visual rewards. Streaks just add a new data source for badge assignment.

**Confidence:** HIGH -- leverages existing systems entirely.

---

### Cross-Outlet Reporting

**No new dependencies needed.**

| Component | Implementation | Dependencies |
|-----------|---------------|--------------|
| Multi-outlet data query | Supabase query joining `attendance_logs` + `outlets` | Existing `supabase_flutter` |
| Comparison bar chart | fl_chart grouped bar chart | `fl_chart` (new, see above) |
| PDF export of comparison | Extend existing `PdfReportService` | Existing `pdf` + `printing` |
| CSV export | Extend existing CSV service | Existing `csv` |

**Confidence:** HIGH -- only new dependency is fl_chart.

---

## Summary: What to Add

### New Dependencies (pubspec.yaml)

```yaml
dependencies:
  # Charts for attendance dashboard, rate cards, cross-outlet comparison
  fl_chart: ^0.70.2
```

That's it. **One new dependency** for all v4.0 features.

### Server-Side Additions (Not Flutter)

| Addition | Purpose | Setup Required |
|----------|---------|----------------|
| Supabase Edge Function: `create-kepala-gerai` | Secure user creation | `supabase init` + `supabase functions new` + deploy |
| Supabase DB migration: `device_tokens` table | FCM token storage (only if Firebase push is added) | SQL migration |
| Supabase DB migration: `employee_patterns` table or view | Cache computed attendance patterns | SQL migration |
| Supabase DB migration: `streaks` column or table | Track current/longest streaks | SQL migration |

### Conditional Dependencies (Only If Firebase Push Needed)

```yaml
# ONLY add if local notification approach is insufficient:
dependencies:
  firebase_core: ^3.13.0
  firebase_messaging: ^15.2.3
```

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `syncfusion_flutter_charts` | Commercial license complexity, massive package for simple charts | `fl_chart` -- open source, lightweight, sufficient for 4 chart types |
| `charts_flutter` | Archived/abandoned by Google | `fl_chart` |
| `firebase_analytics` | No analytics requirement, adds Firebase bloat | Nothing -- not needed |
| `flutter_chart` (not fl_chart) | Unmaintained, confused naming | `fl_chart` (by imaNNeo) |
| Any statistics/ML library | Pattern detection is simple median calculation on small dataset | Pure Dart `DateTime` arithmetic |
| `awesome_notifications` | Already have 3-tier notification system that works | Existing `flutter_local_notifications` + `KioskNotificationHelper.kt` |
| `onesignal_flutter` | Alternative push service -- unnecessary if using FCM or local approach | Local notifications (existing) or Firebase (if needed) |
| `supabase_auth_ui` | Pre-built auth widgets -- wrong for kepala gerai onboarding which is admin-initiated, not self-service | Custom form + Edge Function |
| `flutter_sparkline` | Abandoned, Dart 2 only | `fl_chart` has sparkline-style mini charts built in |
| `percent_indicator` | For progress rings/gauges | fl_chart's `PieChart` or custom `CustomPainter` -- avoid adding dependency for one widget |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Charts | `fl_chart` | `syncfusion_flutter_charts` | Commercial license, 10x heavier, 30+ chart types we don't need |
| Charts | `fl_chart` | `graphic` ^2.4.0 | Newer, smaller community, less documentation, grammar-of-graphics API is overkill |
| Push notifications | Local approach (existing deps) | Firebase FCM | Firebase adds 2 dependencies + google-services.json + Firebase project setup. Local approach works since the kiosk tablet is always-on |
| User creation | Supabase Edge Function | Direct `service_role` in app | SECURITY RISK -- service_role key bypasses RLS entirely. Never expose in client app |
| User creation | Supabase Edge Function | Supabase RPC (PostgreSQL function) | RPC runs as the calling user's role. Creating auth users requires `service_role` privileges that RPC cannot safely provide |
| Pattern algorithm | Pure Dart | `ml_linalg` or stats package | 14 employees, ~90 records. Simple median/mean. Adding ML library is absurd overkill |
| Streak display | Existing badge system + confetti | `gamification` package | No mature Flutter gamification package exists. Custom implementation with existing tools is cleaner |

---

## Version Compatibility

| Package | Version | Dart SDK | Flutter SDK | Project Compatible? |
|---------|---------|----------|-------------|---------------------|
| `fl_chart` | ^0.70.2 | >=3.0.0 | >=3.7.0 | YES -- project uses Dart >=3.3.0, Flutter 3.41.1 |
| `firebase_core` | ^3.13.0 | >=3.2.0 | >=3.16.0 | YES (if added) |
| `firebase_messaging` | ^15.2.3 | >=3.2.0 | >=3.16.0 | YES (if added) |

**Kotlin compatibility note:** Firebase packages use Kotlin. Project is locked to Kotlin 1.9.25 (cannot upgrade due to nfc_manager). Firebase 3.x/15.x should be compatible with Kotlin 1.9.x but verify at integration time -- Firebase sometimes pulls in Kotlin 2.x transitive dependencies. If conflict arises, pin Kotlin version in `android/build.gradle.kts`.

---

## Installation

```yaml
# Add to pubspec.yaml under dependencies:
dependencies:
  # ... existing deps unchanged ...

  # Charts for attendance dashboard (mini charts, rate cards, cross-outlet comparison)
  fl_chart: ^0.70.2
```

```bash
# Install
C:\flutter\bin\flutter.bat pub get

# Server-side (one-time setup for Edge Functions)
npx supabase init
npx supabase functions new create-kepala-gerai
npx supabase functions deploy create-kepala-gerai
```

---

## Stack Patterns by Feature

**For mini chart dashboard:**
- Use fl_chart `LineChart` for attendance trend (7-day/30-day)
- Use fl_chart `BarChart` for daily check-in distribution
- Use fl_chart `PieChart` for on-time vs late ratio

**For attendance rate cards:**
- Use `Card` + `Column` with fl_chart sparkline-style `LineChart` (small, no axis labels)
- Keep cards in a `GridView` or horizontal `ListView`

**For cross-outlet comparison:**
- Use fl_chart grouped `BarChart` with one group per outlet
- Color-code by outlet using existing `AppColors`

**For gamification streaks:**
- Store streak data in Supabase (new column or table)
- Display with custom widget + fire `confetti` on milestone (7-day, 30-day)
- Award badges from existing badge system

**For push notification (local approach):**
- Add periodic check in existing `flutter_foreground_task` callback
- At configurable time (e.g., 30 min after shift end), query today's logs
- If `masuk` exists without `pulang`, fire `flutter_local_notifications` with channel `absensi_enakko_missing_clockout`

---

## Sources

- [fl_chart on pub.dev](https://pub.dev/packages/fl_chart) -- version 0.70.2 and 1.1.0 found in search results (MEDIUM confidence on exact latest stable)
- [Syncfusion Flutter Charts](https://pub.dev/packages/syncfusion_flutter_charts) -- evaluated and rejected for commercial license complexity
- [Supabase: Create a user (Dart)](https://supabase.com/docs/reference/dart/auth-admin-createuser) -- confirms service_role requirement
- [Supabase: Edge Functions](https://supabase.com/docs/guides/functions) -- server-side Deno functions for secure admin operations
- [Supabase: Database Webhooks](https://supabase.com/docs/guides/database/webhooks) -- trigger Edge Functions from DB events
- [Supabase: Push Notifications guide](https://supabase.com/docs/guides/functions/examples/push-notifications) -- FCM integration via Edge Functions
- [Firebase Messaging on pub.dev](https://pub.dev/packages/firebase_messaging) -- requires firebase_core
- [Supabase Discussion #20790](https://github.com/orgs/supabase/discussions/20790) -- confirms Edge Function as recommended pattern for client-initiated user creation
- Project `pubspec.yaml` -- verified existing dependencies and SDK constraints
- Project `CLAUDE.md` -- architecture rules, notification system, Kotlin constraints

---
*Stack research for: Absensi Enakko v4.0 Smart Attendance + Admin Dashboard*
*Researched: 2026-03-18*
