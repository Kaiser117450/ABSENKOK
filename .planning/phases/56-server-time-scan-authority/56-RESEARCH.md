# Phase 56: Server-Time Scan Authority - Research

**Researched:** 2026-03-27
**Domain:** server-authoritative kiosk scan timing, offline queue ordering, and break-first intent capture across Flutter, SQLite, and Supabase/Postgres
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Break-first flow
- When the first scan is inside the eligible break-first window, the kiosk should expose an extra `Istirahat Dulu` action instead of forcing everything through only the default `Masuk` path.
- Selecting the break-first path should still show a short yes/no confirmation so accidental taps do not silently create break-first intent.
- The kiosk should ask every eligible time; it must not silently reuse a previous answer for the employee.
- After a break-first confirmation, the success state should explicitly say the break-first event was saved and hint that the next expected tap is `Selesai Istirahat`.

### Offline-safe scan authority
- If server time cannot be reached at scan time, the kiosk should still accept the scan and queue it as pending instead of blocking attendance capture.
- Offline capture only applies to employees already present in the local cache; uncached employees should be told to retry when connectivity returns.
- Queued scans should auto-sync in the background when connectivity returns; staff should not have to trigger a manual upload.
- If later server-authoritative reconciliation makes a queued scan suspicious, the system should keep the event history and flag it for admin review rather than silently rewriting or dropping the event.

### Scan feedback
- Live server-confirmed scans should show the authoritative WITA timestamp on the success screen.
- Queued/offline scans should use a visibly different success treatment from live server-confirmed scans.
- On-screen wording should stay human-first; staff should see the time and state clearly without backend jargon such as "server authority" or sync protocol terms.
- Queued confirmations should keep the current fast auto-close, with the existing idle-screen pending badge and banner carrying the persistent follow-up signal.

### Claude's Discretion
- Exact copy, iconography, and color treatment for the break-first prompt and queued success state, as long as live vs pending scans remain unmistakable.
- Whether the extra `Istirahat Dulu` action appears as a separate primary button or a visually subordinate alternative, as long as it only appears for eligible cases and the normal flow stays fast.
- The exact admin-review surface for suspicious queued events and break-first late traces, as long as later review can distinguish them from normal late cases.

### Deferred Ideas (OUT OF SCOPE)
- Exact admin-review labeling and filtering for break-first-late vs normal late cases can stay flexible for planning, as long as the distinction remains available for later recap and audit work.
- Any supervisor-only offline override or uncached-employee fallback flow is not part of this phase and should be treated as a separate future capability if needed.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| `SCAN-01` | Kiosk attendance timestamps are stamped from a server-authoritative WITA time source so device local-clock drift or manipulation cannot change lateness and payroll outcomes. | The current kiosk path still creates `scanned_at` from `DateTime.now()` in Flutter, stores that in SQLite, and replays it later. Phase 56 needs a server-owned insert path plus a deterministic offline replay contract. |
| `SCAN-02` | When an employee appears to start with a break-first pattern, the kiosk flow can confirm that initial break intent and the recap engine still evaluates the same shift window correctly instead of treating it as a normal on-time arrival. | The current scan flow only knows `AttendanceType` and last server log type. Phase 56 needs explicit break-first intent metadata and a shared eligibility context built from the Phase 55 policy contract. |
</phase_requirements>

## Summary

Phase 56 is not a simple timestamp replacement. The current kiosk scan path still trusts the tablet clock end-to-end: `lib/screens/kiosk/kiosk_scan_screen.dart` creates `scanTime = DateTime.now()`, stores that UTC string in SQLite, and `lib/services/sync_service.dart` later inserts the same value into `attendance_logs`. The same code path also derives smart buttons only from server history, so pending local scans are invisible to the next tap, and the current success path cannot show a true authoritative WITA time because none exists yet.

