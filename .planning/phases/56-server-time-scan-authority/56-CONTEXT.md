# Phase 56: Server-Time Scan Authority - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Move kiosk scan capture to a server-authoritative WITA timeline and safely capture break-first intent on eligible first scans. This phase covers the kiosk scan experience, offline-safe capture behavior, and scan feedback surfaces needed to trust the authoritative time source. Shift-band policy, break-first eligibility windows, and lateness cutoffs are already locked by Phase 55; payroll recap severity and richer admin audit redesign remain out of scope.

</domain>

<decisions>
## Implementation Decisions

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

</decisions>

<specifics>
## Specific Ideas

- The user wants Phase 56 to preserve the fast kiosk rhythm: the normal scan flow should remain quick, and added friction should only appear for eligible break-first cases.
- The user explicitly prefers an extra `Istirahat Dulu` path plus a short confirmation, not a hidden auto-branch or a long explainer.
- The user wants queued offline scans to stay operationally usable, but only for known employees, with auto-recovery once connectivity returns.
- The user wants the success state to show the authoritative WITA time and make pending scans look different without requiring technical wording or slower manual dismissal.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/screens/kiosk/kiosk_scan_screen.dart`: current scan experience already has smart action buttons, a styled success screen, backup badges, and one-tap attendance actions that can absorb an eligible `Istirahat Dulu` path.
- `lib/screens/kiosk/kiosk_idle_screen.dart`: the kiosk already uses a polished custom dialog pattern for outlet confirmation and already surfaces pending-sync state with a header badge and banner.
- `lib/services/sqlite_service.dart`: the local `pending_logs` queue already stores unsynced scan records with retry status and chronological insertion order.
- `lib/services/sync_service.dart`: background sync already uploads queued attendance logs automatically when connectivity exists.

### Established Patterns
- Kiosk interactions favor fast taps, short confirmations, and automatic return to idle rather than multi-step forms.
- Pending-sync visibility already lives on the idle screen as compact status UI instead of a separate operator workflow.
- Attendance records are currently stamped and synced from the device using `scanned_at`, so planning must replace device-clock trust without breaking the offline queue contract.
- Late-pattern notification logic in `lib/services/pattern_detection_service.dart` still consumes the local `scanTime`, so server-authoritative timing must eventually feed any lateness-sensitive follow-up behavior.

### Integration Points
- `lib/screens/kiosk/kiosk_scan_screen.dart` needs the new eligible break-first action, short confirmation, authoritative WITA success state, and distinct queued-success treatment.
- `lib/screens/kiosk/kiosk_idle_screen.dart` already owns the persistent pending indicator and can remain the follow-up surface after fast auto-close.
- `lib/services/sqlite_service.dart`, `lib/models/attendance_log.dart`, and `lib/services/sync_service.dart` must preserve offline event order while moving scan authority away from the tablet clock.
- `lib/services/pattern_detection_service.dart` and later recap/admin review paths must consume the authoritative scan timeline or clearly separate local provisional timing from final authoritative evaluation.

</code_context>

<deferred>
## Deferred Ideas

- Exact admin-review labeling and filtering for break-first-late vs normal late cases can stay flexible for planning, as long as the distinction remains available for later recap and audit work.
- Any supervisor-only offline override or uncached-employee fallback flow is not part of this phase and should be treated as a separate future capability if needed.

</deferred>

---

*Phase: 56-server-time-scan-authority*
*Context gathered: 2026-03-26*
