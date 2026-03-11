# ROADMAP.md — Absensi Enakko

## Milestones

- ✅ **v1.1 Bug Fix + Edge Cases + Features** — Phases 1-12 (shipped 2026-03-05)
- [ ] **v2.0 Admin Tools + Live Activity** — Phases 13-16

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

### v2.0 Admin Tools + Live Activity

- [ ] **Phase 13: Soft-Archive Karyawan + Riwayat** — Admin can archive/restore employees with full history preservation
- [ ] **Phase 14: Batch CSV Import** — Admin can onboard multiple karyawan at once via CSV with validation and preview
- [ ] **Phase 15: Kepala Gerai SQL Setup** — SQL script to promote outlet manager to Kepala Gerai admin role
- [ ] **Phase 16: Persistent Live Activity Pill** — Dynamic Island-style overlay with real-time break status and fun facts

## Phase Details

### Phase 13: Soft-Archive Karyawan + Riwayat
**Goal**: Admin can manage employee lifecycle — archive departing karyawan, preserve full attendance history, and restore when needed
**Depends on**: Nothing (foundational data model change — all subsequent phases build on this)
**Requirements**: ARCH-01, ARCH-02, ARCH-03, ARCH-04, ARCH-05, ARCH-06
**Success Criteria** (what must be TRUE):
  1. Admin archives a karyawan → employee disappears from active employee list and schedule selectors immediately
  2. Archived karyawan taps NFC card → scan rejected with clear "Karyawan tidak aktif" message (not silently ignored, not accepted even with stale cache)
  3. Admin opens Riwayat Karyawan page → sees all archived employees with their complete attendance history preserved and browsable
  4. Admin restores an archived karyawan → employee reappears in active list, can be scheduled, and can clock in again via NFC
  5. Archive confirmation dialog displays count of upcoming scheduled shifts that will be removed for that employee
**Plans**: 3 plans in 2 waves

Plans:
- [ ] 13-01-PLAN.md — Database migration + Employee model update (Wave 1)
- [ ] 13-02-PLAN.md — Archive actions + admin UI (Wave 2)
- [ ] 13-03-PLAN.md — Riwayat Karyawan screen (Wave 2)

### Phase 14: Batch CSV Import
**Goal**: Admin can onboard multiple karyawan at once via CSV file upload with full validation, preview, and error reporting
**Depends on**: Phase 13 (imported employees use `is_archived: false` field; archive model must exist)
**Requirements**: CSV-01, CSV-02, CSV-03, CSV-04, CSV-05, CSV-06
**Success Criteria** (what must be TRUE):
  1. Admin uploads a CSV file with 10 employees → preview screen shows all parsed rows with per-row validation status before any database write happens
  2. CSV row with misspelled or unknown outlet name → that row is flagged with "outlet not found" error and blocked from inserting
  3. CSV with duplicate employee (same nama + same outlet as existing) → flagged as duplicate, admin sees which rows conflict
  4. Admin confirms valid rows → employees appear in active employee list with correct outlet assignment, position, and photo URL
**Plans**: TBD

### Phase 15: Kepala Gerai SQL Setup
**Goal**: Any outlet manager can be promoted to Kepala Gerai admin role via a SQL script run in Supabase dashboard — zero app code changes
**Depends on**: Nothing (independent of all other phases; zero Flutter code)
**Requirements**: ADMIN-01
**Success Criteria** (what must be TRUE):
  1. Running the SQL script with a target Gmail address and outlet ID → that user can log in as Kepala Gerai and sees only their assigned outlet's employees, schedules, and reports
  2. Existing superadmin users retain full cross-outlet access after the script is run — no regression
**Plans**: TBD

### Phase 16: Persistent Live Activity Pill
**Goal**: Kiosk tablet shows a persistent Dynamic Island-style overlay pill outside the app with real-time break status and rotating idle content
**Depends on**: Phase 13 (needs stable employee data model; benefits from Phases 13-15 being production-tested)
**Requirements**: LIVE-01, LIVE-02, LIVE-03, LIVE-04
**Success Criteria** (what must be TRUE):
  1. Kiosk is running → overlay pill is visible on home screen and other apps (outside the Absensi Enakko app), not just inside the app
  2. Employee starts break (istirahat) → overlay pill shows employee name and "Istirahat" status within 30 seconds, updates automatically
  3. No employees currently on break → overlay pill cycles through fun facts and daily attendance stats (e.g., "Hari ini 12/14 hadir 🎉") every 30 seconds
  4. Overlay pill runs for 24+ hours continuously without memory growth, ANR, or being killed by OEM battery optimization on target tablets

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|---------------|--------|-----------|
| 1. Rekap Harian Bug Fixes | v1.1 | 1/1 | Complete | 2026-03-01 |
| 2. Kiosk Scan Cycle Edge Cases | v1.1 | 3/3 | Complete | 2026-03-01 |
| 3. Overlay Pill Implementation | v1.1 | 4/4 | Complete | 2026-03-02 |
| 4. PDF Export Engine | v1.1 | 1/1 | Complete | 2026-03-04 |
| 6. NFC Idle Screen Visual | v1.1 | 2/2 | Complete | 2026-03-04 |
| 7. Admin UI System Polish | v1.1 | 3/3 | Complete | 2026-03-04 |
| 8. Schedule System Fix | v1.1 | 2/2 | Complete | 2026-03-03 |
| 8.1. PDF/CSV Export Fix | v1.1 | 2/2 | Complete | 2026-03-04 |
| 10. Sakit/Izin Direct Input | v1.1 | 2/2 | Complete | 2026-03-05 |
| 11. Employee Badge System | v1.1 | 3/3 | Complete | 2026-03-05 |
| 12. Kiosk Logout Bug Fix | v1.1 | 1/1 | Complete | 2026-03-05 |
| 13. Soft-Archive Karyawan + Riwayat | v2.0 | 0/3 | Not started | - |
| 14. Batch CSV Import | v2.0 | 0/? | Not started | - |
| 15. Kepala Gerai SQL Setup | v2.0 | 0/? | Not started | - |
| 16. Persistent Live Activity Pill | v2.0 | 0/? | Not started | - |

## Future Backlog (Not Scheduled)
- Schedule UI full grid redesign (week-view grid, tap-to-assign cells)
- Time-off request approval workflow
- Keterlambatan (late arrival) automatic flagging vs shift start time
- Overtime tracking (> 8h kerja → overtime flag)
- Push notification for missing clock-out
- Attendance rate card on admin dashboard
- Employee attendance streak tracking (gamification)
- Cross-outlet attendance comparison chart
- WhatsApp/email daily attendance summary for outlet managers
- QR code backup when NFC fails (camera scan)
- Employee self-service portal (view own attendance history)
