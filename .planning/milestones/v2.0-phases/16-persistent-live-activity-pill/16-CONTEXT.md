# Phase 16: Persistent Live Activity Pill - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the existing overlay pill to show real-time break status and rotating idle fun facts. The overlay infrastructure (overlay_task.dart, KioskBackgroundService, OverlayPillState) already exists from v1.1. This phase adds data-driven content: break names, attendance stats, and motivational messages.

Requirements: LIVE-01 (already done — pill exists), LIVE-02, LIVE-03, LIVE-04.

</domain>

<decisions>
## Implementation Decisions

### Break Status Display (LIVE-02)
- When employee(s) on break: rotate individual names in attendance label
- Format: "🍽️ Budi istirahat" → "🍽️ Sari istirahat" (rotating)
- Rotation speed: 5 seconds (matches existing _rotateTimer)
- Break detection: query attendance_logs for today's `type = 'istirahat'` without a subsequent `type = 'kembali'` for same employee

### Fun Facts / Idle Messages (LIVE-03)
- Mix of live stats + motivational messages interleaved
- 3-5 live stats from Supabase: e.g. "Hari ini 12/14 hadir 🎉", attendance rate, earliest arrival
- 3-5 fixed motivational messages: e.g. "Semangat kerja! 💪", etc.
- Rotate every 5 seconds in the attendance label area
- Stats refresh every 30 seconds (cached between refreshes)

### Update Frequency (LIVE-04)
- Supabase polling interval: 30 seconds
- Display rotation: 5 seconds (using cached data from last poll)
- On NFC scan event: immediately push event overlay (existing behavior), then revert to break/idle after eventUntilEpochMs expires

### Data Flow Architecture
- Main app polls Supabase every 30s via existing SupabaseClientFactory.admin
- Build fun facts pool (stats + motivational) and break names list
- Push to overlay via FlutterOverlayWindow.shareData() every 5s with rotated content
- Overlay isolate remains stateless — just renders what it receives
- OverlayPillState.attendanceType carries the current display text

### Claude's Discretion
- Exact Supabase query structure for break detection
- How to determine "on break" vs "returned from break"
- Exact motivational messages (Indonesian, positive, work-appropriate)
- Error handling for failed Supabase polls (use last cached data)
- Whether to extend OverlayPillState model or reuse existing fields

</decisions>

<specifics>
## Specific Ideas

- User wants it to feel alive — the pill should always show something interesting
- Break names rotation gives a human touch (seeing colleague names)
- Stats like "Hari ini 12/14 hadir 🎉" give at-a-glance visibility
- Must NOT increase battery drain significantly (30s poll, not realtime subscription)

</specifics>

<code_context>
## Existing Code Insights

### Overlay Infrastructure (v1.1 — fully built)
- `lib/overlay_task.dart` (574 lines) — KioskOverlayUI with idle/event modes, expand/collapse, animations
- `lib/models/overlay_pill_state.dart` (149 lines) — State model with mode, outlet, time, attendanceType, accentHex, badgeEmoji
- `lib/services/kiosk_background_service.dart` — start/stop/ensureOverlayVisible/updateOverlayState/hideOverlay

### Data Push Pipeline
- `KioskBackgroundService._rotateTimer` fires every 5s → calls `_rotateNotification()`
- `updateOverlayState(state)` → `FlutterOverlayWindow.shareData(state.toWirePayload())`
- Overlay receives via `FlutterOverlayWindow.overlayListener` stream

### Break Tracking in DB
- `attendance_logs` table: `employee_id`, `type` (masuk/pulang/istirahat/kembali), `timestamp`
- "On break" = has `istirahat` log today without subsequent `kembali` log
- `AttendanceType` enum: masuk, pulang, istirahat, kembali (lib/models/attendance_log.dart)

### Key Constraint
- Overlay runs in separate Dart isolate → NO direct Supabase access
- All data must flow through shareData() string serialization
- KioskBackgroundService is in MAIN isolate → CAN access Supabase

### Integration Points
- `_rotateTimer` (5s) in KioskBackgroundService — extend to push break/fun-fact data
- Add separate 30s poll timer for Supabase queries
- `OverlayPillState.attendanceType` → currently carries "Masuk"/"Istirahat" etc., extend to carry fun facts
- `kiosk_scan_screen.dart` calls `updateOverlayState()` on each NFC scan → event mode takes priority

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 16-persistent-live-activity-pill*
*Context gathered: 2026-03-12*
