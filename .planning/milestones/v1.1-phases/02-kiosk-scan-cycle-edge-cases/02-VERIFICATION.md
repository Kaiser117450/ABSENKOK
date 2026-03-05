---
phase: 02-kiosk-scan-cycle-edge-cases
verified: 2026-03-01T13:00:00Z
status: human_needed
score: 12/12 must-haves verified
re_verification: true
  previous_status: gaps_found
  previous_score: 10/12
  gaps_closed:
    - "Rekap Harian shows 'Belum Pulang' badge for past-date entries where firstMasuk != null and lastPulang == null"
    - "Today's active shift (employee currently working) does NOT show Belum Pulang badge mid-day"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Open Rekap Harian tab in Admin Reports for a date range that includes yesterday with an employee who scanned masuk but not pulang"
    expected: "Tile shows masuk time in the Masuk cell AND an amber 'Belum Pulang' chip in the Pulang cell, without crashing"
    why_human: "Requires live Supabase data and navigation to the Rekap Harian tab to observe runtime behavior"
  - test: "Verify today's entry for an employee currently working does not show Belum Pulang"
    expected: "Today's in-progress shift shows normal --:-- on the pulang cell"
    why_human: "Time-dependent guard requires real device and current-day attendance data"
  - test: "Open Admin Dashboard and verify Open Shifts widget appears for employees with open shifts from last 32h"
    expected: "Amber card visible between stat grid and quick actions; each row shows name, masuk time, hours elapsed, and Tutup Shift button"
    why_human: "Requires live Supabase data and Android device to confirm rendering and widget placement"
  - test: "Tap Tutup Shift for an open shift, enter notes, confirm"
    expected: "Dialog appears, pulang inserted to attendance_logs, widget refreshes and employee disappears from list"
    why_human: "Requires live Supabase connection and database write confirmation"
---

# Phase 02: Kiosk Scan Cycle Edge Cases — Verification Report

**Phase Goal:** Kiosk handles forgot-clock-out, midnight transitions, and 24h outlets correctly.
**Verified:** 2026-03-01T13:00:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure (commit d554797)

---

## Re-Verification Summary

**Previous status:** gaps_found (10/12, 2026-03-01T00:00:00Z)

**Gap that was fixed:** Commit `d554797` changed line 431 in
`lib/screens/admin/admin_reports_screen.dart` from:

```dart
// BEFORE (crashed for belumPulang days — no sakit/izin row exists)
if (dayStatus != DailySummaryStatus.normal) {
```

to:

```dart
// AFTER (only runs for days that actually have a sakit/izin row)
if (dayStatus == DailySummaryStatus.sakit ||
    dayStatus == DailySummaryStatus.izin) {
```

**Scope of change:** 1 file, 2 insertions, 1 deletion. No other files modified. No regressions
detected on the 10 previously passing must-haves (see regression checks below).