The planner should treat this as one server contract and one queue contract. The server contract should own authoritative scan time, WITA projection, break-first eligibility, and returned scan feedback for live scans. The queue contract should preserve intent, provenance, and event order when the server is unavailable, without pretending the tablet clock is authoritative. Reuse the Phase 55 schedule-policy contract for lateness and break-first windows; do not duplicate that math inside kiosk widgets.

**Primary recommendation:** add a security-definer kiosk scan RPC plus a lightweight scan-context RPC, extend the offline queue with monotonic order and intent/provenance fields, and replace parallel replay with deterministic ordered sync.

## Existing Code Findings

### 1. The kiosk still stamps scans on-device
- `lib/screens/kiosk/kiosk_scan_screen.dart` writes `scanned_at` from `DateTime.now().toUtc().toIso8601String()`.
- `lib/services/sync_service.dart` inserts that same string into `attendance_logs`.
- `PatternDetectionService.checkAndNotifyIfLate()` also receives the device-side `scanTime`, so any lateness-sensitive follow-up still trusts the tablet clock today.

**Implication:** Phase 56 must remove `DateTime.now()` from all kiosk business-time decisions, not only from the final insert call.

### 2. Offline replay does not preserve deterministic authoritative order
- `SqliteService.getPendingLogs()` orders by `created_at ASC`.
- `SyncService.syncPendingLogs()` then uploads those rows with `Future.wait(...)`, so the replay order is effectively concurrent, not sequential.
- `pending_logs.created_at` and `local_id` are both derived from the device clock, so even the local ordering key is not monotonic if the tablet time changes.

**Implication:** later server-authoritative replay cannot rely on current `created_at` or the current parallel sync loop. The queue needs a device-local monotonic sequence, and sync needs ordered replay.

### 3. Auto-sync on connectivity restore is not implemented for attendance logs
- `lib/screens/kiosk/kiosk_idle_screen.dart` calls `SyncService.syncPendingLogs()` on mount.
- `lib/screens/kiosk/kiosk_scan_screen.dart` calls it after a new scan is queued.
- `lib/services/heartbeat_service.dart` listens for connectivity restore, but only retries heartbeats. It never triggers `SyncService.syncPendingLogs()`.

**Implication:** the locked requirement "auto-sync in the background when connectivity returns" still needs real implementation.

### 4. Smart action resolution ignores pending local scans
- `lib/screens/kiosk/kiosk_scan_screen.dart` loads `_lastType` only by querying `attendance_logs` from Supabase.
- On timeout or offline failure, it falls back to `_lastType = null`, which means the UI shows `Masuk`.
- The queue is never consulted to derive the next action.

**Implication:** after an offline queued scan, the next scan can offer the wrong button set unless the planner introduces a merged authoritative-plus-pending timeline.

### 5. Offline fallback currently has only employee cache, not policy context
- `lib/screens/kiosk/kiosk_idle_screen.dart` can work offline only for employees already present in `EmployeeCacheService`.
- That cache currently holds employee identity and backup-mode hints, not today's schedule, shift band, contract, or break-first deadline.
- Phase 55 defines break-first windows from shift band plus employment contract.

**Implication:** offline break-first eligibility cannot be correct unless Phase 56 adds a lightweight local scan-context cache or a conservative fallback rule. Cached employee identity alone is insufficient.

### 6. The queue schema is shared beyond kiosk scan
- `lib/screens/admin/sakit_izin_dialog.dart` also falls back to `SqliteService.insertPendingLog(...)` when Supabase insert fails.

**Implication:** any queue migration in Phase 56 must be additive and default-safe for non-kiosk producers such as `ADMIN_INPUT`.

### 7. The recap layer already expects WITA projection from server timestamps
- `sql/phase_42_portal_attendance_recap_20260323.sql` consistently projects attendance with `AT TIME ZONE 'Asia/Makassar'`.
- The portal recap RPC already uses authoritative local-day logic from the server side.

