# test/screens/admin/AGENTS.md

<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-05 | Updated: 2026-04-05 -->

## Purpose

Admin screen widget tests. 10 test files covering all admin-facing screens.

## Key Files

| File | Description |
|---|---|
| `admin_login_screen_test.dart` | Admin login form validation and auth flow |
| `admin_dashboard_schedule_gap_test.dart` | Dashboard schedule gap warnings |
| `admin_employees_archive_test.dart` | Employee archive/restore functionality |
| `admin_reports_payroll_matrix_test.dart` | Payroll matrix report screen |
| `admin_reports_payroll_rollout_test.dart` | Payroll rollout report screen |
| `admin_reports_policy_recap_test.dart` | Policy recap report screen |
| `central_dashboard_screen_test.dart` | Multi-outlet central dashboard |
| `chart_dashboard_screen_test.dart` | Chart/analytics dashboard |
| `rekap_harian_test.dart` | Daily recap (rekap harian) screen |
| `shift_scheduler_screen_test.dart` | Shift scheduler management screen |

## For AI Agents

- Tests use `WidgetTester` — always `await tester.pumpAndSettle()` after interactions
- Mock providers and services before pumping widgets
- Test navigation flows between admin screens
- Test form validation (login, employee forms, schedule forms)
- Payroll report tests are the most complex — verify table rendering and export triggers
- `admin_login_screen_test.dart` must verify `/admin/login` is always accessible before kiosk check
