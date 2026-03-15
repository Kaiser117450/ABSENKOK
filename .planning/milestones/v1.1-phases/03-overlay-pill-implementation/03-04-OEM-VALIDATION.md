# Phase 03 Plan 04 OEM Validation Checklist

Use this sheet for the blocking real-device gate in Task 3.

## Run Metadata

| Field | Value |
| --- | --- |
| Date |  |
| Build/Commit |  |
| Tester |  |
| Notes |  |

## Device Matrix

Use at least 2 real devices with different OEM skins.

| Device ID | Brand/Model | OEM Skin | Android Version | Build Variant | Tester |
| --- | --- | --- | --- | --- | --- |
| Device-A |  |  |  |  |  |
| Device-B |  |  |  |  |  |

## Gate Rule

- Every `Critical` row must be `PASS` on all listed devices before approval.
- If any critical row fails, add details in `Blocking Notes` and do not approve.

## Validation Checklist

| ID | Scenario | Critical | Device-A | Device-B | Evidence (video/screenshot/log) | Blocking Notes |
| --- | --- | --- | --- | --- | --- | --- |
| OVL-01 | App `inactive`/`hidden`/`paused` with active kiosk session shows persistent idle overlay | Yes | PENDING | PENDING |  |  |
| OVL-02 | On `resumed`, overlay hides when foreground toggle is OFF | Yes | PENDING | PENDING |  |  |
| OVL-03 | On `resumed`, overlay stays visible when foreground toggle is ON | Yes | PENDING | PENDING |  |  |
| OVL-04 | Tap-through works: taps/scrolls in foreground app still function outside pill hit area | Yes | PENDING | PENDING |  |  |
| OVL-05 | Pill interaction works: tap pill toggles expanded/minimized without trapping global interaction | Yes | PENDING | PENDING |  |  |
| OVL-06 | Readability on light foreground background (text/accent still readable) | Yes | PENDING | PENDING |  |  |
| OVL-07 | Readability on dark foreground background (text/accent still readable) | Yes | PENDING | PENDING |  |  |
| OVL-08 | Permission denied path shows guided re-enable dialog (overlay is best-effort, no toast) | Yes | PENDING | PENDING |  |  |
| OVL-09 | Overlay show/render failure silently logged to debugPrint (no user-facing toast per design) | No | PENDING | PENDING |  |  |
| OVL-10 | Kiosk reset stops service + hides overlay (no stale floating UI remains) | Yes | PENDING | PENDING |  |  |

## Final Decision

| Item | Value |
| --- | --- |
| Critical Rows Pass |  |
| Overall Result | `APPROVED` / `BLOCKED` |
| Follow-up Needed |  |

