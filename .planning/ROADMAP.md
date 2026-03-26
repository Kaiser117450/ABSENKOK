# Roadmap: Absensi Enakko

## Shipped Milestones

- ✅ **v7.1 Security Hardening** — Phases 50-53, shipped 2026-03-25 ([roadmap archive](.planning/milestones/v7.1-ROADMAP.md), [requirements archive](.planning/milestones/v7.1-REQUIREMENTS.md))
- ✅ **v7.0 Android Release Hardening** — Phases 46-49 plus 48.1, shipped 2026-03-25 ([roadmap archive](.planning/milestones/v7.0-ROADMAP.md), [requirements archive](.planning/milestones/v7.0-REQUIREMENTS.md))

## Active Milestone

### v8.0 Strict Attendance & Payroll Reporting

**Goal:** Convert attendance into a contract-aware, server-time, overnight-safe payroll reporting system with strict red/yellow enforcement for lateness, short work, excess break, overtime, and absence.
**Phases:** 54-60
**Requirements:** 17 mapped / 17 total

## Current Position

- Active milestone is now **v8.0 Strict Attendance & Payroll Reporting**.
- This milestone replaces the current generic overtime and device-local recap assumptions with explicit `FULLTIME` / `PARTTIME` employee contracts and `NORMAL` / `TWENTY_FOUR_HOUR` outlet modes.
- Payroll-facing recap exports will move from flat CSV to spreadsheet/PDF parity with employee-by-date summaries and aggregate violation counts.

## Proposed Roadmap

**7 phases** | **17 requirements mapped** | All covered

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 54 | Workforce Contract & Outlet Mode Foundation | Add the new employee and outlet rule metadata without breaking the live attendance baseline | `CONTRACT-01`, `CONTRACT-02` | 4 |
| 55 | Schedule Policy & Absence Rules | Rebuild mandatory schedule logic around shift bands, lateness windows, and no-show detection | `SCHED-01`, `SCHED-02`, `SCHED-03` | 4 |
| 56 | Server-Time Scan Authority | Move scan timing to WITA server authority and capture break-first intent safely | `SCAN-01`, `SCAN-02` | 4 |
| 57 | Strict Recap Evaluation Engine | Compute overnight-safe, contract-aware red/yellow attendance outcomes including manager exemptions | `CONTRACT-03`, `RECAP-01`, `RECAP-02`, `RECAP-03`, `RECAP-04` | 4 |
| 58 | Payroll Matrix & Spreadsheet Export | Rebuild Rekap Harian around salary-ready employee/date matrices and spreadsheet output | `REPORT-01`, `REPORT-02` | 4 |
| 59 | PDF & Portal Parity | Align PDF and portal surfaces with the new contract-aware rules and remove stale fixed shift clocks | `SCHED-04`, `REPORT-03` | 4 |
| 60 | Rollout & Payroll Acceptance | Validate live-safe rollout, overnight edge cases, and export parity before salary use | `OPS-01` | 4 |

### Phase 54: Workforce Contract & Outlet Mode Foundation

**Status:** Pending
**Goal:** Add the new employee and outlet rule metadata without breaking the live attendance baseline.
**Depends on:** v7.1 closeout baseline
**Requirements:** `CONTRACT-01`, `CONTRACT-02`
**Plans:** Pending phase planning

Success criteria:
1. Employee data can persist and read one explicit contract value, `FULLTIME` or `PARTTIME`, through additive migrations and typed models.
2. Outlet data can persist and read one operating-mode value, `NORMAL` or `TWENTY_FOUR_HOUR`, without regressing current admin functionality.
3. Admin and kepala gerai surfaces expose those fields with safe defaults for existing live records.
4. Attendance and reporting services have one shared model layer for contract and outlet-mode metadata instead of ad-hoc heuristics.

### Phase 55: Schedule Policy & Absence Rules

**Status:** Pending
**Goal:** Rebuild mandatory schedule logic around shift bands, lateness windows, and no-show detection.
**Depends on:** Phase 54
**Requirements:** `SCHED-01`, `SCHED-02`, `SCHED-03`
**Plans:** Pending phase planning

Success criteria:
1. Schedule storage and admin UI stop depending on stale exact clock labels and instead represent the intended pagi, siang, or sore work band plus required hours.
2. Morning, siang, and sore lateness rules evaluate from WITA business rules, including the morning hard cutoff at 07:00.
3. Scheduled employees with no logs for the logical workday resolve to `tidak_hadir` while sakit, izin, libur, and cuti remain distinct states.
4. Existing scheduling workflows for kepala gerai remain additive and backwards-compatible for live outlets.

### Phase 56: Server-Time Scan Authority

**Status:** Pending
**Goal:** Move scan timing to WITA server authority and capture break-first intent safely.
**Depends on:** Phase 55
**Requirements:** `SCAN-01`, `SCAN-02`
**Plans:** Pending phase planning