**Implication:** Phase 56 should keep stored kiosk timestamps as server-owned `timestamptz` data and continue projecting WITA on read. Do not switch the authoritative storage model to local-time strings.

### 8. Uncached-offline employee handling is still undefined in the UI
- The slow-path employee lookup in `lib/screens/kiosk/kiosk_idle_screen.dart` catches network errors and simply returns to idle.
- The locked decision requires a human-readable retry message for uncached employees when connectivity is down.

**Implication:** this phase needs explicit offline-uncached feedback, not just queue changes.

## Standard Stack

### Core
| Library / System | Version | Purpose | Why Standard |
|------------------|---------|---------|--------------|
| Supabase Flutter | repo-resolved `2.12.0` (`pub.dev` latest `2.12.2`, published 27 hours ago) | Call database RPCs from kiosk Flutter code | The repo already uses Supabase everywhere and already has a stable RPC pattern in `HeartbeatService`. |
| PostgreSQL `timestamptz` + `statement_timestamp()` + `AT TIME ZONE 'Asia/Makassar'` | PostgreSQL current docs | Server-authoritative time capture plus WITA projection | PostgreSQL stores timezone-aware timestamps in UTC and converts them for display; this matches the existing Phase 42 WITA recap pattern. |
| SQLite queue via `sqflite` | repo-resolved `2.4.2` (`pub.dev` latest `2.4.2`, published 13 months ago) | Durable pending scan queue and ordered replay metadata | The repo already uses SQLite for offline attendance, and `sqflite` supports schema versioning and background-thread DB work. |
| Flutter state/UI via `flutter_riverpod` and existing kiosk screens | repo-resolved `2.6.1` (`pub.dev` latest `3.3.1`, published 17 days ago) | Kiosk scan state, success states, pending badge state | The kiosk screens are already structured around Riverpod state and do not need a new state layer. |

### Supporting
| Library / System | Version | Purpose | When to Use |
|------------------|---------|---------|-------------|
| `connectivity_plus` | repo-resolved `6.1.5` (`pub.dev` latest `7.0.0`, published 6 months ago) | Connectivity hint only | Use to decide whether to attempt background replay, but never as proof that the internet or Supabase RPC is reachable. |
| `go_router` | repo-resolved `14.8.1` (`pub.dev` latest `17.1.0`, published 51 days ago) | Existing kiosk navigation | Keep the current kiosk route flow; Phase 56 is not a routing rewrite. |
| `shared_preferences` | repo-resolved `2.5.4` (`pub.dev` latest `2.5.5`, published 21 hours ago) | Existing session/preferences only | Keep using it for kiosk session and minor prefs, but not for critical offline authority state. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Kiosk RPC for live insert | Direct `attendance_logs` table insert from Flutter | Simpler, but the client can still send arbitrary `scanned_at` and cannot return a trusted WITA authority result. |
| Monotonic queue order plus sequential replay | Keep `created_at` text ordering plus `Future.wait` | Easier, but replay order stays nondeterministic and still depends on the device clock. |
| Explicit break-first intent field | Infer break-first from seeing a first `break` event later | Cheaper now, but it allows the recap layer to silently misclassify false on-time or false late cases. |
| Repo-pinned package stack | Opportunistic package upgrades during Phase 56 | Higher churn. `connectivity_plus 7.0.0` alone raises Android toolchain requirements beyond the repo's pinned Phase 47 release contract. |

**Installation:**
```bash
flutter pub get
```

**Version verification:**
- Repo-resolved versions came from `pubspec.lock` on 2026-03-27.
- Current package releases were verified on 2026-03-27 against `pub.dev`:
  - `supabase_flutter` `2.12.2`
  - `sqflite` `2.4.2`
  - `connectivity_plus` `7.0.0`
  - `flutter_riverpod` `3.3.1`
  - `go_router` `17.1.0`
  - `shared_preferences` `2.5.5`

## Architecture Patterns

