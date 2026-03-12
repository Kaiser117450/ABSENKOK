# Phase 16: Persistent Live Activity Pill - Research

**Researched:** 2026-03-12
**Domain:** Flutter overlay data pipeline, Supabase polling, Android overlay stability
**Confidence:** HIGH

## Summary

Phase 16 extends the **already-built** Dynamic Island overlay pill to show live data: break status (employee names currently on break) and rotating idle content (attendance stats + motivational messages). The overlay infrastructure is 100% functional from v1.1 — `overlay_task.dart` (574 lines), `OverlayPillState` model, `KioskBackgroundService` with `_rotateTimer` (5s) and `shareData()` pipeline. The work is purely **data-driven**: adding a Supabase polling timer (30s) in the main isolate, building content pools (break names, fun facts), and pushing rotated content through the existing `shareData()` pipeline.

The critical architectural constraint is the **isolate boundary**: the overlay UI runs in a separate Dart isolate and **cannot** access Supabase directly. All data must flow through `FlutterOverlayWindow.shareData()` as serialized strings. This means the main isolate (KioskBackgroundService) must poll Supabase, compute the content pool, and push pre-formatted text to the overlay every 5 seconds. The overlay remains a dumb renderer.

**Primary recommendation:** Add a 30-second Supabase polling timer to `KioskBackgroundService`, build a `LiveContentProvider` service class that computes break names and fun-fact pools, and modify `_rotateNotification()` to cycle through the content pool every 5s via the existing `_rotateTimer`. Reuse `OverlayPillState.attendanceType` field to carry arbitrary display text (break names, stats). No new packages needed.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Break Status Display (LIVE-02):** When employee(s) on break, rotate individual names in attendance label. Format: "🍽️ Budi istirahat" → "🍽️ Sari istirahat". Rotation speed: 5 seconds (matches existing `_rotateTimer`). Break detection: query attendance_logs for today's `type = 'istirahat'` without subsequent `type = 'kembali'` for same employee.
- **Fun Facts / Idle Messages (LIVE-03):** Mix of live stats + motivational messages interleaved. 3-5 live stats from Supabase (e.g. "Hari ini 12/14 hadir 🎉", attendance rate, earliest arrival). 3-5 fixed motivational messages (e.g. "Semangat kerja! 💪"). Rotate every 5 seconds in the attendance label area. Stats refresh every 30 seconds (cached between refreshes).
- **Update Frequency (LIVE-04):** Supabase polling interval: 30 seconds. Display rotation: 5 seconds (using cached data from last poll). On NFC scan event: immediately push event overlay (existing behavior), then revert to break/idle after eventUntilEpochMs expires.
- **Data Flow Architecture:** Main app polls Supabase every 30s via existing `SupabaseClientFactory.admin`. Build fun facts pool (stats + motivational) and break names list. Push to overlay via `FlutterOverlayWindow.shareData()` every 5s with rotated content. Overlay isolate remains stateless — just renders what it receives. `OverlayPillState.attendanceType` carries the current display text.

### Claude's Discretion
- Exact Supabase query structure for break detection
- How to determine "on break" vs "returned from break"
- Exact motivational messages (Indonesian, positive, work-appropriate)
- Error handling for failed Supabase polls (use last cached data)
- Whether to extend OverlayPillState model or reuse existing fields

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LIVE-01 | Persistent Dynamic Island-style overlay pill visible outside the app when kiosk is running | **Already implemented** in v1.1 (overlay_task.dart + KioskBackgroundService). No new work needed — verify existing functionality works. |
| LIVE-02 | Overlay pill shows real-time break status (nama karyawan yang sedang istirahat) | Supabase query for break detection + content rotation in _rotateNotification(). Use attendanceType field for "🍽️ Budi istirahat" text. |
| LIVE-03 | Overlay pill shows fun facts / rotating idle messages when no one is on break | LiveContentProvider builds pool of stats + motivational messages, cached 30s. Push via attendanceType field. |
| LIVE-04 | Overlay pill updates automatically without user interaction | Extend KioskBackgroundService with 30s poll timer + modify existing 5s _rotateTimer to push content. |

</phase_requirements>

## Standard Stack