Success criteria:
1. Kiosk scan creation and sync paths use one server-authoritative WITA timestamp source instead of trusting the tablet clock.
2. Break-first cases can be confirmed and recorded without slowing the normal tap workflow.
3. A missing initial break can no longer silently turn into a false on-time or false late result in recap calculations.
4. Offline-safe behavior remains defined so later sync still preserves the authoritative event order.

### Phase 57: Strict Recap Evaluation Engine

**Status:** Pending
**Goal:** Compute overnight-safe, contract-aware red/yellow attendance outcomes including manager exemptions.
**Depends on:** Phase 56
**Requirements:** `CONTRACT-03`, `RECAP-01`, `RECAP-02`, `RECAP-03`, `RECAP-04`
**Plans:** Pending phase planning

Success criteria:
1. Afternoon-to-morning sessions at 24-hour outlets stay attached to one logical workday instead of becoming false overtime or zero-work records after midnight.
2. Full-time and part-time employees receive the specified red/yellow evaluation rules for short work, excess break, and overtime.
3. Kepala toko / kepala gerai recap rows never turn red for lateness, short work, or excess break while still remaining visible in reporting.
4. Recap outputs distinguish late, short work, excess break, overtime, absence, and exempt cases as separate payroll signals.

### Phase 58: Payroll Matrix & Spreadsheet Export

**Status:** Pending
**Goal:** Rebuild Rekap Harian around salary-ready employee/date matrices and spreadsheet output.
**Depends on:** Phase 57
**Requirements:** `REPORT-01`, `REPORT-02`
**Plans:** Pending phase planning

Success criteria:
1. Rekap Harian admin view renders employees on the left and selected dates across the page with compact masuk/pulang content in each cell.
2. Spreadsheet export replaces recap CSV export and preserves the same per-day red/yellow outcome colors.
3. Per-employee summary columns count how many times each violation or overtime state occurred across the selected range.
4. Payroll-facing exports exclude GPS and other low-signal scan details that are irrelevant for salary review.

### Phase 59: PDF & Portal Parity

**Status:** Pending
**Goal:** Align PDF and portal surfaces with the new contract-aware rules and remove stale fixed shift clocks.
**Depends on:** Phase 58
**Requirements:** `SCHED-04`, `REPORT-03`
**Plans:** Pending phase planning

Success criteria:
1. Portal schedule and attendance surfaces show contract-required hours plus remaining or already-worked time without stale exact shift ranges.
2. PDF recap uses the same contract-aware, overnight-safe, red/yellow evaluation engine as the spreadsheet export.
3. PDF recap stays compact and payroll-facing, with no GPS or technical scan fields on the recap surface.
4. Portal, admin recap, spreadsheet, and PDF agree on the same outcome for the same logical workday.

### Phase 60: Rollout & Payroll Acceptance

**Status:** Pending
**Goal:** Validate live-safe rollout, overnight edge cases, and export parity before salary use.
**Depends on:** Phase 59
**Requirements:** `OPS-01`
**Plans:** Pending phase planning

Success criteria:
1. Production rollout is documented as additive-only and explicitly gates any database change behind user confirmation.
2. Acceptance covers full-time, part-time, overtime, 24-hour outlet, normal outlet, break-first, and no-show scenarios.
3. Validation confirms parity across admin matrix, spreadsheet export, PDF export, and portal presentation.
4. The milestone closes with a clear operational checklist before payroll decisions rely on the new recap outputs.

<details>
<summary>✅ v7.1 Security Hardening (Phases 50-53) — SHIPPED 2026-03-25</summary>

- [x] Phase 50: Kiosk Device Boundary Hardening (2/2 plans) — completed 2026-03-25
- [x] Phase 51: Admin Session Trust Hardening (2/2 plans) — completed 2026-03-25
- [x] Phase 52: Portal Surface Minimization (3/3 plans) — completed 2026-03-25
- [x] Phase 53: Security Rollout & Acceptance (3/3 plans) — completed 2026-03-25

</details>

<details>
<summary>✅ v7.0 Android Release Hardening (Phases 46-49, 48.1) — SHIPPED 2026-03-25</summary>

- [x] Phase 46: Release Baseline Recovery (2/2 plans)
- [x] Phase 47: Toolchain Contract & Preflight Gates (3/3 plans)
- [x] Phase 48: Secure Signing & Artifact Discipline (3/3 plans)
- [x] Phase 48.1: APK-First Release Artifact Alignment (2/2 plans)
- [x] Phase 49: Release Runbook & Acceptance (2/2 plans)

</details>

---
_For current project status, see `.planning/PROJECT.md`_
_For full milestone history, see `.planning/MILESTONES.md`_
