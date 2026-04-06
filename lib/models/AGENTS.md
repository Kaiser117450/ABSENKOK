# AGENTS.md

> Parent: [../AGENTS.md](../AGENTS.md)

## Purpose

Data models representing database entities and domain objects. 24 model files that mirror Supabase tables and encapsulate domain logic.

## Key Files

| File | Description |
|---|---|
| `employee.dart` | Employee profile (name, NFC UID, outlet, contract type, archived status) |
| `attendance_log.dart` | Clock in/out record with GPS, device info, policy signals |
| `kiosk_session.dart` | Active kiosk session with outlet binding |
| `kiosk_device.dart` | Registered kiosk device with heartbeat data |
| `shift_schedule.dart` | Employee shift assignment |
| `shift_band.dart` | Shift time definitions (start/end/grace periods) |
| `outlet.dart` | Restaurant outlet/branch |
| `outlet_operating_mode.dart` | Operating mode enum (normal, ramadan, etc.) |
| `employee_contract.dart` | Contract type (tetap, magang, probation) |
| `daily_summary.dart` | Aggregated daily attendance summary |
| `pending_log.dart` | Offline queue entry for SQLite sync |
| `time_off_request.dart` | Sakit/izin (sick/leave) request |
| `csv_import_result.dart` | CSV import parsing result |
| `overlay_pill_state.dart` | Dynamic Island overlay state |
| `kiosk_scan_context.dart` | NFC scan context with server time |
| `employee_badge.dart` | Achievement badges |
| `attendance_policy_signal.dart` | Policy evaluation signals |
| `attendance_policy_recap_day.dart` | Daily policy recap |
| `payroll_matrix_row.dart` | Payroll matrix row data |
| `payroll_matrix_day_cell.dart` | Individual day cell in payroll matrix |
| `payroll_rollout_acceptance.dart` | Payroll acceptance tracking |
| `schedule_gap_notice.dart` | Unscheduled day warnings |

## For AI Agents

- **Pattern**: All models use `fromJson(Map<String, dynamic>)` factory constructors and `toJson()` methods for Supabase serialization.
- **Nullable fields**: Optional database columns are represented as nullable Dart fields (`Type?`). Always handle nulls defensively.
- **Mirror Supabase tables**: Model field names match database column names (snake_case in DB, camelCase in Dart via fromJson mapping).
- **Enums**: `outlet_operating_mode.dart` and `employee_contract.dart` define enum types — use these instead of raw strings.
- **Offline queue**: `pending_log.dart` is the SQLite model for offline attendance entries awaiting sync. It has its own lifecycle separate from `attendance_log.dart`.
