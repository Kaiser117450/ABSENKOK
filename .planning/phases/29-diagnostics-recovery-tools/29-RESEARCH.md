# Phase 29: Diagnostics & Recovery Tools — Research

**Researched:** 2026-03-20
**Status:** Complete
**Phase Requirements:** SYNC-04, RECV-01, RECV-02, RECV-03

## Executive Summary

Phase 29 adds user-facing diagnostics and recovery tools to the kiosk. This includes a visual sync indicator on the idle screen and an admin-gated diagnostics screen with a "Force Sync" button. The existing codebase already has all the backend primitives needed — `SqliteService.countPendingLogs()`, `SyncService.syncPendingLogs()`, and `appProvider.pendingCount`. The work is primarily UI integration and routing.

---

## 1. Existing Infrastructure Analysis

### 1.1. Offline Queue (SQLite)

**File:** `lib/services/sqlite_service.dart`

- `countPendingLogs()` — returns `int` count of rows where `sync_status IN ('pending','failed')` — **already exists** (line 158)
- `getPendingLogs()` — returns `List<PendingLog>` with retry limit and batch size — **already exists** (line 125)
- `markLogSynced(localId)` / `markLogFailed(localId)` — **already exist**
- `cleanOldSyncedLogs()` — deletes synced rows >7d — **already exists**

**Key insight:** `countPendingLogs()` is already used by both the kiosk idle header badge and HeartbeatService. No new SQLite methods needed.

### 1.2. Sync Service

**File:** `lib/services/sync_service.dart`

- `SyncService.syncPendingLogs()` → returns `SyncResult` (`({int synced, int failed})`)
- Checks connectivity first, skips if offline
- Handles `PostgrestException` code `23505` (duplicate) as success
- Already does batch `Future.wait` for all pending logs

**Key insight:** This is the exact method the "Force Sync" button should call. No modifications needed to the service itself.

### 1.3. Pending Count in App State

**File:** `lib/providers/app_provider.dart`

- `AppState.pendingCount` (int, default 0) — already tracked
- `AppStateNotifier.setPendingCount(int count)` — already exists (line 167)
- `kiosk_idle_screen.dart` already calls `setPendingCount` after sync on mount (line 261-262)

### 1.4. Current Pending Badge on Kiosk

**File:** `lib/screens/kiosk/kiosk_idle_screen.dart` (lines 783-808)

The kiosk idle screen **already shows** a pending count badge in the header when `pendingCount > 0`:
- Amber container with `cloud_off_outlined` icon
- Shows "{N} pending" text
- Located in top-right header area

**Key insight for SYNC-04:** The requirement says "visual indicator on the idle screen." The current badge is in the _header_ area (top-right). The requirement could be satisfied by enhancing this existing badge or adding a more prominent indicator elsewhere on the idle screen (e.g., near the NFC ring or in a status bar).

### 1.5. Current Kiosk Routing

**File:** `lib/app.dart`

Current kiosk routes:
```
/kiosk          → KioskIdleScreen
/kiosk/scan     → KioskScanScreen
```

The router redirect (line 84-86) enforces: if `hasKiosk` and path doesn't start with `/kiosk`, redirect to `/kiosk`. This means any new `/kiosk/diagnostics` route will be automatically allowed for kiosk users.

### 1.6. Admin Gating Pattern

The kiosk idle screen already has an admin-gated flow via `_goToAdmin()` (line 592) which shows a confirmation dialog then navigates to `/admin/login`. However, for the diagnostic screen, we need a **simpler gate** — not a full admin login, but a secret gesture (e.g., long-press, or tap a hidden area) that opens the diagnostics without requiring Supabase auth.

**Existing pattern:** The logout button (`_confirmLogoutGerai`, line 515) and admin button are both in the header area as small circular icons. The diagnostic screen entry point should follow this same pattern — accessible but not prominent.

---

## 2. Implementation Approach

### 2.1. SYNC-04: Kiosk Idle Screen Sync Indicator

**Current state:** A pending badge already exists in the header (lines 783-808). 

**Enhancement options:**
1. **Option A (Minimal):** Keep the existing header badge as-is. Already satisfies requirement.
2. **Option B (Recommended):** Add a more prominent bottom status bar or subtle animated indicator near the NFC zone when pending > 0. This is more visible than a small header badge.

**Recommended approach:** Add a subtle status strip below the header (or above the bottom bar) that appears when `pendingCount > 0`. This strip would show an icon + count + "menunggu sinkronisasi" text. The existing header badge can remain for redundancy.

**Update frequency:** The `pendingCount` is already updated:
- On mount via `_syncOnMount()` 
- After each NFC scan (implicit through the attendance flow)
- Missing: periodic refresh while idle. Should add a timer to re-read `countPendingLogs()` every 30-60 seconds so the UI stays current.

### 2.2. RECV-01: Admin-Gated Diagnostics Screen

**Entry point options:**
1. **Long-press on logo** — hidden gesture, no visible UI clutter
2. **Tap pending badge** — intuitive but only visible when there are pending logs
3. **Hidden gear icon in header** — always accessible, subtle
4. **Triple-tap on clock** — hidden gesture

