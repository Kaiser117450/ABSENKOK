# test/models/AGENTS.md

<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-05 | Updated: 2026-04-05 -->

## Purpose

Model unit tests. 8 test files validating `fromJson`/`toJson`, equality, and edge cases for all data models.

## Key Files

| File | Description |
|---|---|
| `attendance_policy_recap_day_test.dart` | Attendance policy recap day model |
| `csv_import_result_test.dart` | CSV import result model |
| `overlay_pill_state_test.dart` | Overlay pill state model |
| `payroll_matrix_day_cell_test.dart` | Payroll matrix day cell model |
| `payroll_matrix_row_test.dart` | Payroll matrix row model |
| `shift_schedule_policy_test.dart` | Shift schedule policy model |
| `shift_schedule_test.dart` | Shift schedule model |
| `workforce_metadata_test.dart` | Workforce metadata model |

## For AI Agents

- Test all nullable field handling — models must survive `null` JSON values gracefully
- Verify JSON serialization round-trips: `fromJson(toJson(model)) == model`
- Test equality operators and `hashCode` consistency
- Payroll matrix models have the most complex field logic
- Shift schedule models validate time range constraints
