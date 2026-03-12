# ROADMAP.md — Absensi Enakko

## Milestones

- ✅ **v1.1 Bug Fix + Edge Cases + Features** — Phases 1-12 (shipped 2026-03-05)
- ✅ **v2.0 Admin Tools + Live Activity** — Phases 13-16 (shipped 2026-03-12)
- 🚧 **v3.0 Schedule Grid + Landing Website** — Phases 17-18 (in progress)

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

### 🚧 v3.0 Schedule Grid + Landing Website (In Progress)

**Milestone Goal:** Redesign schedule management UI to week-view grid layout, and create a marketing landing website for ABSENKOK.

- [x] **Phase 17: Schedule Grid UI Redesign** — Refactor jadwal mingguan ke format grid proper dengan pinned headers, tap-to-assign, bulk assign, dan auto-generate (completed 2026-03-12)
- [x] **Phase 18: ABSENKOK Landing Website** — Website marketing statis dengan Astro 5 + Tailwind v4, deploy ke Vercel (completed 2026-03-12)

## Phase Details

### Phase 17: Schedule Grid UI Redesign
**Goal**: Admin mengelola jadwal karyawan dalam grid mingguan yang proper — karyawan di baris, hari di kolom, tap cell untuk assign shift
**Depends on**: Phase 16 (v2.0 complete)
**Requirements**: GRID-01, GRID-02, GRID-03, GRID-04, GRID-05, GRID-06, GRID-07, GRID-08, GRID-09, GRID-10
**Success Criteria** (what must be TRUE):
  1. Admin melihat jadwal mingguan dalam format grid (karyawan di baris, Senin-Minggu di kolom); kolom nama karyawan tetap pinned saat scroll horizontal dan header hari tetap pinned saat scroll vertikal
  2. Admin tap cell untuk assign shift type (Pagi/Siang/Sore/Libur), setiap shift ditampilkan sebagai chip berwarna berbeda; status Sakit/Izin tampil sebagai overlay pada cell
  3. Admin navigasi antar minggu (← →), menggunakan bulk assign untuk set shift yang sama ke beberapa karyawan sekaligus, dan auto-generate jadwal dari template shift
  4. Semua perubahan jadwal tersimpan ke Supabase + SQLite cache — data layer tetap utuh, zero regression dari fungsionalitas yang sudah ada
**Plans:** 2/2 plans complete

Plans:
- [ ] 17-01-PLAN.md — Widget architecture: add `two_dimensional_scrollables`, create cell builders, TableView wrapper, legend widget
- [ ] 17-02-PLAN.md — Screen refactor: wire new widgets into shift_scheduler_screen.dart, remove old scroll sync, visual verification

### Phase 18: ABSENKOK Landing Website
**Goal**: Pengunjung membuka website marketing ABSENKOK yang cepat, informatif, dan bisa langsung download APK
**Depends on**: Nothing (independent dari Phase 17 — repo terpisah, zero code coupling)
**Requirements**: WEB-01, WEB-02, WEB-03, WEB-04, WEB-05, WEB-06, WEB-07, WEB-08, WEB-09, WEB-10
**Success Criteria** (what must be TRUE):
  1. Pengunjung melihat hero section dengan tablet mockup + tagline ABSENKOK, feature showcase 4-6 fitur utama dengan ikon, dan "How It Works" section 3 langkah penggunaan
  2. Pengunjung tap tombol download APK yang mengarah ke GitHub Releases
  3. Website responsive di mobile/tablet/desktop, semua copy dalam Bahasa Indonesia, page load < 2 detik dengan zero JavaScript shipped ke browser
  4. Website memiliki SEO meta tags + sitemap.xml, credit developer "Akmal" di footer, dan deployed live di Vercel
**Plans**: 2 plans

Plans:
- [ ] 18-01-PLAN.md — Project scaffolding + configuration (Astro 5, Tailwind v4, Vercel, sitemap, BaseLayout)
- [ ] 18-02-PLAN.md — Content sections + page assembly + visual verification (Hero, Features, HowItWorks, Download, Footer)

## Progress

**Execution Order:** Phase 17 → Phase 18 (or parallel — zero coupling)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 17. Schedule Grid UI Redesign | 2/2 | Complete    | 2026-03-12 | - |
| 18. ABSENKOK Landing Website | 2/2 | Complete    | 2026-03-12 | - |

## Future Backlog (Not Scheduled)
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
- Live Activity pill device debugging (code delivered, needs on-device verification)
