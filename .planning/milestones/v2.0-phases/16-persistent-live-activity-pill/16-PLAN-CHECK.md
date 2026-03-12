# Phase 16 Plan Verification Report
**Checker:** gsd-plan-checker  
**Date:** 2026-03-12  
**Phase:** 16-persistent-live-activity-pill  
**Plans Verified:** 16-01-PLAN.md (Wave 1), 16-02-PLAN.md (Wave 2)

---

## Verification Summary

| Dimension | Plan 01 | Plan 02 | Status |
|-----------|---------|---------|--------|
| 1. Requirement Coverage | LIVE-02, LIVE-03 | LIVE-01, LIVE-02, LIVE-03, LIVE-04 | ✅ PASS |
| 2. Task Completeness | 2 tasks — all fields present | 2 auto + 1 checkpoint | ✅ PASS |
| 3. Dependency Correctness | Wave 1, no deps | Wave 2, depends_on: [16-01] | ✅ PASS |
| 4. Key Links Planned | Supabase → LiveContentProvider; model → overlay | Service → provider; service → model; overlay → model | ⚠️ PARTIAL |
| 5. Scope Sanity | 2 tasks / 4 files | 3 tasks / 3 files | ✅ PASS |
| 6. Verification Derivation | User-observable truths | User-observable truths | ✅ PASS |
| 7. Context Compliance | Honors discretion on displayLabel choice | Honors locked decisions | ✅ PASS |
| 8. Nyquist Compliance | flutter test commands present | flutter test commands present | ✅ PASS |

**Overall: PASS with warnings**

---

## Dimension 1: Requirement Coverage

| Requirement | Plan | Covering Tasks | Status |
|-------------|------|----------------|--------|
| LIVE-01 (regression check) | 02 | Task 3 (checkpoint:human-verify) | ✅ Covered |
| LIVE-02 (break status display) | 01, 02 | 01/Task 2 (LiveContentProvider), 02/Task 1 (rendering), 02/Task 2 (wiring) | ✅ Covered |
| LIVE-03 (fun facts) | 01, 02 | 01/Task 2 (fun facts builder), 02/Task 1 (rendering), 02/Task 2 (wiring) | ✅ Covered |
| LIVE-04 (auto-update 30s/5s) | 02 | Task 2 (poll timer + rotate timer) | ✅ Covered |

All 4 requirements covered. ✓

---

## Dimension 2: Task Completeness

### Plan 01
| Task | Files | Action | Verify | Done | TDD Behavior |
|------|-------|--------|--------|------|--------------|
| Task 1: displayLabel field | ✅ 2 files | ✅ Specific (6 steps with code) | ✅ flutter test | ✅ Measurable | ✅ 6 behaviors listed |
| Task 2: LiveContentProvider | ✅ 2 files | ✅ Specific (full class skeleton + impl details) | ✅ flutter test | ✅ Measurable | ✅ 12 behaviors listed |

### Plan 02
| Task | Files | Action | Verify | Done | Notes |
|------|-------|--------|--------|------|-------|
| Task 1: overlay rendering | ✅ 2 files | ✅ Specific (code blocks, line numbers) | ✅ flutter test | ✅ Measurable | — |
| Task 2: KioskBackgroundService wiring | ✅ 1 file | ⚠️ Internally contradictory (see issues) | ✅ flutter test | ✅ Measurable | See Issue #1 |
| Task 3: checkpoint:human-verify | N/A | ✅ 12-step device checklist | ✅ Human confirm | ✅ "approved" | — |

---

## Dimension 3: Dependency Correctness

```
Plan 01 (Wave 1) ──── no deps ──── can run immediately
Plan 02 (Wave 2) ──── depends_on: [16-01] ──── must wait for Plan 01
```

- No circular dependencies ✓
- Wave numbers consistent with dependency graph ✓
- Plan 02 correctly consumes Plan 01 outputs (displayLabel, LiveContentProvider API) ✓
- Plan 02 context includes `16-01-SUMMARY.md` reference for execution-time availability ✓

---

## Dimension 4: Key Links Planned