**Recommended:** Long-press on the Absensi Enakko logo in the header. This is discoverable by admins who know about it, invisible to employees using the kiosk.

**Screen contents:**
- Pending sync count (real-time)
- Last heartbeat timestamp
- Battery level (from HeartbeatService)
- App version
- "Force Sync" button (RECV-02)
- Sync result (RECV-03)

**Route:** `/kiosk/diagnostics` — nested under `/kiosk` so the existing redirect guard allows it.

### 2.3. RECV-02: Force Sync Button

**Implementation:**
```dart
// In diagnostics screen
Future<void> _forceSync() async {
  setState(() => _isSyncing = true);
  try {
    final result = await SyncService.syncPendingLogs();
    final count = await SqliteService.countPendingLogs();
    // Update global state
    ref.read(appProvider.notifier).setPendingCount(count);
    // Show result toast (RECV-03)
    _showSyncResult(result);
  } catch (e) {
    _showSyncError(e);
  } finally {
    setState(() => _isSyncing = false);
  }
}
```

**Key consideration:** `SyncService.syncPendingLogs()` already checks connectivity. If offline, it returns `(synced: 0, failed: 0)`. The UI should differentiate between "no pending" and "offline" scenarios.

### 2.4. RECV-03: Toast/Snackbar Feedback

**Existing toast library:** `toastification` is already in `pubspec.yaml` and used throughout the app.

**Success toast:** "Sinkronisasi berhasil — {N} data berhasil dikirim"
**Partial failure:** "Sinkronisasi sebagian — {synced} berhasil, {failed} gagal"
**Offline:** "Tidak ada koneksi internet"
**Nothing to sync:** "Tidak ada data pending"

---

## 3. Technical Details

### 3.1. File Changes Required

| File | Change |
|------|--------|
| `lib/screens/kiosk/kiosk_idle_screen.dart` | Add sync indicator widget (SYNC-04), long-press handler on logo, periodic pendingCount refresh |
| `lib/screens/kiosk/kiosk_diagnostics_screen.dart` | **NEW** — diagnostics screen with force sync (RECV-01, RECV-02, RECV-03) |
| `lib/app.dart` | Add `/kiosk/diagnostics` route |

### 3.2. No New Dependencies

All required functionality exists:
- `sqflite` — SQLite access
- `connectivity_plus` — network check
- `toastification` — toast feedback
- `battery_plus` — battery info (for display)
- `package_info_plus` — version info (for display)

### 3.3. No Database Changes

No Supabase migrations needed. All data is read from existing local SQLite queue and existing Supabase `outlets` table (heartbeat data).

### 3.4. Connectivity Awareness

`SyncService.syncPendingLogs()` already handles offline gracefully:
```dart
final connectivity = await Connectivity().checkConnectivity();
if (connectivity.contains(ConnectivityResult.none) || connectivity.isEmpty) {
  return (synced: 0, failed: 0);
}
```

The diagnostics screen should show connectivity status and disable the Force Sync button when offline.

---

## 4. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Force sync called during heartbeat sync | Low | `SyncService.syncPendingLogs()` is idempotent — duplicate syncs handled via `23505` |
| pendingCount goes stale on idle screen | Medium | Add periodic timer (30s) to re-read count |
| Employee accidentally enters diagnostics | Low | Long-press gesture has natural barrier |
| Force sync floods Supabase with retry storm | Low | `syncBatchSize` constant already limits batch; retry has `syncMaxRetries` cap |

---

## 5. Validation Architecture

### Dimension 1: Input Validation
- Force sync button should be disabled while sync is already in progress (prevent double-tap)
- Pending count display should handle 0, 1, and large numbers gracefully

### Dimension 2: State Machine
- Diagnostics screen states: `idle` → `syncing` → `result` → `idle`
- Sync indicator on idle screen: visible when `pendingCount > 0`, hidden when 0

### Dimension 3: Integration
- After force sync, `pendingCount` in AppState must be refreshed
- HeartbeatService should also pick up the updated count on next heartbeat

### Dimension 4: Edge Cases
- Force sync when already at 0 pending → show "Tidak ada data pending" toast
- Force sync when offline → show "Tidak ada koneksi internet" toast
- Force sync when all logs fail → show partial failure message with counts

### Dimension 5: Security
- Diagnostics screen is kiosk-only (no sensitive data exposed)
- No auth secrets or service_role keys displayed
- Device info (battery, version) is non-sensitive

### Dimension 6: Performance
- `countPendingLogs()` is a simple COUNT query — fast
- Periodic poll every 30s has negligible impact
- Force sync uses existing batch mechanism

### Dimension 7: Cleanup
- No resources to leak — diagnostics screen is stateless except sync state
- Timer for periodic count refresh must be cancelled in dispose()

### Dimension 8: Observable Behavior
- Sync indicator visibility testable via `pendingCount > 0` state
- Force sync result verifiable via toast content and updated count

---

## RESEARCH COMPLETE

All requirements (SYNC-04, RECV-01, RECV-02, RECV-03) can be implemented using existing backend primitives. No new dependencies or database changes needed. Primary work is UI: a sync indicator on the idle screen and a new diagnostics screen with force sync capability.
