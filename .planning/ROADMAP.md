# ROADMAP.md — Absensi Enakko

## Milestones

- ✅ **v1.1 Bug Fix + Edge Cases + Features** — Phases 1-12 (shipped 2026-03-05)
- ✅ **v2.0 Admin Tools + Live Activity** — Phases 13-16 (shipped 2026-03-12)
- ✅ **v3.0 Schedule Grid + Landing Website** — Phases 17-19 (shipped 2026-03-13)
- [ ] **v3.1 Biometric Login + Badge Polish + Release** — Phases 20-22 (in progress)

## Phases

<details>
<summary>✅ v1.1 Bug Fix + Edge Cases + Features (Phases 1-12) — SHIPPED 2026-03-05</summary>

- [x] Phase 1: Rekap Harian Bug Fixes (1/1 plan) — completed 2026-03-01
- [x] Phase 2: Kiosk Scan Cycle Edge Cases (3/3 plans) — completed 2026-03-01
- [x] Phase 3: Overlay Pill Implementation (4/4 plans) — completed 2026-03-02
- [x] Phase 4: PDF Export Engine (1/1 plan executed) — completed 2026-03-04
- [x] Phase 6: NFC Idle Screen Visual Enhancement (2/2 plans) — completed 2026-03-04
- [x] Phase 7: Admin UI System Polish (3/3 plans) — completed 2026-03-04
- [x] Phase 8: Schedule System Fix + Supabase Integration (2/2 plans) — completed 2026-03-03
- [x] Phase 8.1: PDF/CSV Export Fix (2/2 plans) — completed 2026-03-04
- [x] Phase 10: Sakit/Izin Direct Input — Gap Closure (2/2 plans) — completed 2026-03-05
- [x] Phase 11: Employee Badge System — Gap Closure (3/3 plans) — completed 2026-03-05
- [x] Phase 12: Kiosk Logout Bug Fix (1/1 plan) — completed 2026-03-05

Full details: `.planning/milestones/v1.1-ROADMAP.md`

</details>

<details>
<summary>✅ v2.0 Admin Tools + Live Activity (Phases 13-16) — SHIPPED 2026-03-12</summary>

- [x] Phase 13: Soft-Archive Karyawan + Riwayat (3/3 plans) — completed 2026-03-11
- [x] Phase 14: Batch CSV Import (2/2 plans) — completed 2026-03-11
- [x] Phase 15: Kepala Gerai SQL Setup (SQL scripts) — completed 2026-03-11
- [x] Phase 16: Persistent Live Activity Pill (2/2 plans) — completed 2026-03-11

Full details: `.planning/milestones/v2.0-ROADMAP.md`

</details>

<details>
<summary>✅ v3.0 Schedule Grid + Landing Website (Phases 17-19) — SHIPPED 2026-03-13</summary>

- [x] Phase 17: Schedule Grid UI Redesign (2/2 plans) — completed 2026-03-13
- [x] Phase 18: ABSENKOK Landing Website (2/2 plans) — completed 2026-03-13
- [x] Phase 19: Website Polish — Screenshots + About/Architecture + Tech Icons (2/2 plans) — completed 2026-03-13

Full details: `.planning/milestones/v3.0-ROADMAP.md`

</details>

### v3.1 Biometric Login + Badge Polish + Release (In Progress)

**Milestone Goal:** Add biometric fast-login for admin/kepala gerai, visual badge color picker, and publish production APK to GitHub Releases.

- [x] **Phase 20: Biometric Login** — Admin/kepala gerai can unlock app with fingerprint or face after first login (completed 2026-03-18)
- [ ] **Phase 21: Badge Color Picker** — Admin picks badge border colors visually instead of typing hex codes
- [ ] **Phase 22: Production Release** — Build obfuscated APK and publish to GitHub Releases as v3.1

## Phase Details

### Phase 20: Biometric Login
**Goal**: Admin and kepala gerai can re-authenticate quickly using device biometrics instead of retyping credentials
**Depends on**: Nothing (first phase of v3.1)
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04
**Success Criteria** (what must be TRUE):
  1. Admin who previously logged in can unlock the app with fingerprint or face tap (no email/password retyping)
  2. If biometric fails or is cancelled, the email/password login form appears and works normally
  3. User can toggle "Remember me" on/off from settings, and disabling it requires password on next login
  4. On a device with no biometric sensor, the app skips biometric setup entirely and uses standard login
**Plans**: 2 plans
Plans:
- [ ] 20-01-PLAN.md — Android platform setup + BiometricService + AppProvider extensions + tests
- [ ] 20-02-PLAN.md — Login screen biometric UI + admin shell settings dialog

### Phase 21: Badge Color Picker
**Goal**: Admin can visually select badge border colors using an interactive color picker UI
**Depends on**: Nothing (independent of Phase 20)
**Requirements**: BADGE-01, BADGE-02, BADGE-03
**Success Criteria** (what must be TRUE):
  1. Admin can tap a color field and choose a badge border color from a visual color wheel or grid (no hex typing required)
  2. Admin can independently pick color1 and color2 for gradient badge styles
  3. While selecting colors, the badge preview updates in real time showing the exact result
**Plans**: 1 plan
Plans:
- [ ] 21-01-PLAN.md — Add flutter_colorpicker dependency + replace hex TextFields with visual color picker UI

### Phase 22: Production Release
**Goal**: Ship v3.1 as a production-ready APK on GitHub Releases
**Depends on**: Phase 20, Phase 21
**Requirements**: REL-01, REL-02
**Success Criteria** (what must be TRUE):
  1. Release APK builds successfully with ProGuard minification and obfuscation enabled
  2. GitHub Releases page shows v3.1 tag with the APK attached and a changelog describing biometric login and badge color picker
**Plans**: TBD

## Progress

**Execution Order:** 20 → 21 → 22 (Phase 20 and 21 are independent; Phase 22 depends on both)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 20. Biometric Login | 2/2 | Complete    | 2026-03-18 | - |
| 21. Badge Color Picker | v3.1 | 0/1 | Not started | - |
| 22. Production Release | v3.1 | 0/TBD | Not started | - |

## Future Backlog (Not Scheduled)
- Time-off request approval workflow
- Keterlambatan (late arrival) automatic flagging vs shift start time
- Overtime tracking (> 8h kerja → overtime flag)
- Push notification for missing clock-out
- Attendance rate card on admin dashboard
- Employee attendance streak tracking (gamification)
- Cross-outlet comparison chart
- WhatsApp/email daily attendance summary for outlet managers
- QR code backup when NFC fails (camera scan)
- Employee self-service portal (view own attendance history)
- Live Activity pill device debugging (code delivered, needs on-device verification)
- Schedule grid tap-to-cycle shift (GRID-D1)
- Schedule grid copy-week (GRID-D2)
- Schedule grid today-column highlight (GRID-D3)