### Plan 01 Key Links
| From | To | Via | Verification |
|------|----|-----|-------------|
| `live_content_provider.dart` | `attendance_logs` table | Supabase query with `.eq('scan_outlet_id', outletId)` | ✅ Action text explicit |
| `overlay_pill_state.dart` | `overlay_task.dart` | `displayLabel` field in wire payload | ✅ Plan 02 implements this |

### Plan 02 Key Links
| From | To | Via | Verification |
|------|----|-----|-------------|
| `kiosk_background_service.dart` | `live_content_provider.dart` | `_liveContent.poll()` + `nextDisplayText()` | ✅ Code blocks in action |
| `kiosk_background_service.dart` | `overlay_pill_state.dart` | `displayLabel: displayText` in constructor | ✅ Code blocks in action |
| `overlay_task.dart` | `overlay_pill_state.dart` | `displayLabel.isNotEmpty` in `_resolveStyle()` | ✅ Code blocks in action |
| `kiosk_scan_screen.dart` | `kiosk_background_service.dart` | `markEventActive(eventUntilEpochMs)` call | ⚠️ In action text but NOT in files_modified |

**Gap:** `kiosk_scan_screen.dart` is referenced in Plan 02 Task 2 action as needing `markEventActive()` call, but is absent from `files_modified` frontmatter. See Issue #1.

---

## Dimension 5: Scope Sanity

| Plan | Tasks | Files Modified | Wave | Assessment |
|------|-------|----------------|------|------------|
| 01 | 2 | 4 | 1 | ✅ Ideal (2-3 tasks, <10 files) |
| 02 | 3 (2 auto + 1 checkpoint) | 3 | 2 | ✅ Within budget |

Total context estimate: ~40-50% — well within budget. ✓

---

## Dimension 6: Verification Derivation (must_haves)

### Plan 01 Truths — all user-observable or functionally testable ✓
- `"nextDisplayText() returns '🍽️ {name} istirahat'"` — output-verifiable
- `"rotates through break names on successive calls"` — behavior-verifiable  
- `"interleaves live stats with motivational messages"` — output-verifiable
- `"OverlayPillState.displayLabel serializes/deserializes correctly"` — unit-testable
- `"backward-compatible: missing displayLabel defaults to empty string"` — unit-testable

### Plan 02 Truths — all user-observable or functionally testable ✓
- `"Overlay pill renders displayLabel text instead of enum label"` — widget-testable
- `"Falls back to attendanceType enum label when displayLabel empty"` — widget-testable
- `"KioskBackgroundService polls every 30 seconds"` — behavior-verifiable
- `"pushes nextDisplayText() every 5 seconds"` — behavior-verifiable
- `"Event mode takes priority"` — behavior-verifiable (and device-verified in Task 3)
- `"Accent color amber/green"` — widget-testable
- `"Poll timer cancelled on stop()"` — unit-testable
- `"Overlay remains visible outside app (LIVE-01)"` — device-verifiable in Task 3

---

## Dimension 7: Context Compliance

### Locked Decisions Honored

| Decision | Plan Handling | Status |
|----------|--------------|--------|
| Break format: "🍽️ {name} istirahat" | Plan 01/Task 2 action and must_haves truth exact match | ✅ |
| Rotation speed: 5 seconds | Reuses existing `_rotateTimer` (5s) | ✅ |
| Fun facts: 3-5 live stats + 3-5 motivational messages | Plan 01/Task 2 has exactly 3 stats + 5 motivational messages | ✅ |
| Supabase poll interval: 30 seconds | Plan 02/Task 2 `Timer.periodic(Duration(seconds: 30))` | ✅ |
| Data flow: main isolate polls, overlay is dumb renderer | Architecture preserved throughout | ✅ |

### Discretion Area: displayLabel vs. reusing attendanceType

CONTEXT.md initially says "OverlayPillState.attendanceType carries the current display text" but also explicitly marks "Whether to extend OverlayPillState model or reuse existing fields" as **Claude's Discretion**. The plan chose to add `displayLabel` — this is valid per Research Pitfall 7 (arbitrary text would break `AttendanceTypeExt.fromString()`). Discretion exercised correctly. ✓