### Core (Already in Project)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| flutter_overlay_window | ^0.5.0 | System-wide floating overlay (SYSTEM_ALERT_WINDOW) | ✅ Already installed |
| flutter_foreground_task | ^8.14.0 | Foreground service to keep kiosk alive | ✅ Already installed |
| supabase_flutter | ^2.8.4 | Backend queries for break/attendance data | ✅ Already installed |
| flutter_riverpod | ^2.6.1 | State management | ✅ Already installed |
| intl | ^0.19.0 | Date formatting | ✅ Already installed |

### New Dependencies
**None.** This phase requires zero new packages. All functionality is built on existing infrastructure.

## Architecture Patterns

### Existing Data Flow (Unchanged)
```
┌─────────────────────────┐         ┌─────────────────────┐
│    MAIN ISOLATE          │         │  OVERLAY ISOLATE     │
│                          │         │  (overlay_task.dart)  │
│  KioskBackgroundService  │         │                      │
│   ├─ _rotateTimer (5s)   │──share──│  KioskOverlayUI      │
│   ├─ _pollTimer (30s)  ★ │  Data() │  (dumb renderer)     │
│   └─ _session            │         │                      │
│                          │         │                      │
│  SupabaseClientFactory   │         │  ❌ NO Supabase      │
│   └─ .admin (queries)    │         │  ❌ NO direct data   │
└─────────────────────────┘         └─────────────────────┘
                                     ★ = new addition
```

### New Data Flow for Phase 16
```
Every 30 seconds (_pollTimer):
  1. Query Supabase: today's attendance_logs (type, employee name)
  2. Query Supabase: active employee count for outlet
  3. Compute:
     a. breakNames: employees with 'break' type and no subsequent 'kembali'
     b. funFacts: live stats + fixed motivational messages
  4. Cache results in memory

Every 5 seconds (_rotateTimer, already exists):
  1. Check event mode → if active, skip (existing NFC event takes priority)
  2. If breakNames not empty → rotate to next break name
  3. Else → rotate to next fun fact
  4. Build OverlayPillState with rotated content
  5. Push via shareData()
```

### Recommended Project Structure
```
lib/
├── services/
│   ├── kiosk_background_service.dart   # MODIFY: add _pollTimer, content rotation
│   └── live_content_provider.dart      # NEW: break detection + fun facts builder
├── models/
│   └── overlay_pill_state.dart         # UNCHANGED (reuse attendanceType field)
└── overlay_task.dart                   # UNCHANGED (dumb renderer)
```

### Pattern 1: LiveContentProvider (Pure Dart Service)
**What:** Stateless service class that queries Supabase and computes content pools
**When to use:** Every 30 seconds from KioskBackgroundService._pollTimer

```dart
// lib/services/live_content_provider.dart
class LiveContentProvider {
  /// Cached content pool — survives between poll intervals
  List<String> _breakNames = [];
  List<String> _funFacts = _defaultMotivationalMessages;
  int _breakIndex = 0;
  int _funFactIndex = 0;
  DateTime? _lastPollAt;

  /// Returns the next display text for the overlay attendance label.
  /// Rotates between break names (priority) or fun facts (idle).
  String nextDisplayText() {
    if (_breakNames.isNotEmpty) {
      final name = _breakNames[_breakIndex % _breakNames.length];
      _breakIndex++;
      return '🍽️ $name istirahat';
    }
    final fact = _funFacts[_funFactIndex % _funFacts.length];
    _funFactIndex++;
    return fact;
  }

  /// Poll Supabase for break status and attendance stats.
  /// Called every 30 seconds. On error, keeps last cached data.
  Future<void> poll(String outletId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day)
          .toUtc().toIso8601String();

      // Single query: all today's attendance logs with employee names
      final data = await SupabaseClientFactory.kiosk
          .from('attendance_logs')
          .select('employee_id, type, scanned_at, employees(name)')
          .gte('scanned_at', startOfDay)
          .order('scanned_at', ascending: true);

      _computeBreakNames(data as List);
      await _computeFunFacts(data as List, outletId);
      _lastPollAt = now;
    } catch (e) {
      // Keep last cached data — don't clear on error
      debugPrint('[LiveContent] poll error: $e');
    }
  }

  void _computeBreakNames(List logs) {
    // Group by employee_id, check for 'break' without subsequent 'kembali'
    final Map<String, ({String name, bool onBreak})> employees = {};
    for (final log in logs) {
      final empId = log['employee_id'] as String;
      final type = log['type'] as String;
      final empData = log['employees'] as Map<String, dynamic>?;
      final name = empData?['name'] as String? ?? '-';

      if (type == 'break') {
        employees[empId] = (name: name, onBreak: true);
      } else if (type == 'kembali') {
        final existing = employees[empId];
        if (existing != null) {
          employees[empId] = (name: existing.name, onBreak: false);
        }
      }
    }

    _breakNames = employees.entries
        .where((e) => e.value.onBreak)
        .map((e) => e.value.name)
        .toList();
  }

  static const _defaultMotivationalMessages = [
    'Semangat kerja! 💪',
    'Terima kasih sudah tepat waktu 🙏',
    'Kerja keras, hasil manis 🍯',
    'Tim terbaik! ⭐',
    'Satu tim, satu semangat 🤝',
  ];
}
```

