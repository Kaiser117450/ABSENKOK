---
phase: 53-security-rollout-acceptance
plan: "01"
subsystem: docs
tags: [security, rollout, operator-runbook, supabase, astro, flutter]
dependency_graph:
  requires:
    - 50-kiosk-device-boundary-hardening
    - 51-admin-session-trust-hardening
    - 52-portal-surface-minimization
  provides:
    - docs/security-hardening-rollout.md
    - .planning/phases/53-security-rollout-acceptance/53-USER-SETUP.md
  affects:
    - production Supabase project tmapxdftdhxovthgbhww (pending operator application)
tech_stack:
  added: []
  patterns:
    - additive-only rollout ledger
    - acceptance evidence split by finding class
key_files:
  created:
    - docs/security-hardening-rollout.md
    - .planning/phases/53-security-rollout-acceptance/53-USER-SETUP.md
  modified: []
decisions:
  - "Recovery script kept in conditional appendix, not routine rollout path"
  - "Accepted passwordless portal boundary documented as intentional, not a regression"
metrics:
  duration: "~8 minutes"
  completed: "2026-03-25"
  tasks_completed: 2
  files_changed: 2
---

# Phase 53 Plan 01: Security Hardening Rollout Checklist Summary

One-liner: Operator rollout checklist consolidating Phase 50-52 additive SQL, Astro, and Flutter hardening gates into a single auditable sequence with conditional recovery script in appendix.

## What Was Built

**Task 1 — Canonical security hardening rollout checklist (`docs/security-hardening-rollout.md`)**

Created the single operator-facing checklist for rolling out the Phase 50-52 security hardening against the live production Supabase project. The document covers:

- Scope boundary: Phase 53 is rollout-and-acceptance only, not new hardening
- Prerequisites: production approval, additive-only SQL rule, pre-rollout Astro and Flutter checks
- Ordered rollout sequence: Phase 50 SQL -> Phase 51 SQL -> Phase 52 SQL (recovery script in Appendix A only)
- Astro gate: `npm run check` and `npm run build` with explicit pass criteria
- Flutter gate: four targeted test files plus reference to `docs/android-release-runbook.md` for release lane
- Evidence table for the closeout packet
- Accepted findings section (passwordless portal, local-only logout) explicitly not treated as regressions

**Task 2 — Phase-local user setup note (`.planning/phases/53-security-rollout-acceptance/53-USER-SETUP.md`)**

Created the production handoff note for the live rollout window. The document covers:

- Status: Incomplete header with production project ID `tmapxdftdhxovthgbhww`
- Three ordered Supabase SQL steps matching the canonical checklist exactly
- Conditional recovery script step clearly separated with approval requirement
- Evidence checklist: SQL confirmation, Astro verification, Flutter test results, accepted-risk notes

## Decisions Made

1. **Recovery script in conditional appendix only.** `sql/repair_employee_portal_accounts_20260325.sql` sits next to the rollout SQL files but is not part of the normal three-step sequence. It appears in Appendix A with explicit conditions: broken `employee_portal_accounts` row, confirmed metadata match, and explicit production approval.

2. **Accepted findings named explicitly.** Passwordless portal sign-in and local-only portal logout are documented as intentional product decisions in both artifacts. They must appear in the acceptance packet as accepted findings, not open issues.

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- `docs/security-hardening-rollout.md` pattern check: 17 matches for all 7 required patterns (all four SQL filenames, `npm run check`, `npm run build`, `android-release-runbook.md`)
- `53-USER-SETUP.md` pattern check: 11 matches for all 5 required patterns (`Status: Incomplete`, `tmapxdftdhxovthgbhww`, `repair_employee_portal_accounts_20260325.sql`, `SQL Editor`, `passwordless`)

## Self-Check: PASSED

- `docs/security-hardening-rollout.md` exists: FOUND
- `.planning/phases/53-security-rollout-acceptance/53-USER-SETUP.md` exists: FOUND
- Task 1 commit `be72773` exists: FOUND
- Task 2 commit `c511c76` exists: FOUND