### Recommended Project Structure
```text
sql/
├── phase_56_server_time_scan_authority_20260327.sql
└── [contract tests continue to read migration files directly]

lib/models/
├── attendance_log.dart
├── pending_log.dart
└── [new] kiosk_scan_context.dart

lib/services/
├── sqlite_service.dart
├── sync_service.dart
├── heartbeat_service.dart
└── [new] kiosk_scan_authority_service.dart

lib/screens/kiosk/
├── kiosk_idle_screen.dart
└── kiosk_scan_screen.dart

test/
├── services/
│  ├── pattern_detection_test.dart
│  ├── [new] kiosk_scan_authority_service_test.dart
│  └── [new] sync_service_order_test.dart
├── screens/kiosk/
│  └── [new] kiosk_scan_server_time_test.dart
└── phase56/
   └── [new] server_time_scan_sql_contract_test.dart
```

### Pattern 1: Split scan authority into context RPC and record RPC
**What:** Use one RPC to fetch authoritative scan context before the action UI is shown, and one RPC to record live scans with a server-owned timestamp.
**When to use:** Every kiosk scan screen entry and every live scan submission.

**Recommended responsibilities:**
- `get_kiosk_scan_context(...)`
  - returns authoritative server "now"
  - returns WITA display time
  - returns last authoritative server event
  - returns Phase 55 policy context needed for break-first eligibility
- `record_kiosk_scan(...)`
  - stamps `scanned_at` on the server
  - stores explicit intent/provenance fields
  - returns authoritative WITA time for the success screen
  - returns review flags for suspicious queued replays

**Why:** the break-first button itself depends on the same trusted WITA boundary as the insert. A live UI cannot safely decide eligibility from the tablet clock.

### Pattern 2: Keep authoritative server time separate from device capture metadata
**What:** Treat the stored attendance event time and the device-observed capture time as two different facts.
**When to use:** Every queue insert and every server insert/replay.

**Recommended field direction:**
- `attendance_logs.scanned_at`: authoritative server `timestamptz`
- `attendance_logs.device_captured_at`: nullable device timestamp for audit only
- `attendance_logs.capture_mode`: `live` or `queued`
- `attendance_logs.queue_order`: per-device monotonic replay order
- `attendance_logs.initial_scan_intent`: nullable enum such as `break_first`
- `attendance_logs.requires_admin_review`: boolean

**Why:** this preserves history for suspicious offline cases without letting the device clock decide payroll-critical time.

### Pattern 3: Make queue order monotonic and replay it deterministically
**What:** Add a monotonic local sequence to `pending_logs` and sync queued events in that order, not in parallel.
**When to use:** All offline queue writes and all replay uploads.

**Recommended implementation direction:**
- Add `queue_order INTEGER` with a monotonic insert order.
- Keep `local_id` for idempotency.
- Order by `queue_order ASC`.
- Replay sequentially or through one ordered batch RPC.

**Why:** the current `created_at ASC` plus `Future.wait` contract cannot preserve authoritative event order.

### Pattern 4: Build action buttons from a merged timeline
**What:** Resolve kiosk buttons from server context plus unsynced local pending events for the same employee/device.
**When to use:** Every time `kiosk_scan_screen` opens.

**Required merged inputs:**
- last authoritative server event
- pending local events not yet acknowledged by the server
- Phase 55 shift-band and contract policy context
- current capture mode (`online` vs `queued/offline`)

**Why:** otherwise the next tap after a queued scan can offer `Masuk` when the next valid action is actually `Selesai Istirahat` or `Pulang`.

### Pattern 5: Cache only the minimum offline policy context
**What:** Cache a compact per-employee daily scan context, not the entire schedule system.
**When to use:** Offline support for cached employees only.

**Recommended cached fields:**
- employee contract
- today's logical workday date
- today's shift band / required hours
- break-first deadline from the Phase 55 policy
- last authoritative server context snapshot time