### Pattern 2: Extending _rotateNotification() in KioskBackgroundService
**What:** Modify the existing 5-second rotation to push live content
**When to use:** Every time the rotate timer fires

```dart
// In KioskBackgroundService (kiosk_background_service.dart)

static final LiveContentProvider _liveContent = LiveContentProvider();
static Timer? _pollTimer;

// In start():
_pollTimer?.cancel();
_pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
  _pollContent();
});
// First poll immediately
_pollContent();

static Future<void> _pollContent() async {
  final session = _session;
  if (session == null) return;
  await _liveContent.poll(session.outletId);
}

// Modified _rotateNotification:
static Future<void> _rotateNotification() async {
  final session = _session;
  if (session == null) return;

  final now = DateTime.now();
  final timeStr = _formatClock(now);

  // Get next display text from live content provider
  final displayText = _liveContent.nextDisplayText();
  final hasBreak = _liveContent.hasActiveBreaks;

  // Determine accent color: amber for break, green for idle
  final accentHex = hasBreak ? '#F59E0B' : '#22C55E';

  // Build overlay state
  final overlayState = OverlayPillState(
    mode: OverlayPillMode.idle,
    outlet: session.outletName,
    time: timeStr,
    attendanceType: displayText, // reuse field for arbitrary text
    accentHex: accentHex,
    eventUntilEpochMs: 0,
    expanded: true,
  );

  await updateOverlayState(overlayState);
  await updateLiveNotification(outletName: session.outletName, body: displayText);

  FlutterForegroundTask.updateService(
    notificationTitle: session.outletName,
    notificationText: displayText,
  );
}
```

### Pattern 3: Break Detection Query (Supabase)
**What:** Determine which employees are currently on break
**Logic:** Employee has `type = 'break'` log today with NO subsequent `type = 'kembali'` log

```dart
// Query: all today's attendance logs, ordered ascending
final data = await SupabaseClientFactory.kiosk
    .from('attendance_logs')
    .select('employee_id, type, scanned_at, employees(name)')
    .gte('scanned_at', startOfDay)
    .order('scanned_at', ascending: true);

// Process: iterate chronologically, track break state per employee
final Map<String, ({String name, bool onBreak})> state = {};
for (final log in data) {
  final empId = log['employee_id'];
  final type = log['type'];  // 'masuk', 'break', 'pulang', 'kembali'
  final name = log['employees']?['name'] ?? '';

  if (type == 'break') {
    state[empId] = (name: name, onBreak: true);
  } else if (type == 'kembali' && state[empId]?.onBreak == true) {
    state[empId] = (name: name, onBreak: false);
  }
}

final onBreak = state.values.where((s) => s.onBreak).map((s) => s.name).toList();
```

**Critical DB note:** The `type` column in `attendance_logs` stores `'break'` (not `'istirahat'`), matching `AttendanceType.breakTime.value` → `'break'`. The UI label is `'Istirahat'` but the DB value is `'break'`.

### Pattern 4: Fun Facts Builder with Live Stats
**What:** Mix live attendance stats with fixed motivational messages
**When to use:** When no employees are on break (idle mode)

