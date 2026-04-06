# test/screens/AGENTS.md

<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-05 | Updated: 2026-04-05 -->

## Purpose

Screen widget tests container. Organized by app mode (admin vs kiosk).

## Subdirectories

| Directory | Description |
|---|---|
| `admin/` | 10 admin screen widget tests (dashboard, employees, reports, login, scheduler) |
| `kiosk/` | 2 kiosk screen widget tests (NFC scan flow, server time) |

## For AI Agents

- Screen tests use `WidgetTester` for pump-and-interact testing
- Mock all providers and services before pumping widgets
- Admin screens are more numerous and complex than kiosk screens
- See subdirectory AGENTS.md files for detailed file listings
