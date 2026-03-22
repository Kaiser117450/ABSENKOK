---
phase: 33
slug: multi-outlet-control-center
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-22
approved: 2026-03-22
approved_by: Phase 36 evidence — 2026-03-22
---

# Phase 33 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | `pubspec.yaml` -> `dev_dependencies: flutter_test` |
| **Quick run command** | `C:\flutter\bin\flutter.bat test test/services/analytics_service_test.dart test/screens/admin/central_dashboard_screen_test.dart` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run `C:\flutter\bin\flutter.bat test test/services/analytics_service_test.dart test/screens/admin/central_dashboard_screen_test.dart`
- **After every plan wave:** Run `C:\flutter\bin\flutter.bat test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 33-01-01 | 01 | 1 | ADMIN-01, ADMIN-02 | unit | `C:\flutter\bin\flutter.bat test test/services/analytics_service_test.dart` | ✅ | ✅ green |
| 33-01-02 | 01 | 1 | ADMIN-01, ADMIN-02 | static | `powershell -Command "Select-String -Path 'sql/phase_33_central_dashboard_20260322.sql' -Pattern 'CREATE OR REPLACE FUNCTION get_central_dashboard_summary','CREATE OR REPLACE FUNCTION get_outlet_control_center','SECURITY DEFINER'"` | ✅ | ✅ green |
| 33-02-01 | 02 | 2 | ADMIN-01, ADMIN-02 | widget | `C:\flutter\bin\flutter.bat test test/screens/admin/central_dashboard_screen_test.dart` | ✅ | ✅ green |
| 33-02-02 | 02 | 2 | ADMIN-01 | analyze | `C:\flutter\bin\flutter.bat analyze lib/screens/admin/central_dashboard_screen.dart lib/widgets/outlet_control_card.dart lib/screens/admin/admin_dashboard_screen.dart lib/app.dart lib/screens/admin/admin_shell.dart` | ✅ | ✅ green |
| 33-02-03 | 02 | 2 | ADMIN-01 | manual | N/A | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

- [x] `test/screens/admin/central_dashboard_screen_test.dart` — widget coverage for central summary rendering, outlet rollup cards, and drilldown tap behavior (completed Phase 33-02, 2026-03-22)

Existing Flutter test infrastructure already covers the rest of the phase. No new framework install is needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full admin lands on central dashboard at `/admin/dashboard` | ADMIN-01 | Requires real role-aware navigation flow | 1. Sign in as full admin 2. Open dashboard 3. Confirm central summary cards appear instead of the old outlet dashboard |
| Tapping an outlet row opens a specific outlet detail dashboard | ADMIN-01 | Requires end-to-end route + screen integration | 1. Tap one outlet card 2. Confirm detail dashboard opens with that outlet preselected |
| Kepala gerai still sees only outlet-scoped dashboard | ADMIN-01 | Requires real auth metadata + role gating | 1. Sign in as kepala_gerai 2. Open dashboard 3. Confirm no central-admin rollup view is shown |
| Firm-wide daily attendance rate reflects live production data | ADMIN-02 | Depends on deployed RPC plus real attendance rows | 1. Open central dashboard after SQL migration 2. Compare displayed rate with Supabase query / expected known sample |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 20s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** Phase 33 accepted — 2026-03-22. Central dashboard routing, outlet drilldown, kepala_gerai role gate, and firm-wide KPI data path confirmed via Phase 36 evidence chain (36-VALIDATION.md, 2026-03-22).
