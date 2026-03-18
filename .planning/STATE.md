---
gsd_state_version: 1.0
milestone: v4.0
milestone_name: Smart Attendance + Admin Dashboard
current_plan: Not started
status: defining_requirements
last_updated: "2026-03-18T06:00:00.000Z"
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# STATE.md — Project Memory

## Current Status
- **Milestone:** v4.0 — Smart Attendance + Admin Dashboard
- **Phase:** Not started (defining requirements)
- **Current Plan:** —
- **Last Updated:** 2026-03-18 — Milestone v4.0 started

## Progress

```
v4.0 Smart Attendance + Admin Dashboard — DEFINING REQUIREMENTS
[░░░░░░░░░░] 0/0 plans · 0/0 phases
```

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-18)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Defining requirements for v4.0

## What Was Shipped

### v3.1 (Released, 2026-03-18)
- Phase 20: Biometric Login
- Phase 21: Badge Color Picker
- Phase 22: Production Release (GitHub Release v3.1 with ABSENKOK-v3.1.0.apk)

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
| 19 | Auto-trigger biometric only when session+pref+hardware all present | Prevents prompting users who haven't opted in |
| 20 | Keep biometric_enabled on logout, clear remembered role | User shouldn't re-enable after re-login |
| 21 | Persist borderColor2 only for gradient style | Prevents hidden secondary color data from leaking into solid/glow badges |
| 22 | Keep badge color storage as #RRGGBB strings | Allows visual picker UI without changing badge model or service contracts |
| 23 | APK output path is build/app/outputs/apk/release/ not flutter-apk/ | Gradle applicationVariants rename outputs to different directory |

## Key Constraints
- Production database serving 4 outlets — NO destructive migrations
- Kotlin 1.9.25 — no upgrade (breaks nfc_manager)
- Android only — no iOS target

### Open Blockers
- None

## Accumulated Context
- Cross-day shift noon rule works correctly — "belum pulang" cases are employees forgetting to scan out, not a system bug
- Push notification for missing clock-out will address the forgotten scan-out problem
- Smart attendance algorithm is BETA — some outlets have variable schedules
- Kepala Gerai onboarding switches from SQL script to in-app Supabase Auth creation

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