---

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|---------|
| 1  | Employee on overnight shift (masuk 22:00, pulang 06:00 next day) can scan pulang without kiosk showing Masuk mid-shift | VERIFIED | `_loadLastAttendance` uses `.gte('scanned_at', cutoff)` 24h window at line 101 of `kiosk_scan_screen.dart`; `isSameDay` absent |
| 2  | After pulang is recorded, next scan always shows Masuk (new cycle) | VERIFIED | `_buildSmartButtons` case `AttendanceType.pulang` → shows Masuk button; 24h window ensures pulang recorded recently sets `_lastType = pulang` |
| 3  | If employee's last masuk was more than 24 hours ago with no pulang, next scan shows Masuk (safety net) | VERIFIED | When no row found in 24h window, `_lastType` stays null; switch `null` → Masuk button |
| 4  | No calendar-day boundary causes incorrect Masuk reset during an active shift | VERIFIED | `isSameDay` variable and conditional fully removed; only time-window constraint used |
| 5  | Rekap Harian shows 'Belum Pulang' badge for past-date entries where firstMasuk != null and lastPulang == null | VERIFIED | `belumPulang` enum variant, detection, and tile rendering all implemented. The `dayNotes` crash is **fixed** — line 431 now guards `firstWhere` to sakit/izin only (commit d554797) |
| 6  | Today's active shift does NOT show Belum Pulang badge mid-day | VERIFIED | `isToday` guard at lines 418-421 correctly prevents `belumPulang` assignment for today's date. Previously blocked by crash — now reachable |
| 7  | Belum Pulang tile shows masuk time alongside the badge (4-cell layout preserved with amber indicator) | VERIFIED | Tile branch at line 1144 routes sakit/izin to `_buildStatusBadge()`; belumPulang stays in 4-cell row; amber chip replaces Pulang cell at line 1164 |
| 8  | Normal days (masuk + pulang) still render the 4-cell row unchanged | VERIFIED | Normal status takes the `else` branch in tile at line 1148; unmodified |
| 9  | Admin dashboard shows list of employees who scanned masuk in last 32h but never scanned pulang | VERIFIED | `_loadOpenShifts` uses `Duration(hours: 32)` cutoff at line 156; open-session detection groups by employee_id |
| 10 | Each open shift entry displays employee name, masuk time, and 'Tutup Shift' action | VERIFIED | `_buildOpenShiftRow` renders avatar + name + masuk time + hoursAgo + TextButton 'Tutup Shift' at line 689 |
| 11 | Admin can tap 'Tutup Shift', confirm, and a pulang record is inserted to Supabase | VERIFIED | `_manualPulang` shows AlertDialog, on confirm inserts to `attendance_logs` with `type: 'pulang'`, `is_backup: false` at lines 210-282 |
| 12 | If there are zero open shifts, the widget is not shown | VERIFIED | `_buildOpenShiftsWidget` returns `SizedBox.shrink()` when `!_loadingOpenShifts && _openShifts.isEmpty` at line 632 |

