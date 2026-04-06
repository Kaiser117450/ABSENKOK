# test/AGENTS.md

<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-05 | Updated: 2026-04-05 -->

## Purpose

Flutter test suite. Unit tests for models, services, providers, screens, and widgets. Also has phase-specific integration tests.

## Subdirectories

| Directory | Description |
|---|---|
| `fixtures/` | Shared test data and mock objects |
| `models/` | 8 model unit tests (JSON serialization, equality, edge cases) |
| `providers/` | 1 provider test (AppProvider biometric) |
| `screens/admin/` | 10 admin screen widget tests |
| `screens/kiosk/` | 2 kiosk screen widget tests |
| `services/` | 25 service tests — largest and most critical directory |
| `widgets/` | 7 shared widget unit tests |
| `phase32/`–`phase57/` | Phase-specific integration tests (milestones 32, 50–53, 56, 57) |

## Key Files

| File | Description |
|---|---|
| `widget_test.dart` | Default Flutter widget smoke test |
| `device_identity_service_test.dart` | Device identity service test (root level) |

## For AI Agents

- Run all tests: `flutter test`
- Run a single test: `flutter test test/<path_to_test>.dart`
- **Service tests are the most critical** — 25 files covering all business logic
- Phase tests validate specific milestone features and regressions
- Use `fixtures/` for shared test data across test files
- Mock Supabase calls in tests — never hit real endpoints
- Mock SQLite for offline queue tests
