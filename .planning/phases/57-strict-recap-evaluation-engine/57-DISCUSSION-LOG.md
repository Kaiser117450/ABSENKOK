# Phase 57: Strict Recap Evaluation Engine - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 57-strict-recap-evaluation-engine
**Areas discussed:** Overnight attachment, manager exemption, signal composition, work calculation, incomplete attendance, unscheduled attendance

---

## Overnight attachment

### After-midnight carry-forward at 24-hour outlets

| Option | Description | Selected |
|--------|-------------|----------|
| Sampai shift baru | Keep post-midnight scans on the prior logical day until a clearly new work context starts | ✓ |
| Sampai cutoff pagi | Use one fixed morning cutoff for all overnight carry-forward | |
| Sampai scan pulang | Keep everything on the old day until the first checkout scan appears | |

**User's choice:** Sampai shift baru
**Notes:** 24-hour carry-forward should end on a real new-shift boundary, not on an arbitrary clock threshold.

### What creates a new logical workday

| Option | Description | Selected |
|--------|-------------|----------|
| Shift baru jelas | Split only when a clearly new work context starts, such as a fresh `masuk` chain or closed prior chain | ✓ |
| Selalu review | Mark the split as manual review instead of deciding automatically | |
| Tetap hari lama | Keep all next-morning activity attached to the old day unless someone intervenes | |

**User's choice:** Shift baru jelas
**Notes:** The engine should use an explicit new-work context instead of blindly carrying everything forward.

### Carry-over at normal outlets

| Option | Description | Selected |
|--------|-------------|----------|
| Tidak boleh | Overnight carry-over belongs only to `TWENTY_FOUR_HOUR` outlets | ✓ |
| Boleh terbatas | Allow carry-over at normal outlets when the scan chain looks continuous | |
| Boleh semua | Treat normal and 24-hour outlets the same for overnight carry-over | |

**User's choice:** Tidak boleh
**Notes:** `NORMAL` outlets must stay same-day and not inherit the 24-hour grouping rules.

---

## Manager exemption

### Source of truth for exempt managers

| Option | Description | Selected |
|--------|-------------|----------|
| Jabatan karyawan | Identify exemption from the employee's stored job title / position | ✓ |
| Role login | Identify exemption from auth login role only | |
| Flag khusus | Add a dedicated explicit exemption flag | |

**User's choice:** Jabatan karyawan
**Notes:** The exemption should follow the attendance row's employee identity, not only people who have login roles.

### Which negative signals remain visible

| Option | Description | Selected |
|--------|-------------|----------|
| Tetap lihat semua | Show late / short / break as visible audit signals while suppressing red penalties | |
| Sembunyikan negatif | Do not show late / short / break as normal negative signals for exempt managers | ✓ |
| Hanya overtime | Keep only overtime visible | |

**User's choice:** Sembunyikan negatif
**Notes:** Exempt managers should not read like ordinary penalized rows for late / short / break behavior.

### How exempt rows should appear

| Option | Description | Selected |
|--------|-------------|----------|
| Signal plus exempt | Keep visible signal context plus an explicit exempt marker | ✓ |
| Exempt saja | Show only the exempt label with no context | |
| Section terpisah | Move exempt managers into a separate recap section | |

**User's choice:** Signal plus exempt
**Notes:** The exempt marker should remain explicit on the row so payroll reviewers can see why the row is not penalized.

### Clarification for late / short / break detail on manager rows

| Option | Description | Selected |
|--------|-------------|----------|
| Exempt plus info | Keep exempt as the row's strict meaning, but allow non-penal informational notes about late / short / break | ✓ |
| Exempt only | Suppress those details entirely | |
| Normal signals | Show negative details exactly like ordinary staff rows | |

**User's choice:** Exempt plus info
**Notes:** The user confirmed that manager rows may retain informational context, but not strict negative penalty styling for late / short / break.

---

## Signal composition

### Shape of the strict recap result

| Option | Description | Selected |
|--------|-------------|----------|
| Primary plus detail | One dominant status with all active payroll signals preserved as additional detail | ✓ |
| Semua setara | No dominant status; all signals are shown at the same level | |
| Satu label final | Collapse the entire day into one final label | |

**User's choice:** Primary plus detail
**Notes:** The engine must preserve multiple payroll signals without losing a quick headline status.

### Severity for late and absence

| Option | Description | Selected |
|--------|-------------|----------|
| Late kuning | `late` is yellow, `absence` is red | |
| Late merah | `late` and `absence` are both red | ✓ |
| Late netral | `late` is informational only | |

**User's choice:** Late merah
**Notes:** The user explicitly wants lateness to remain a red strict signal.

### Part-time overtime and break allowance

| Option | Description | Selected |
|--------|-------------|----------|
| Naik jadi 2 jam | Part-time overtime days inherit a 2-hour break allowance while overtime remains a separate signal | ✓ |
| Tetap 1 jam | Part-time break allowance never changes, even on overtime days | |
| Overtime ganti semua | Overtime replaces other work-duration penalties | |

**User's choice:** Naik jadi 2 jam
**Notes:** Overtime expands the break allowance for that part-time day but does not erase the signal model.

