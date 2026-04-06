# test/widgets/AGENTS.md

<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-05 | Updated: 2026-04-05 -->

## Purpose

Shared widget unit tests. 7 test files for reusable UI components.

## Key Files

| File | Description |
|---|---|
| `attendance_policy_badge_test.dart` | Attendance policy status badge rendering |
| `color_picker_field_test.dart` | Color picker form field interactions |
| `employee_contract_badge_test.dart` | Employee contract type badge |
| `outlet_mode_badge_test.dart` | Outlet mode indicator badge |
| `overlay_pill_widget_test.dart` | Floating overlay pill (Dynamic Island style) |
| `payroll_matrix_table_test.dart` | Payroll matrix table rendering and scroll |
| `schedule_policy_widgets_test.dart` | Schedule policy display widgets |

## For AI Agents

- Test widget rendering with `WidgetTester`
- Verify tap handlers fire correct callbacks
- Test state changes on user interaction
- Badge widgets should handle all enum values without overflow
- Overlay pill widget tests validate expand/collapse animation
- Payroll matrix table tests are the most complex — verify scroll, cell rendering, and large datasets