**Score:** 12/12 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/screens/kiosk/kiosk_scan_screen.dart` | Fixed `_loadLastAttendance` using 24h window query | VERIFIED | `cutoff` at line 92-93 (`Duration(hours: 24)`), `.gte('scanned_at', cutoff)` at line 101; `isSameDay` absent from file |
| `lib/screens/admin/admin_reports_screen.dart` | `belumPulang` variant in DailySummaryStatus enum + detection + tile rendering; `dayNotes` guard fixed | VERIFIED | Enum at line 785; detection at lines 414-427; `dayNotes` guard fixed at lines 431-441 (commit d554797); tile rendering at lines 1144-1209 |
| `lib/screens/admin/admin_dashboard_screen.dart` | `_OpenShift` class, `_loadOpenShifts()`, `_manualPulang()`, `_buildOpenShiftsWidget()` | VERIFIED | All four present: `_OpenShift` at line 1809; `_loadOpenShifts` at line 150; `_manualPulang` at line 210; `_buildOpenShiftsWidget` at line 630 |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `kiosk_scan_screen.dart _loadLastAttendance` | `attendance_logs` Supabase table | `.gte('scanned_at', cutoff)` | WIRED | Line 101: `.gte('scanned_at', cutoff)` present in query chain |
| `_computeDailySummaries` | `DailySummaryStatus.belumPulang` | `isToday` check + `firstMasuk != null && lastPulang == null` | WIRED | Detection at lines 418-427; `dayNotes` crash fixed; detection now executes without error |
| `_DailySummaryTile.build` | amber chip in Pulang cell | `belumPulang` condition in if-branch in 4-cell row | WIRED | Line 1164: `if (summary.status == DailySummaryStatus.belumPulang)` renders amber chip with "Belum\nPulang" text |
| `_loadOpenShifts` | `attendance_logs` Supabase table | `.gte('scanned_at', cutoff)` with 32h window | WIRED | Line 156: `Duration(hours: 32)` cutoff, `.gte('scanned_at', cutoff)` |
| `_manualPulang` | `attendance_logs` Supabase table | `SupabaseClientFactory.admin.from('attendance_logs').insert` | WIRED | Lines 210-282: insert with `type: 'pulang'`, `is_backup: false` |
| `_buildOpenShiftsWidget` | CustomScrollView slivers list | `SliverToBoxAdapter` between `_buildStatGrid` and `_buildQuickActions` | WIRED | Line 397: order is statGrid → openShiftsWidget → quickActions |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| REQ-M1-05 | 02-01 | 24h outlet shift cycle — no midnight reset | SATISFIED | `_loadLastAttendance` 24h window implemented; `isSameDay` removed |
| REQ-M1-04 | 02-02, 02-03 | Forgot clock-out handling — admin visibility and belumPulang badge | SATISFIED | Dashboard open-shifts widget fully satisfies admin list + manual close. Rekap Harian belumPulang badge implemented and the blocking crash is now fixed. All three acceptance criteria met in code |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | No blocker anti-patterns detected | — | — |

The previously-flagged blocker (`firstWhere` without `orElse` on a `belumPulang` day) was
resolved in commit `d554797`. No new anti-patterns introduced by the fix.

---

### Regression Check (Previously Passing Items)

Quick sanity checks confirm no regressions from the single-line guard change:

- `kiosk_scan_screen.dart`: `Duration(hours: 24)` at line 93, `.gte('scanned_at', cutoff)` at line 101 — unchanged.
- `admin_dashboard_screen.dart`: `_OpenShift`, `_loadOpenShifts`, `_manualPulang`, `_buildOpenShiftsWidget`, `SizedBox.shrink()`, `Duration(hours: 32)`, `SliverToBoxAdapter` at line 397 — all unchanged.
- `admin_reports_screen.dart`: `isToday` guard (lines 418-421), amber chip render (line 1164), `DailySummaryStatus.belumPulang` enum (line 785), tile branch (line 1144) — all unchanged.

---

### Human Verification Required

All automated checks pass. The following items require a real device and live Supabase data to confirm runtime behavior.

#### 1. Rekap Harian belumPulang tile rendering

**Test:** In Admin Reports, select a date range containing yesterday. Use an employee who scanned masuk yesterday but did not scan pulang.
**Expected:** Tile shows masuk time in the Masuk cell AND an amber "Belum Pulang" chip in the Pulang cell instead of --:--. No crash occurs.
**Why human:** Requires live Supabase data. Static analysis confirms the fix is correct; runtime confirmation needed.

#### 2. Today's active shift guard

**Test:** Select today's date. Verify that an employee currently mid-shift (masuk recorded, no pulang yet) does NOT show the Belum Pulang chip.
**Expected:** Normal 4-cell row with --:-- in the Pulang cell.
**Why human:** Time-dependent behavior; requires real device with current-day attendance data.

#### 3. Admin Dashboard Open Shifts widget visibility

**Test:** Log in as admin. Ensure at least one employee has a masuk scan from within the last 32 hours but no subsequent pulang.
**Expected:** Amber "Belum Absen Pulang (N)" card visible between the stat grid and quick action chips on the dashboard.
**Why human:** Requires live Supabase data; visual placement cannot be confirmed programmatically.

#### 4. Tutup Shift manual close flow

**Test:** Tap "Tutup Shift" for an employee on the open shifts list. Enter a note and confirm.
**Expected:** Dialog shows employee name + masuk time + notes field. On confirm, pulang record inserted, widget refreshes, employee no longer appears in the list.
**Why human:** Requires live Supabase connection and verification of database write; list refresh requires UI observation.

---

### Gaps Summary

All gaps from the initial verification are closed. No gaps remain.

The single blocker gap (StateError crash in `_computeDailySummaries` when computing notes for a
`belumPulang` day) was resolved by changing the `dayNotes` guard on line 431 from
`dayStatus != DailySummaryStatus.normal` to
`dayStatus == DailySummaryStatus.sakit || dayStatus == DailySummaryStatus.izin`.

This fix is narrow and correct: `belumPulang` days do not have sakit/izin rows to extract notes
from, so excluding them from the `firstWhere` block is semantically correct as well as
crash-preventing. The change was committed as `d554797` (1 file, 2 insertions, 1 deletion).

Phase goal is achieved at the code level. Human smoke-test is the remaining gate before
considering this phase complete.

---

_Verified: 2026-03-01T13:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification: Yes — gap closure after commit d554797_