**Why:** Phase 56 needs enough local context to preserve break-first intent safely when offline, but the kiosk does not need full admin scheduling state.

### Pattern 6: Keep live and queued success states explicitly distinct
**What:** The success screen should branch on authority state, not just on attendance type.
**When to use:** Every kiosk success state and any related follow-up surface.

**Required output states:**
- `live_confirmed`
  - show authoritative WITA time returned by RPC
  - use the normal success styling
- `queued_pending`
  - show clearly that the event is saved locally and waiting for confirmation
  - keep fast auto-close and the idle pending badge/banner
  - if showing a time, label it as provisional, not authoritative

### Anti-Patterns to Avoid
- **Direct table insert from kiosk Flutter:** it cannot enforce server-owned scan time.
- **Any business decision based on `DateTime.now()` in kiosk scan code:** that reintroduces device-clock trust.
- **Parallel queued replay:** it breaks offline event ordering.
- **Inferring break-first later from missing `masuk`:** it is too lossy for later recap rules.
- **Storing critical offline authority state in `SharedPreferences`:** the plugin docs explicitly say it is not for critical data, and cached APIs can diverge across isolates/engine instances.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| WITA business-time math | Dart-side manual timezone conversion as the source of truth | PostgreSQL `timestamptz` + `AT TIME ZONE 'Asia/Makassar'` | The database already owns WITA recap projection and stores timezone-aware values in UTC internally. |
| Reachability truth | "online" decisions from `Connectivity().checkConnectivity()` alone | Real RPC attempt + queue fallback | `connectivity_plus` explicitly warns that network type does not guarantee internet access. |
| Offline replay order | Timestamp sorting plus concurrent uploads | Monotonic queue order plus deterministic replay | Device timestamps drift, and concurrent replay destroys intended ordering. |
| Break-first reconstruction | Re-deriving intent later from `type == 'break'` | Explicit `initial_scan_intent` or `break_first_confirmed` data | Later recap cannot safely distinguish confirmed break-first from ordinary late/break anomalies. |
| Pending authority state | SharedPreferences or transient widget state | SQLite queue rows | This data is critical, durable, and shared across app restarts and background activity. |

**Key insight:** the dangerous bugs in this phase are silent classification bugs, not loud crashes. The stack should preserve enough explicit provenance that later recap logic can tell "live authoritative", "queued but reconciled", and "queued and suspicious" apart.

## Common Pitfalls

### Pitfall 1: Removing `DateTime.now()` only at the final insert
**What goes wrong:** the success screen, break-first eligibility, pattern-detection input, or button selection still trust the tablet clock even if the final DB row does not.
**Why it happens:** the current code uses `DateTime.now()` in multiple kiosk surfaces, not only in the sync layer.
**How to avoid:** audit every kiosk business-time use and replace it with either server context or explicit provisional metadata.
**Warning signs:** live success UI still shows a time before the RPC returns.

### Pitfall 2: Treating connectivity as proof of successful sync
**What goes wrong:** the app marks a scan as effectively online even when Wi-Fi exists but Supabase is unreachable.
**Why it happens:** `connectivity_plus` reports transport type, not actual end-to-end reachability.
**How to avoid:** only classify a scan as live-confirmed after the RPC succeeds; otherwise queue it.
**Warning signs:** scans disappear from the queue without a confirmed RPC result.

### Pitfall 3: Preserving queue rows but losing their intended order
**What goes wrong:** later server-authoritative timestamps reflect network race order instead of capture order.
**Why it happens:** current sync is parallel and current queue ordering is tied to device time.
**How to avoid:** add a monotonic local order key and sync deterministically.
**Warning signs:** two queued scans from the same employee can swap order on the server.