```dart
Future<List<String>> _buildFunFacts(List logs, String outletId) async {
  final stats = <String>[];

  // Stat 1: Today's attendance count
  final uniqueMasuk = logs
      .where((l) => l['type'] == 'masuk')
      .map((l) => l['employee_id'])
      .toSet();

  // Get total active employees for this outlet
  final totalEmployees = await SupabaseClientFactory.kiosk
      .from('employees')
      .select('id')
      .eq('home_outlet_id', outletId)
      .eq('is_active', true);
  final total = (totalEmployees as List).length;

  if (total > 0) {
    stats.add('Hari ini ${uniqueMasuk.length}/$total hadir 🎉');
  }

  // Stat 2: Attendance rate percentage
  if (total > 0) {
    final rate = ((uniqueMasuk.length / total) * 100).round();
    stats.add('Kehadiran hari ini $rate% 📊');
  }

  // Stat 3: Earliest arrival
  final masukLogs = logs.where((l) => l['type'] == 'masuk').toList();
  if (masukLogs.isNotEmpty) {
    final earliest = masukLogs.first; // already sorted ascending
    final name = earliest['employees']?['name'] ?? '';
    final time = _extractTime(earliest['scanned_at']);
    if (name.isNotEmpty) {
      stats.add('$name datang pertama $time 🏆');
    }
  }

  // Interleave stats with motivational messages
  final mixed = <String>[];
  final motivational = [..._defaultMotivationalMessages];
  int si = 0, mi = 0;
  while (si < stats.length || mi < motivational.length) {
    if (si < stats.length) mixed.add(stats[si++]);
    if (mi < motivational.length) mixed.add(motivational[mi++]);
  }

  return mixed.isNotEmpty ? mixed : _defaultMotivationalMessages;
}
```

### Anti-Patterns to Avoid
- **Direct Supabase access from overlay isolate:** The overlay runs in a separate Dart isolate. It CANNOT import or use `SupabaseClientFactory`. All data must come through `shareData()`.
- **Supabase Realtime in kiosk mode:** Realtime channels work in admin dashboard (same isolate) but are unnecessary for 30s polling. Polling is simpler, more reliable, and matches the CONTEXT.md decision.
- **Storing content state in the overlay:** The overlay must remain stateless — it renders whatever payload arrives. Don't add timers or caching in `overlay_task.dart`.
- **Frequent Supabase queries (< 30s):** Battery drain risk on kiosk tablets running 24/7. 30s is the locked decision.
- **Creating new Dart isolates for polling:** The KioskBackgroundService already runs in the main isolate. Use a simple `Timer.periodic` — no need for `Isolate.spawn` or compute().

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Overlay window | Custom platform channel for window | `flutter_overlay_window` ^0.5.0 | Already integrated, handles SYSTEM_ALERT_WINDOW permission, OEM fallbacks built |
| Foreground service | Custom Android service | `flutter_foreground_task` ^8.14.0 | Already handles battery optimization, wake lock, service lifecycle |
| Date/time formatting | Manual string formatting | `intl` ^0.19.0 (or existing `_formatClock()`) | Already in use; consistent formatting |
| JSON serialization | Custom string encoding | `OverlayPillState.toWirePayload()` / `fromRaw()` | Already handles v1 JSON + legacy delimiter formats |
| Break state machine | Complex FSM library | Simple map iteration over chronological logs | 14 employees × 4 log types = trivially small data set |

**Key insight:** This phase adds ZERO new packages. The entire implementation is plumbing existing infrastructure together with new data queries.

## Common Pitfalls

### Pitfall 1: AttendanceType.breakTime.value is 'break' not 'istirahat'
**What goes wrong:** Querying for `type = 'istirahat'` returns zero results. The CONTEXT.md mentions "istirahat" but the actual DB column value is `'break'`.
**Why it happens:** The `AttendanceType.breakTime.value` returns `'break'` (see attendance_log.dart line 30). The label `'Istirahat'` is UI-only (line 47).
**How to avoid:** Always use `AttendanceType.breakTime.value` (which returns `'break'`) when constructing Supabase queries. Display "istirahat" in the pill text only.
**Warning signs:** Break detection returns empty list even when employees are on break.

