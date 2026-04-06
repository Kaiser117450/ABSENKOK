# AGENTS.md

> Parent: [../AGENTS.md](../AGENTS.md)

## Purpose

Shared reusable UI widgets used across admin and kiosk screens. 15 widgets following consistent naming conventions.

## Key Files

| File | Description |
|---|---|
| `app_badge.dart` | Styled badge component for generic labels |
| `app_card.dart` | Standard card wrapper with consistent elevation and padding |
| `app_empty_state.dart` | Empty state placeholder with icon and message |
| `app_toast.dart` | Toast notification widget for user feedback |
| `badge_avatar.dart` | Employee avatar with achievement badge overlay |
| `shimmer_skeleton.dart` | Loading skeleton animation for content placeholders |
| `overtime_alert_row.dart` | Overtime warning display row |
| `attendance_rate_card.dart` | Attendance rate metric card for dashboard |
| `kiosk_health_card.dart` | Kiosk device health status card |
| `kiosk_device_card.dart` | Kiosk device info and management card |
| `outlet_control_card.dart` | Outlet management and control card |
| `attendance_policy_signal_chip.dart` | Policy signal chip indicator |
| `attendance_policy_badge.dart` | Policy evaluation status badge |
| `employee_contract_badge.dart` | Contract type badge (tetap, magang, probation) |
| `outlet_mode_badge.dart` | Operating mode badge (normal, ramadan, etc.) |

## For AI Agents

### Naming Conventions

- **`app_*.dart`** — Generic reusable widgets (badge, card, toast, empty state).
- **`*_badge.dart`** — Status indicator badges (policy, contract, outlet mode).
- **`*_card.dart`** — Information display cards (attendance rate, kiosk health, device, outlet).
- **`*_chip.dart`** — Small inline indicators (policy signal).
- **`*_row.dart`** — Single-row display components (overtime alert).

### Guidelines

- Follow existing naming conventions when adding new widgets.
- Use theme colors from `core/theme.dart` — do not hardcode colors.
- All cards should use `app_card.dart` as a base wrapper for consistent styling.
- Widgets should be stateless where possible; use Riverpod for state that needs to be shared.