### Pitfall 4: Offering buttons from server history only
**What goes wrong:** after an offline queued `break` or `kembali`, the next scan screen offers the wrong action because the server has not seen the queued event yet.
**Why it happens:** `_loadLastAttendance()` only reads Supabase.
**How to avoid:** merge authoritative server history with pending local events before rendering action buttons.
**Warning signs:** offline repeat scans keep defaulting back to `Masuk`.

### Pitfall 5: Recording break-first as plain `break`
**What goes wrong:** later recap cannot tell whether the first `break` was a confirmed break-first start or just an anomalous event, so false on-time/late states remain possible.
**Why it happens:** `AttendanceType` alone does not capture first-scan intent.
**How to avoid:** persist explicit break-first confirmation metadata.
**Warning signs:** recap logic still has to "guess" what the first event meant.

### Pitfall 6: Forgetting uncached-offline handling
**What goes wrong:** offline employees who are not in the local cache fail silently or look like "not found" errors.
**Why it happens:** the current slow path just falls back to idle on lookup failure.
**How to avoid:** add explicit retry-when-online messaging for uncached offline scans.
**Warning signs:** operators see no reason when an offline uncached employee cannot scan.

### Pitfall 7: Breaking non-kiosk queue producers
**What goes wrong:** admin `sakit/izin` offline fallback stops working after the queue schema changes.
**Why it happens:** `pending_logs` is shared, but it is easy to think of it as kiosk-only.
**How to avoid:** add defaults for new queue columns and keep non-kiosk producers compatible.
**Warning signs:** `ADMIN_INPUT` inserts fail after the migration.

## Code Examples

Verified patterns from official sources and existing repo patterns:

### Flutter RPC call pattern
```dart
final result = await Supabase.instance.client.rpc(
  'record_kiosk_scan',
  params: {
    'p_employee_id': employeeId,
    'p_requested_action': requestedAction,
  },
);
```
Source: Supabase Dart RPC docs and the repo's `HeartbeatService` RPC pattern.

### Authoritative server timestamp capture with WITA projection
```sql
DECLARE
  v_scanned_at timestamptz := statement_timestamp();
BEGIN
  INSERT INTO attendance_logs (scanned_at)
  VALUES (v_scanned_at);

  RETURN QUERY
  SELECT v_scanned_at, v_scanned_at AT TIME ZONE 'Asia/Makassar';
END;
```
Source: Inference from PostgreSQL current date/time docs plus the repo's existing `AT TIME ZONE 'Asia/Makassar'` recap pattern in `sql/phase_42_portal_attendance_recap_20260323.sql`.

### Ordered queue fetch pattern
```dart
final rows = await db.query(
  'pending_logs',
  orderBy: 'queue_order ASC',
);
```
Source: Recommended extension of the repo's current `SqliteService.getPendingLogs()` pattern.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Kiosk inserts send `scanned_at` from the device clock | Kiosk should call a server RPC that stamps the event on receipt and returns authoritative WITA time | Phase 56 | Device clock drift/manipulation stops affecting lateness and payroll inputs for live scans. |
| Offline queue sorted by clock-derived timestamps and replayed in parallel | Offline queue should carry monotonic local order and replay deterministically | Phase 56 | Later server reconciliation can preserve event order instead of racing inserts. |
| Break-first inferred from raw event sequence only | Break-first should be stored as explicit confirmed intent | Phase 56 | Later recap can distinguish confirmed break-first from ordinary late/break anomalies. |

**Deprecated/outdated:**
- Direct kiosk `attendance_logs` inserts with client-supplied `scanned_at`: outdated for this phase because they cannot satisfy `SCAN-01`.
- `ConnectivityResult` as the live/offline decision boundary: outdated for this phase because it does not prove Supabase reachability.

## Open Questions

1. **What are the current live `attendance_logs` insert permissions and uniqueness guarantees?**
   - What we know: the repo code assumes kiosk direct insert works today, and `SyncService` treats PostgreSQL `23505` on `local_id` as idempotent success.
   - What's unclear: the repo does not include the current `attendance_logs` RLS policy or unique-index definition for `local_id`.
   - Recommendation: verify the live table policy/index before planning rollout tasks, and include a post-RPC permission hardening step if anon direct insert is currently allowed.

