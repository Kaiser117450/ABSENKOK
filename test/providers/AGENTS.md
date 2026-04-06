# test/providers/AGENTS.md

<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-05 | Updated: 2026-04-05 -->

## Purpose

Provider unit tests. 1 test file for AppProvider state management.

## Key Files

| File | Description |
|---|---|
| `app_provider_biometric_test.dart` | AppProvider biometric authentication state |

## For AI Agents

- Test session loading — must always set `isLoading: false` in `finally` block
- Test mode switching (admin vs kiosk)
- Test loading state management and the 5s safety-net timeout
- Uses `SharedPreferences` (NOT `FlutterSecureStorage` — causes ANR)
- Mock biometric service for authentication tests
