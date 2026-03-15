# Phase 3: Overlay Pill Implementation - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement a persistent live-activity style floating pill overlay (Dynamic-Island-like) that remains visible above other apps when Absensi Enakko is minimized/backgrounded.  
Existing scan-success notification flow already exists and should not be the main target of this phase revision.

</domain>

<decisions>
## Implementation Decisions

### Persistent Overlay Behavior
- Primary behavior is persistent overlay in background/minimized state, not scan-trigger-only overlay.
- Pill stays visible above other apps and can be toggled between expanded/minimized by tap.
- When scan-event presentation appears, it should return to persistent idle state (not fully disappear).
- Overlay visibility while app is foregrounded should be user-configurable (toggle setting).

### Visual Hierarchy and Content
- Use compact 2-line density for expanded presentation.
- Keep identity as text + brand micro-logo (no employee avatar requirement).
- Show attendance type with accent color and keep it visible in persistent state.
- Time format should remain local `HH:mm`.

### Motion and Transitions
- Keep slide-down + fade with subtle spring feel for event/state transitions.
- Existing event entrance implementation is considered already handled; do not re-scope heavily into scan animation redesign.
- Prioritize stable persistent behavior over adding new decorative continuous motion.

### Permission and Failure Handling
- If overlay permission is denied, show guided re-enable prompt (including OEM-specific guidance).
- Re-check overlay permission on each kiosk start for reliability on OEM-modified Android.
- Trigger persistent overlay when app goes to background/minimized state.
- If overlay rendering fails, show toast feedback (not silent).

### Claude's Discretion
- Exact typography/spacing tokens inside the compact pill.
- Exact implementation of foreground visibility toggle UI and storage.
- Exact fallback wording for permission/error messages.
- Internal state model for idle vs event overlay rendering, as long as it preserves persistent behavior.

</decisions>

<specifics>
## Specific Ideas

- Reference direction: Grab-style live activity behavior ("dynamic island" feel).
- User intent: overlay should feel like live activity above other apps when app is closed/minimized.
- User noted this phase should prioritize persistent live activity and bug-fix alignment, not redoing existing scan notification feature that is already working.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/overlay_task.dart`: existing overlay FlutterEngine entrypoint and pill UI (`overlayMain`, `KioskOverlayUI`) with expand/minimize interaction.
- `lib/services/kiosk_background_service.dart`: existing `showOverlayPill`, `hideOverlayPill`, `requestOverlayPermission`, and overlay data push via `FlutterOverlayWindow.shareData`.
- `lib/screens/kiosk/kiosk_idle_screen.dart`: existing guided permission dialog with MIUI-specific MethodChannel flow.
- `lib/models/attendance_log.dart`: `AttendanceTypeExt.color` mapping available for consistent accent usage.

### Established Patterns
- Overlay runs in separate FlutterEngine via `flutter_overlay_window`.
- Lifecycle-driven overlay management already exists in `lib/app.dart` (`paused` shows overlay, `resumed` hides overlay).
- Overlay data channel currently uses compact shared payload format (`outlet|time`) and can be extended for persistent type/accent state.

### Integration Points
- `lib/app.dart` `didChangeAppLifecycleState` is the main hook for background/minimized trigger behavior.
- `KioskBackgroundService` is the correct orchestration layer for overlay show/hide/update and permission checks.
- App-level state/preferences (Riverpod provider layer) is the likely integration point for foreground visibility toggle.

</code_context>

<deferred>
## Deferred Ideas

- Detailed bug-fix list mentioned by user but not enumerated in this session should be captured as explicit TODO/phase backlog items.
- Any new capabilities beyond persistent live activity (outside this boundary) should be planned as separate future phases.

</deferred>

---

*Phase: 03-overlay-pill-implementation*
*Context gathered: 2026-03-01*