2. **What is the minimal offline policy context the kiosk must cache?**
   - What we know: employee identity is cached locally, but break-first eligibility depends on Phase 55 schedule band plus Phase 54 contract data.
   - What's unclear: whether the kiosk will have Phase 55 schedule context locally by the time Phase 56 executes.
   - Recommendation: plan a compact per-employee daily scan-context cache rather than assuming the full scheduling layer is already available offline.

3. **Where should suspicious replay metadata live?**
   - What we know: later review must distinguish suspicious queued events from ordinary live scans, and the user left exact admin-review labeling flexible.
   - What's unclear: whether the app should use additive columns on `attendance_logs`, a sidecar audit table, or both.
   - Recommendation: prefer additive `attendance_logs` fields for Phase 56 so later recap and review code can read one source of truth, unless live-schema constraints force a sidecar table.

4. **Should the floating overlay pill also switch to authoritative time?**
   - What we know: the success screen is explicitly required to show authoritative WITA time for live scans, and `_pushAttendanceOverlayEvent()` still formats `DateTime.now()` locally.
   - What's unclear: whether the overlay pill is in scope for the same guarantee or can remain an approximate transient surface.
   - Recommendation: plan the success screen as mandatory and treat overlay alignment as a low-risk additive task if it does not slow the main path.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Widget/service tests and kiosk app changes | Yes | `3.41.1` | - |
| Dart SDK | Unit and SQL contract tests | Yes | `3.11.0` | - |
| Java runtime | Android builds and some Flutter tooling | Yes, but default is wrong for release work | `25.0.1` | Use the repo's Java 21 release contract tooling from Phase 47 for Android build tasks |
| Supabase project | RPC rollout and SQL migration target | Yes | Project `tmapxdftdhxovthgbhww`, status `ACTIVE_HEALTHY` from `.planning/STATE.md` | None |
| ADB | Device smoke checks if Phase 56 needs hardware validation | Yes | `36.0.2` | - |

**Validated tooling caveat:**
- Default `flutter test` from the repo path fails on this machine because a native asset hook is launched from a path with spaces under the default Pub cache.
- Validated fallback:
  ```powershell
  New-Item -ItemType Directory -Force C:\pub-cache | Out-Null
  cmd /c subst X: "C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter"
  $env:PUB_CACHE = 'C:\pub-cache'
  Set-Location X:\
  flutter test test/screens/kiosk/kiosk_scan_streak_test.dart
  ```
- This fallback was verified on 2026-03-27 with:
  - `test/screens/kiosk/kiosk_scan_streak_test.dart`
  - `test/services/pattern_detection_test.dart`
  - `test/phase51/sql_role_guard_contract_test.dart`

**Missing dependencies with no fallback:**
- None for planning or source-level implementation.

**Missing dependencies with fallback:**
- Default test execution from the workspace path. Use the validated `subst` + `PUB_CACHE` workaround above.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` on Flutter `3.41.1` / Dart `3.11.0` |
| Config file | none dedicated; default Flutter test conventions plus `analysis_options.yaml` |
| Quick run command | `$env:PUB_CACHE='C:\pub-cache'; cmd /c subst X: "C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter"; Set-Location X:\; flutter test test/screens/kiosk/kiosk_scan_streak_test.dart` |
| Full suite command | `$env:PUB_CACHE='C:\pub-cache'; cmd /c subst X: "C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter"; Set-Location X:\; flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| `SCAN-01` | Live kiosk scans use server-stamped WITA time; queued scans preserve event order and auto-sync on connectivity restore | unit + SQL contract + widget | `$env:PUB_CACHE='C:\pub-cache'; cmd /c subst X: "C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter"; Set-Location X:\; flutter test test/phase56/server_time_scan_sql_contract_test.dart` | No, Wave 0 |
| `SCAN-02` | Eligible first scans offer break-first confirmation, store explicit intent, and preserve that intent for later recap input | widget + unit + SQL contract | `$env:PUB_CACHE='C:\pub-cache'; cmd /c subst X: "C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter"; Set-Location X:\; flutter test test/screens/kiosk/kiosk_scan_server_time_test.dart` | No, Wave 0 |

