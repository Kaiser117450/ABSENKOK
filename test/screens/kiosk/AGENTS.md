# test/screens/kiosk/AGENTS.md

<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-05 | Updated: 2026-04-05 -->

## Purpose

Kiosk screen widget tests. 2 test files covering NFC scan and kiosk display behavior.

## Key Files

| File | Description |
|---|---|
| `kiosk_scan_server_time_test.dart` | Kiosk scan with server time validation |
| `kiosk_scan_streak_test.dart` | Kiosk scan streak display and animation |

## For AI Agents

- Test NFC scan flow end-to-end — mock `NfcService` completely
- Test idle screen behavior and auto-reset
- Server time test validates clock sync between device and server
- Streak test validates attendance streak display after successful scan
- Mock NFC availability check: `NfcManager.instance.isAvailable()`