### Break Detection: 'break' not 'istirahat'

CONTEXT.md says `type = 'istirahat'` but the actual DB value (confirmed in `attendance_log.dart` line 30) is `'break'`. The plan correctly uses `AttendanceType.breakTime.value` → `'break'`. This is a factual correction, not a contradiction. ✓

---

## Dimension 8: Nyquist Compliance

| Task | Plan | Wave | Automated Command | Status |
|------|------|------|-------------------|--------|
| Task 1 (displayLabel) | 01 | 1 | `flutter test test/models/overlay_pill_state_test.dart` | ✅ |
| Task 2 (LiveContentProvider) | 01 | 1 | `flutter test test/services/live_content_provider_test.dart` | ✅ |
| Task 1 (overlay rendering) | 02 | 2 | `flutter test test/widgets/overlay_pill_widget_test.dart` | ✅ |
| Task 2 (KioskBackgroundService) | 02 | 2 | `flutter test` (full suite) | ✅ |
| Task 3 (checkpoint) | 02 | 2 | Human verify (checkpoint type) | ✅ N/A |

Sampling: Wave 1: 2/2 verified ✅ | Wave 2: 2/2 auto + 1 human checkpoint ✅  
Overall: ✅ PASS

---

## Technical Accuracy Validation

Plans reference actual source code with high precision:

| Claim | Actual | Match |
|-------|--------|-------|
| `_resolveStyle()` at "around line 234" | Line 234 | ✅ Exact |
| `_copyState()` at "around line 197" | Line 197 | ✅ Exact |
| `_rotateNotification` at "line 456" | Line 456 | ✅ Exact |
| `_showingTime` at "around line 45" | Line 45 | ✅ Exact |
| `start()` rotateTimer setup "around line 155" | Lines 154-157 | ✅ Exact |
| `stop()` at "line 167" | Line 167 | ✅ Exact |
| `AttendanceType.breakTime.value` returns `'break'` | Confirmed line 30 | ✅ Exact |
| `_applyIncomingState` idle payloads overwrite event state | Lines 119-123 confirmed | ✅ Confirmed gap exists |
| `kiosk_scan_screen.dart` pushes event with `eventUntilEpochMs` | Line 235-236: `now.add(Duration(seconds: 8))` | ✅ Confirmed |

---

## Issues Found

### ⚠️ WARNING — Issue #1: kiosk_scan_screen.dart missing from Plan 02 files_modified

**Dimension:** key_links_planned  
**Plan:** 16-02  
**Task:** Task 2  
**Description:** Plan 02 Task 2 action explicitly states: *"Then in `kiosk_scan_screen.dart` (wherever it calls `updateOverlayState` with event), also call `KioskBackgroundService.markEventActive(eventUntilEpochMs)`."* This is required for the event mode priority protection to function. However, `lib/screens/kiosk/kiosk_scan_screen.dart` is absent from the `files_modified` frontmatter list.

**Risk:** An executor working strictly from the `files_modified` list would not track this change. The `gsd-verifier` would not check `kiosk_scan_screen.dart` for the required `markEventActive` call. Without this call, `_eventUntilEpochMs` remains 0 and `_rotateNotification` overwrites every NFC event after 5 seconds — breaking the must_haves truth "Event mode (NFC scan) takes priority."

**Confirmed gap:** `overlay_task.dart` line 119-123 confirms idle payloads DO overwrite event state unconditionally. The KioskBackgroundService-side check is the only protection.

**Fix:** Add `lib/screens/kiosk/kiosk_scan_screen.dart` to Plan 02's `files_modified` frontmatter.

---

### ⚠️ WARNING — Issue #2: Plan 02 Task 2 action has internally contradictory event mode instructions

**Dimension:** task_completeness  
**Plan:** 16-02  
**Task:** Task 2  
**Description:** The action text first says *"Do NOT add event mode priority check in _rotateNotification"* then immediately reverses: *"REVISED: Add event mode check..."* with full implementation code. An autonomous executor reading sequentially could follow the first instruction and stop, skipping the event mode protection entirely.