### Sampling Rate
- **Per task commit:** targeted Phase 56 test file through the validated `subst` + `PUB_CACHE` command.
- **Per wave merge:** `flutter test` through the validated fallback command.
- **Phase gate:** full `flutter test` plus one manual Supabase smoke on a real kiosk path before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `test/services/kiosk_scan_authority_service_test.dart` - covers server-context fetch, live insert response mapping, and queued/live state branching.
- [ ] `test/services/sync_service_order_test.dart` - proves sequential or ordered replay and review-flag handling.
- [ ] `test/screens/kiosk/kiosk_scan_server_time_test.dart` - covers break-first prompt, confirmation path, live vs queued success UI, and uncached-offline messaging.
- [ ] `test/phase56/server_time_scan_sql_contract_test.dart` - guards the new migration/RPC shape, grants, and WITA timestamp semantics.

## Sources

### Primary (HIGH confidence)
- Local repo: `lib/screens/kiosk/kiosk_scan_screen.dart` - current kiosk scan submission, server-only last-type lookup, success-state behavior.
- Local repo: `lib/screens/kiosk/kiosk_idle_screen.dart` - employee cache fast path, slow-path offline behavior, pending badge/banner.
- Local repo: `lib/services/sqlite_service.dart` - queue schema, migrations, current ordering contract.
- Local repo: `lib/services/sync_service.dart` - current replay logic and parallel upload behavior.
- Local repo: `lib/services/heartbeat_service.dart` - connectivity listener that retries heartbeats but not queue sync.
- Local repo: `sql/phase_42_portal_attendance_recap_20260323.sql` - existing WITA projection and server-side logical-day pattern.
- PostgreSQL current docs: https://www.postgresql.org/docs/current/functions-datetime.html - `AT TIME ZONE`, `CURRENT_TIMESTAMP`, `statement_timestamp()`, `clock_timestamp()`, and `now()` semantics.
- PostgreSQL current docs: https://www.postgresql.org/docs/current/datatype-datetime.html - timezone-aware timestamp storage in UTC.
- Supabase Dart docs: https://supabase.com/docs/reference/dart/rpc - Flutter/Dart RPC calling pattern.
- `pub.dev` package pages:
  - https://pub.dev/packages/supabase_flutter
  - https://pub.dev/packages/sqflite
  - https://pub.dev/packages/connectivity_plus
  - https://pub.dev/packages/flutter_riverpod
  - https://pub.dev/packages/go_router
  - https://pub.dev/packages/shared_preferences

### Secondary (MEDIUM confidence)
- `.planning/phases/55-schedule-policy-absence-rules/55-RESEARCH.md` - dependency contract for shift bands, lateness cutoffs, and break-first windows. Medium confidence because Phase 55 is planned, not yet executed in source.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - existing repo stack plus official package/docs verification, with no new dependency recommendation.
- Architecture: MEDIUM - the required direction is clear, but the exact live `attendance_logs` schema/RLS contract is not present in the repo and Phase 55 is still a dependency artifact.
- Pitfalls: HIGH - every major pitfall is directly evidenced by current code or by official docs.

**What might I have missed?**
- The live Supabase definition of `attendance_logs`, especially RLS and unique constraints, is not in this repo.
- The exact Phase 55 implementation details may shift the best place to source break-first eligibility context once that phase is executed.

**Research date:** 2026-03-27
**Valid until:** 2026-04-26