### Pitfall 2: Event Mode Priority Conflict
**What goes wrong:** NFC scan event overlay gets immediately overwritten by the next 5-second rotation.
**Why it happens:** `_rotateNotification()` fires every 5s. If an NFC scan just pushed an event overlay, the rotate timer will push idle content over it.
**How to avoid:** Check `_currentState.mode == OverlayPillMode.event` in `_rotateNotification()` and skip if an event is active. The overlay already handles `isEventExpiredAt()` — just don't push new idle content during active events.
**Warning signs:** NFC scan notification flashes briefly then disappears.

### Pitfall 3: Memory Growth from Unbounded Lists
**What goes wrong:** Content lists grow indefinitely over 24+ hours of operation.
**Why it happens:** Each poll adds to lists without clearing old data.
**How to avoid:** Replace lists completely on each poll (don't append). Use fixed-size motivational message list. The break names list naturally resets because it's recomputed from scratch each poll.
**Warning signs:** Memory profiler shows steady growth over hours.

### Pitfall 4: Timer Leak on Stop
**What goes wrong:** `_pollTimer` continues firing after `KioskBackgroundService.stop()` is called.
**Why it happens:** New timer not cleaned up in `stop()`.
**How to avoid:** Add `_pollTimer?.cancel(); _pollTimer = null;` to the `stop()` method, alongside existing `_rotateTimer?.cancel()`.
**Warning signs:** Supabase queries continue after kiosk session ends; debugPrint shows poll logs after stop.

### Pitfall 5: Supabase Query Scope (Outlet Filtering)
**What goes wrong:** Break status shows employees from ALL outlets, not just the kiosk's outlet.
**Why it happens:** Query doesn't filter by `scan_outlet_id`.
**How to avoid:** Always filter attendance_logs by `scan_outlet_id = session.outletId`. Each kiosk tablet is bound to one outlet via `KioskSession`.
**Warning signs:** Pill shows employee names from other outlets.

### Pitfall 6: UTC vs Local Time in Date Boundaries
**What goes wrong:** "Today's" attendance query misses morning logs or includes yesterday's night logs.
**Why it happens:** `scanned_at` is stored in UTC. "Start of day" must also be UTC.
**How to avoid:** Follow existing pattern from `admin_dashboard_screen.dart`: `DateTime(now.year, now.month, now.day).toUtc().toIso8601String()`.
**Warning signs:** Stats show wrong numbers at start/end of day.

### Pitfall 7: _resolveStyle() Parsing Arbitrary Text
**What goes wrong:** The overlay's `_resolveStyle()` method calls `AttendanceTypeExt.fromString()` on the attendanceType field. If we pass arbitrary text like "🍽️ Budi istirahat", it won't match any enum value and defaults to `AttendanceType.masuk`.
**Why it happens:** The existing code expects attendanceType to be one of: masuk, break, pulang, kembali, sakit, izin.
**How to avoid:** Two options: (1) Override `_resolveStyle()` in the overlay to handle non-enum text by using a custom label directly, or (2) Add a new field to OverlayPillState for custom display text and keep attendanceType for accent color resolution. **Recommendation: Option 2** — add a `displayLabel` field to OverlayPillState to carry arbitrary text, keep `attendanceType` for accent color. This is backward-compatible and keeps the color system working.
**Warning signs:** Pill always shows "Masuk" label and green accent regardless of content.

## Code Examples

### Example 1: Extending OverlayPillState with displayLabel
```dart
// In overlay_pill_state.dart — add displayLabel field
class OverlayPillState {
  // ... existing fields ...
  final String displayLabel; // NEW: custom text for attendance label area

  const OverlayPillState({
    // ... existing params ...
    this.displayLabel = '', // empty = use attendanceType enum label (backward compat)
  });

  // In fromMap:
  final displayLabelValue = (map['displayLabel'] ?? '').toString().trim();

  // In toMap:
  'displayLabel': displayLabel,
}
```

### Example 2: Overlay Rendering with displayLabel
```dart
// In overlay_task.dart — _resolveStyle()
_OverlayVisualStyle _resolveStyle() {
  final attendanceType = AttendanceTypeExt.fromString(
    _currentState.attendanceType.toLowerCase(),
  );
  final accent = _parseAccentHex(_currentState.accentHex, attendanceType.color);

  // Use displayLabel if non-empty, otherwise fall back to enum label
  final label = _currentState.displayLabel.isNotEmpty
      ? _currentState.displayLabel
      : attendanceType.label;

  final modeLabel = _currentState.mode == OverlayPillMode.event
      ? 'Event aktif' : 'Kiosk aktif';

  return _OverlayVisualStyle(
    attendanceLabel: label,
    modeLabel: modeLabel,
    accent: accent,
  );
}
```

### Example 3: Poll Timer Setup in KioskBackgroundService
```dart
// In KioskBackgroundService.start()
static final LiveContentProvider _liveContent = LiveContentProvider();
static Timer? _pollTimer;

static Future<OverlayShowResult> start(KioskSession session) async {
  // ... existing start code ...

  // NEW: start content poll timer (30s)
  _pollTimer?.cancel();
  _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    _pollContent();
  });
  // Immediate first poll
  unawaited(_pollContent());

  // ... rest of existing start code ...
}

static Future<void> stop() async {
  _pollTimer?.cancel();  // NEW: clean up poll timer
  _pollTimer = null;
  _rotateTimer?.cancel();
  _rotateTimer = null;
  _session = null;
  // ... rest of existing stop code ...
}
```

### Example 4: Modified _rotateNotification with Content Awareness
```dart
static Future<void> _rotateNotification() async {
  final session = _session;
  if (session == null) return;

  final now = DateTime.now();
  final timeStr = _formatClock(now);

  // Get next display content from live content provider
  final displayText = _liveContent.nextDisplayText();
  final hasBreak = _liveContent.hasActiveBreaks;

  // Accent: amber when someone is on break, green otherwise
  final accentHex = hasBreak ? '#F59E0B' : '#22C55E';
  // attendanceType: 'break' for amber accent, 'masuk' for green
  final attendanceType = hasBreak ? 'break' : 'masuk';

  final idleOverlayState = OverlayPillState(
    mode: OverlayPillMode.idle,
    outlet: session.outletName,
    time: timeStr,
    attendanceType: attendanceType, // drives accent color
    accentHex: accentHex,
    displayLabel: displayText,      // drives display text
    eventUntilEpochMs: 0,
    expanded: true,
  );

  await updateOverlayState(idleOverlayState);

  // Also update notification bar
  await updateLiveNotification(
    outletName: session.outletName,
    body: displayText,
  );

  FlutterForegroundTask.updateService(
    notificationTitle: session.outletName,
    notificationText: displayText,
  );
}
```

## State of the Art

| Old Approach (v1.1) | New Approach (Phase 16) | Impact |
|---------------------|------------------------|--------|
| Static "Masuk"/"Istirahat" label from NFC events | Dynamic rotating content from Supabase poll | Pill always shows relevant, fresh content |
| Simple toggle between outlet name & time | Content pool rotation (breaks > stats > motivational) | "Feels alive" per user request |
| No Supabase polling in background service | 30s poll timer for attendance data | Minimal battery impact, real-time break visibility |
| attendanceType drives both label AND accent | New displayLabel for text, attendanceType for accent | Clean separation of concerns |

## Open Questions

1. **Outlet-scoped vs global break visibility**
   - What we know: KioskSession has `outletId`. Dashboard filters by outlet for kepala gerai.
   - What's unclear: Should the pill only show breaks from THIS outlet, or all outlets?
   - Recommendation: Filter by `scan_outlet_id = session.outletId` — each kiosk shows its own outlet's data. This matches the 1-kiosk-per-outlet model and keeps queries fast.

2. **Employee count for "X/Y hadir" stat**
   - What we know: Admin dashboard queries `employees.is_active = true` and optionally filters by `home_outlet_id`.
   - What's unclear: Should kiosk use `home_outlet_id` filter? Backup employees scan at non-home outlets.
   - Recommendation: Use `home_outlet_id = session.outletId` for the total denominator, and count unique `employee_id` from today's `masuk` logs at this outlet for the numerator. This gives "local team attendance" perspective.

3. **What happens during first 30 seconds before first poll?**
   - What we know: Poll timer fires immediately on start, but the Supabase query takes time.
   - What's unclear: What should the pill show before first poll completes?
   - Recommendation: Default to existing behavior — show outlet name + "Masuk" label + clock. The first poll result arrives within 1-3 seconds; the next 5s rotation will pick it up.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built into Flutter SDK) |