### Primary signal precedence

| Option | Description | Selected |
|--------|-------------|----------|
| Severity tertinggi | Choose the primary status from the highest active severity | ✓ |
| Absence dulu | Always prioritize absence before other severity logic | |
| Urutan bisnis | Use a custom fixed business order instead of severity | |

**User's choice:** Severity tertinggi
**Notes:** Secondary signals remain attached even after the primary headline is chosen.

---

## Work calculation

### How total break is calculated

| Option | Description | Selected |
|--------|-------------|----------|
| Pair break-kembali | Sum real paired break intervals only | ✓ |
| Envelope total | Use the older first-break to last-return envelope | |
| Simple fallback | Keep the existing simpler recap approximation | |

**User's choice:** Pair break-kembali
**Notes:** The user chose a more payroll-precise break model than the older recap approximation.

### How net work is calculated

| Option | Description | Selected |
|--------|-------------|----------|
| Span minus break | Calculate from first `masuk` to final `pulang`, then subtract total break | ✓ |
| Segmen kerja saja | Use only explicitly complete work segments | |
| Raw presence | Use gross presence time without fully subtracting break | |

**User's choice:** Span minus break
**Notes:** Net work stays tied to the full attendance span, then corrected by real break intervals.

### How overtime is decided

| Option | Description | Selected |
|--------|-------------|----------|
| Net work final | Decide overtime from final net work after break handling | ✓ |
| Raw span | Decide overtime from gross presence time only | |
| Pulang only | Require a final checkout and long gross span before overtime exists | |

**User's choice:** Net work final
**Notes:** Overtime is a post-break calculation, not a raw presence calculation.

---

## Incomplete attendance

### Historical incomplete days

| Option | Description | Selected |
|--------|-------------|----------|
| Pending review | Keep incomplete historical days as review-only with no strict final verdict | |
| Langsung merah | Past incomplete days may resolve directly to red once the day is over | ✓ |
| Best effort | Force a final payroll verdict from partial data | |

**User's choice:** Langsung merah
**Notes:** Historical incomplete attendance can become a red strict outcome after the logical workday closes.

### Current-day incomplete chains

| Option | Description | Selected |
|--------|-------------|----------|
| Info only | Keep active-day incomplete states informational until the day ends | ✓ |
| Warn early | Show an early payroll warning before the day ends | |
| Final now | Lock a final verdict while the day is still active | |

**User's choice:** Info only
**Notes:** Active in-progress days must remain non-final.

### `break` without `kembali`

| Option | Description | Selected |
|--------|-------------|----------|
| Incomplete review | Treat it as an incomplete review state rather than a final verdict | |
| Excess break | Treat it as a finalized excess-break violation | |
| Break sampai pulang | Assume the break continues until checkout / end of day | |

**User's choice:** Free-text clarification
**Notes:** The user specified: for `NORMAL` outlets, if a `break` has no matching `kembali`, treat it as `belum absen pulang` when the logical workday ends. The user then confirmed that interpretation explicitly.

---

## Unscheduled attendance

### Payroll treatment for `hadir tanpa jadwal`

| Option | Description | Selected |
|--------|-------------|----------|
| Netral plus review | Keep it visible and review-worthy instead of auto-classifying it as ordinary scheduled work | ✓ |
| Langsung overtime | Treat every unscheduled attendance day as overtime | |
| Langsung merah | Treat unscheduled attendance as an automatic red violation | |

**User's choice:** Netral plus review
**Notes:** The day should remain visibly special rather than collapsing into ordinary `hadir`.

### Whether contract baseline still applies

| Option | Description | Selected |
|--------|-------------|----------|
| Tidak dipakai | No short-work / break-limit baseline without a schedule | |
| Pakai kontrak | Keep using the employee's contract baseline even without a schedule | ✓ |
| Hanya short work | Apply only some of the contract rules | |

**User's choice:** Pakai kontrak
**Notes:** The engine should still compute contract-based work / break metrics for unscheduled days.

### How `hadir tanpa jadwal` appears in recap

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated signal | Keep a dedicated unscheduled-attendance marker separate from normal hadir | ✓ |
| Masuk normal | Display it like ordinary attendance | |
| Kelompok terpisah | Move it outside the main recap flow | |

**User's choice:** Dedicated signal
**Notes:** The unscheduled marker should stay explicit even when other strict signals coexist.

### Clarification for contract-metric usage on unscheduled days

| Option | Description | Selected |
|--------|-------------|----------|
| Info review only | Compute the metrics but keep them non-penal | |
| Strict signals too | Allow contract-based strict signals to coexist with the unscheduled marker | ✓ |
| Overtime only | Only overtime may surface on unscheduled rows | |

**User's choice:** Strict signals too
**Notes:** The user clarified that unscheduled attendance should stay special, but strict signals may still appear on top of the contract-based calculations.

---

## the agent's Discretion

- Exact storage shape for multiple strict signals on one day
- Exact same-severity tie-break ordering for the primary headline signal
- Exact admin-facing copy and chip labels

## Deferred Ideas

None - discussion stayed inside Phase 57 scope.