**Risk:** Medium — the "REVISED" section is present and detailed. A careful executor would follow it. But the contradiction creates unnecessary ambiguity.

**Fix:** Remove the "Do NOT add event mode priority check" paragraph and keep only the REVISED section. Rewrite as a clear, single-direction instruction.

---

### ℹ️ INFO — Issue #3: `_computeFunFacts` needs second Supabase query but injectable interface only exposes one callback

**Dimension:** key_links_planned  
**Plan:** 01  
**Task:** Task 2  
**Description:** The plan correctly designs an injectable `fetchLogs` + `fetchActiveCount` two-callback constructor for testability. However, `fetchActiveCount` runs a separate query (`employees.eq('home_outlet_id', outletId).eq('is_active', true)`). Ensure the constructor injection includes both callbacks — the plan action text does mention both, but only one is illustrated in the class skeleton. This is a minor consistency note.

**Impact:** None if executor follows the full action text. Verified the action does define both callbacks.

---

## Structured Issues (YAML)

```yaml
issues:
  - plan: "16-02"
    dimension: "key_links_planned"
    severity: "warning"
    description: "kiosk_scan_screen.dart missing from files_modified despite being explicitly modified in Task 2 action for markEventActive() call. Event mode priority protection silently breaks without this change."
    task: 2
    fix_hint: "Add lib/screens/kiosk/kiosk_scan_screen.dart to Plan 02 files_modified frontmatter list"

  - plan: "16-02"
    dimension: "task_completeness"
    severity: "warning"
    description: "Task 2 action contains internal contradiction: first says 'Do NOT add event mode priority check', then reverses with 'REVISED: Add event mode check'. Autonomous executor confusion risk."
    task: 2
    fix_hint: "Delete the 'Do NOT add event mode priority check' paragraph. Keep only the REVISED approach with _eventUntilEpochMs and markEventActive()."

  - plan: "16-01"
    dimension: "task_completeness"
    severity: "info"
    description: "LiveContentProvider constructor injectable interface mentions fetchLogs and fetchActiveCount callbacks but the class skeleton only shows the class without constructor. Minor documentation gap."
    task: 2
    fix_hint: "Verify both callbacks are in the constructor signature in the produced code."
```

---

## Recommendation

The plans are **safe to execute** with the warnings addressed. The two warnings are:

1. **Add `kiosk_scan_screen.dart` to Plan 02 `files_modified`** — required for verification tracking of the event mode protection. The step is described in the action text so it will likely be executed, but without the file in the frontmatter, the `gsd-verifier` won't audit it.

2. **Clean up Plan 02 Task 2 contradictory wording** — remove "Do NOT add event mode priority check" paragraph, replace with the REVISED approach as the single clear instruction.

If these warnings are accepted and the executor is careful, execution can proceed. The underlying technical design is sound: line numbers are precise, DB values are correct, the `displayLabel` approach correctly solves Pitfall 7, the event mode protection mechanism is architecturally valid, and all 4 requirements have clear coverage paths.

---

```json
{
  "verdict": "pass",
  "confidence": 0.82,
  "issues": [
    "WARNING: lib/screens/kiosk/kiosk_scan_screen.dart missing from Plan 02 files_modified — needed for markEventActive() call that enables event mode priority protection (must_haves truth). Step described in action text but not tracked in metadata.",
    "WARNING: Plan 02 Task 2 action internally contradicts itself on event mode handling (first says 'Do NOT add', then REVISED says 'Add'). Autonomous executor confusion risk if they stop at the first instruction."
  ],
  "recommendations": [
    "Add lib/screens/kiosk/kiosk_scan_screen.dart to Plan 02 files_modified frontmatter",
    "Rewrite Plan 02 Task 2 action to remove the contradictory 'Do NOT add event mode priority check' paragraph, keeping only the REVISED approach with _eventUntilEpochMs tracking",
    "Consider adding a test for event mode non-overwrite in Plan 02 widget tests (simulate event then idle push, verify event is preserved until expiry)"
  ]
}
```
