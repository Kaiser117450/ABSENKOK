# Requirements: Absensi Enakko v3.0

**Defined:** 2026-03-12
**Core Value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.

## v3.0 Requirements

Requirements for v3.0 release. Each maps to roadmap phases.

### Schedule Grid (GRID)

- [ ] **GRID-01**: Admin melihat jadwal mingguan dalam format grid (karyawan di baris, Senin-Minggu di kolom)
- [ ] **GRID-02**: Admin tap cell untuk assign shift type (Pagi/Siang/Sore/Libur) ke karyawan pada hari tertentu
- [ ] **GRID-03**: Kolom nama karyawan tetap terlihat (pinned) saat scroll horizontal
- [ ] **GRID-04**: Header hari (Senin-Minggu) tetap terlihat (pinned) saat scroll vertikal
- [ ] **GRID-05**: Setiap shift type ditampilkan dengan warna berbeda (chip berwarna di cell)
- [ ] **GRID-06**: Status Sakit/Izin ditampilkan sebagai overlay pada cell grid
- [ ] **GRID-07**: Admin dapat navigasi antar minggu (← minggu sebelumnya / minggu berikutnya →)
- [ ] **GRID-08**: Jadwal tersimpan ke Supabase + SQLite cache seperti sebelumnya
- [ ] **GRID-09**: Bulk assign mode — pilih beberapa karyawan, assign shift yang sama sekaligus
- [ ] **GRID-10**: Auto-generate jadwal dari template shift (2-shift/3-shift)

### Landing Website (WEB)

- [ ] **WEB-01**: Hero section dengan app mockup dalam frame tablet dan tagline ABSENKOK
- [ ] **WEB-02**: Feature showcase section menampilkan 4-6 fitur utama dengan ikon/screenshot
- [ ] **WEB-03**: "How It Works" section menjelaskan 3 langkah penggunaan app
- [ ] **WEB-04**: Tombol download APK mengarah ke GitHub Releases
- [ ] **WEB-05**: Watermark/credit developer "Akmal" di footer
- [ ] **WEB-06**: Responsive design (mobile + tablet + desktop)
- [ ] **WEB-07**: Semua copy dalam Bahasa Indonesia
- [ ] **WEB-08**: Page load < 2 detik, zero JavaScript shipped
- [ ] **WEB-09**: SEO meta tags + sitemap.xml
- [ ] **WEB-10**: Deploy ke Vercel

## Future Requirements

### Schedule Differentiators (Deferred to v3.1+)

- **GRID-D1**: Tap-to-cycle shift tanpa dialog (satu tap ganti shift berikutnya)
- **GRID-D2**: Copy jadwal minggu sebelumnya sebagai template
- **GRID-D3**: Highlight kolom "hari ini" dengan warna berbeda

### Backlog (Deferred)

- **BACK-01**: Schedule UI grid redesign (delivered in v3.0)
- **BACK-02**: Late arrival automatic flagging vs shift start time
- **BACK-03**: Overtime tracking (> 8h kerja → overtime flag)
- **BACK-04**: Push notification for missing clock-out
- **BACK-05**: Attendance rate card on admin dashboard
- **BACK-06**: Employee attendance streak tracking (gamification)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Drag-and-drop shift assignment | Wrong for tablet touch — finger occlusion, gesture conflicts with scroll |
| Monthly view (30-day grid) | 420 cells unreadable on tablet, cognitive overload |
| Employee self-service portal | Kiosk-only product, employees don't interact with admin |
| Blog/pricing on website | Internal tool, not a SaaS product |
| CMS integration for website | Overkill for single static page with fixed content |
| Complex JS animations on website | Defeats Astro's zero-JS advantage |
| iOS app | Android-only kiosk, no iOS target |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| GRID-01 | — | Pending |
| GRID-02 | — | Pending |
| GRID-03 | — | Pending |
| GRID-04 | — | Pending |
| GRID-05 | — | Pending |
| GRID-06 | — | Pending |
| GRID-07 | — | Pending |
| GRID-08 | — | Pending |
| GRID-09 | — | Pending |
| GRID-10 | — | Pending |
| WEB-01 | — | Pending |
| WEB-02 | — | Pending |
| WEB-03 | — | Pending |
| WEB-04 | — | Pending |
| WEB-05 | — | Pending |
| WEB-06 | — | Pending |
| WEB-07 | — | Pending |
| WEB-08 | — | Pending |
| WEB-09 | — | Pending |
| WEB-10 | — | Pending |

**Coverage:**
- v3.0 requirements: 20 total
- Mapped to phases: 0
- Unmapped: 20 ⚠️ (awaiting roadmap creation)

---
*Requirements defined: 2026-03-12*
*Last updated: 2026-03-12 after initial definition*
