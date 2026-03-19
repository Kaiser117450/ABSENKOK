# Project Research — STACK

**Dimension:** Stack additions/changes
**Focus:** Sync visibility, kiosk/device health, recovery/reconciliation, failure surfaces

## Existing Context
**Framework:** Flutter 3.x / Dart (Kotlin 1.9.25 — cannot upgrade to 2.x, breaks nfc_manager)
**Backend:** Supabase (PostgreSQL + Auth + Realtime)
**Local DB:** SQLite (sqflite) — offline attendance queue + schedule cache
**State:** Riverpod (`AppProvider`)

## What's Needed / Recommended

1. **Device Health Metrics:**
   - **`battery_plus` (new):** To monitor battery percentage and charging state (critical for tablets running 24/7).
   - **`device_info_plus` (already in pubspec for 3.x projects, check if installed):** To get the physical device model and OS version.
   
2. **Error & Crash Tracking (Failure Surfaces):**
   - **`sentry_flutter` (new):** The standard for Flutter crash reporting. Captures unhandled exceptions and Native/Kotlin layer crashes (Android). Ideal for a set-and-forget kiosk environment.
   
3. **Connectivity & Sync:**
   - **`connectivity_plus` / `internet_connection_checker_plus`:** To reliably know if there's actual internet vs just a Wi-Fi connection with no routing.
   - No new DB stack needed; SQLite queue table is sufficient but needs query extensions to expose `Stream<int>` counts of pending rows.

## What NOT to Add
- Do not add complex event-sourcing or large logging plugins like `logger` that write thousands of files locally, as it could fill up the Android tablet's storage over time. Just rely on Sentry + targeted Supabase heartbeat updates.