| Config file | `analysis_options.yaml` (existing) |
| Quick run command | `flutter test test/models/ test/services/ test/widgets/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LIVE-01 | Overlay pill visible outside app | manual-only | N/A (requires physical device with SYSTEM_ALERT_WINDOW) | N/A |
| LIVE-02 | Break status shows in pill | unit | `flutter test test/services/live_content_provider_test.dart -x` | ❌ Wave 0 |
| LIVE-02 | Break name rotation | unit | `flutter test test/services/live_content_provider_test.dart -x` | ❌ Wave 0 |
| LIVE-02 | Overlay renders displayLabel | widget | `flutter test test/widgets/overlay_pill_widget_test.dart -x` | ✅ Extend existing |
| LIVE-03 | Fun facts + stats generation | unit | `flutter test test/services/live_content_provider_test.dart -x` | ❌ Wave 0 |
| LIVE-03 | Idle message rotation | unit | `flutter test test/services/live_content_provider_test.dart -x` | ❌ Wave 0 |
| LIVE-04 | Auto-update without interaction | unit | `flutter test test/services/live_content_provider_test.dart -x` | ❌ Wave 0 |
| LIVE-04 | Event mode priority | widget | `flutter test test/widgets/overlay_pill_widget_test.dart -x` | ✅ Extend existing |

### Sampling Rate
- **Per task commit:** `flutter test test/models/overlay_pill_state_test.dart test/services/live_content_provider_test.dart test/widgets/overlay_pill_widget_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/services/live_content_provider_test.dart` — covers LIVE-02, LIVE-03, LIVE-04 (break detection, fun facts, rotation logic)
- [ ] Extend `test/models/overlay_pill_state_test.dart` — covers displayLabel serialization round-trip
- [ ] Extend `test/widgets/overlay_pill_widget_test.dart` — covers displayLabel rendering in pill UI

*(No new framework install needed — flutter_test already present)*

## Sources

### Primary (HIGH confidence)
- **Codebase inspection** — `lib/overlay_task.dart` (574 lines), `lib/models/overlay_pill_state.dart` (149 lines), `lib/services/kiosk_background_service.dart` (581 lines), `lib/models/attendance_log.dart` (167 lines)
- **Codebase inspection** — `lib/screens/kiosk/kiosk_scan_screen.dart` (overlay event push pattern, lines 217-244)
- **Codebase inspection** — `lib/screens/admin/admin_dashboard_screen.dart` (Supabase attendance query patterns, open shift detection, lines 114-212)
- **Codebase inspection** — `lib/core/supabase_client.dart` (SupabaseClientFactory.admin/kiosk)
- **Codebase inspection** — `android/app/src/main/AndroidManifest.xml` (SYSTEM_ALERT_WINDOW permission, foreground service config)
- **Codebase inspection** — Kotlin files (`KioskNotificationHelper.kt`, `MainActivity.kt`)
- **Codebase inspection** — Test files (`test/models/overlay_pill_state_test.dart`, `test/widgets/overlay_pill_widget_test.dart`)

### Secondary (MEDIUM confidence)
- **`liveaction.md`** (43KB reference guide) — best practices section: keep updates meaningful, avoid > 1/sec updates, handle offline gracefully, end activities promptly
- **`16-CONTEXT.md`** — user decisions on rotation speed, poll interval, data flow architecture

### Tertiary (LOW confidence)
- None — all findings verified from codebase inspection

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — zero new packages, all libraries already in use and verified in pubspec.yaml
- Architecture: **HIGH** — extends existing patterns visible in codebase (KioskBackgroundService._rotateTimer, admin_dashboard Supabase queries, overlay shareData pipeline)
- Pitfalls: **HIGH** — identified from actual code inspection (AttendanceType.breakTime.value = 'break', _resolveStyle enum parsing, timer cleanup patterns)
- Break detection: **HIGH** — same pattern as admin_dashboard open shift detection (group by employee, chronological scan)
- 24/7 stability: **MEDIUM** — memory growth prevention (replace lists, don't append) is standard practice but needs real-device validation over 24+ hours

**Research date:** 2026-03-12
**Valid until:** 2026-04-12 (stable domain, no external dependency changes expected)
