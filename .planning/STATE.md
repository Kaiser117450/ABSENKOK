---
gsd_state_version: 1.0
milestone: v3.1
milestone_name: Biometric Login + Badge Polish + Release
current_plan: 20-02
status: executing
last_updated: "2026-03-18T04:15:39.000Z"
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 2
  completed_plans: 1
---

# STATE.md — Project Memory

## Current Status
- **Milestone:** v3.1 — Biometric Login + Badge Polish + Release
- **Phase:** 20 of 22 (Biometric Login) — Plan 2 of 2
- **Current Plan:** 20-02 (Biometric Login UI)
- **Last Updated:** 2026-03-18 — Completed 20-01 (Biometric Foundation)

## Progress

```
v3.1 Biometric Login + Badge Polish + Release — EXECUTING
[█████░░░░░] 1/2 plans · 0/3 phases
```

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-18)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Phase 20 — Biometric fast-login for admin/kepala gerai

## What Was Shipped

### v3.0 (2026-03-13)
- Phase 17: Schedule Grid UI Redesign
- Phase 18: ABSENKOK Landing Website
- Phase 19: Website Polish

### v2.0 (2026-03-12)
- Phase 13-16: Soft-archive, CSV Import, Kepala Gerai SQL, Live Activity Pill

### v1.1 (2026-03-05)
- Phase 1-12: Bug fixes, overlay pill, PDF/CSV reports, kiosk polish, admin UI, badges, logout resilience

### Security Fixes (2026-03-18)
- 17 Codex security PRs merged: role escalation fix, outlet scoping, CSV injection, PII redaction, badge hardening, crash guards

## Key Decisions (Cumulative)

| # | Decision | Rationale |
|---|----------|-----------|
| 4 | SharedPreferences over FlutterSecureStorage | Eliminates ANR |
| 11 | two_dimensional_scrollables for grid | Official Flutter team package |
| 16 | Codex security fixes merged before v3.1 | Clean baseline for new features |
| 17 | Catch Exception broadly in BiometricService | local_auth v3 throws different types than PlatformException |
| 18 | local_auth v3.0.1 direct params API | AuthenticationOptions removed in v3; use biometricOnly/persistAcrossBackgrounding |

## Key Constraints
- Production database serving 4 outlets — NO destructive migrations
- Kotlin 1.9.25 — no upgrade (breaks nfc_manager)
- Android only — no iOS target

### Open Blockers
- None

## Database Safety Rules
- Sistem absensi SEDANG BERJALAN di production (4 gerai, karyawan aktif)
- **WAJIB konfirmasi ke user sebelum setiap perubahan database**
- Selalu jalankan migration additive (tidak merusak data yang ada)

## Supabase Project
- Project ID: `tmapxdftdhxovthgbhww`
- Region: ap-south-1 (Mumbai)
- Status: ACTIVE_HEALTHY

## File Locations
- Flutter project: `absensi apk/absensi_enakko_flutter/`
- Planning: `absensi apk/absensi_enakko_flutter/.planning/`
- Website project: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\`
- Codebase map: `.planning/codebase/`
- Milestones archive: `.planning/milestones/`
- SQL scripts: `sql/`
