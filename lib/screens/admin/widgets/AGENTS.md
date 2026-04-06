# Admin Widgets — Payroll Matrix & Schedule Views

<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-05 | Updated: 2026-04-05 -->

## Purpose

Admin-specific complex widgets, primarily for payroll matrix rendering and schedule views. 10 widget files.

## Key Files

| File | Responsibility |
|------|---------------|
| `payroll_matrix_table.dart` | Main payroll matrix table (2D scrollable via `two_dimensional_scrollables`) |
| `payroll_matrix_day_cell_widget.dart` | Individual day cell in payroll matrix |
| `payroll_matrix_summary_rail.dart` | Summary column for payroll matrix |
| `payroll_rollout_acceptance_panel.dart` | Payroll acceptance workflow panel |
| `policy_recap_payroll_support_section.dart` | Policy recap section in payroll view |
| `schedule_table_view.dart` | Schedule grid view |
| `schedule_cells.dart` | Individual schedule cell renderers |
| `schedule_legend.dart` | Schedule color legend |
| `schedule_policy_summary_card.dart` | Policy summary card for schedules |
| `admin_schedule_gap_notice_sheet.dart` | Bottom sheet for schedule gap notifications |

## Architecture Notes

- **Payroll matrix cluster**: `payroll_matrix_table.dart`, `payroll_matrix_day_cell_widget.dart`, and `payroll_matrix_summary_rail.dart` form the core payroll matrix rendering system using `two_dimensional_scrollables` for 2D scrolling.
- **Schedule cluster**: `schedule_table_view.dart`, `schedule_cells.dart`, `schedule_legend.dart`, `schedule_policy_summary_card.dart`, and `admin_schedule_gap_notice_sheet.dart` are tightly coupled with `shift_band` and `shift_schedule` models.
- **Service dependencies**: Payroll widgets consume data from `services/payroll_matrix_builder.dart` and `services/payroll_matrix_semantics.dart`.

## For AI Agents

- Payroll widgets use `two_dimensional_scrollables` for matrix rendering — this is a specialized package with specific API patterns.
- Schedule widgets are tightly coupled with `shift_band` and `shift_schedule` models — changes to models require updating these widgets.
- The payroll matrix is performance-sensitive — avoid unnecessary rebuilds in cell widgets.
- When modifying payroll cells, verify both the table layout and the summary rail remain aligned.
