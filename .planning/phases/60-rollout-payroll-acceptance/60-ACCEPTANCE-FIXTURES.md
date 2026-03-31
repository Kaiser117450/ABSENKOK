# Phase 60 Acceptance Fixtures

Pack skenario wajib untuk rollout acceptance payroll. Setiap fixture di bawah mengunci apa yang harus direview operator di Admin, Spreadsheet, PDF, dan Portal sebelum `Tandai Siap Payroll` boleh dipakai.

## full-time

- outlet mode: `NORMAL`
- contract type: `FULLTIME`
- logical workday: `2026-03-24`
- expected primary outcome label: `07:00 / 17:00`
- expected short tags: `none`
- expected severity family: `neutral`
- Admin / Spreadsheet / PDF / Portal: pastikan empat artefak menampilkan hari kerja penuh tanpa mismatch label atau severity
- what blocks approval: salah satu artefak menunjukkan penalti, tag tambahan, atau logical day yang berbeda

## part-time

- outlet mode: `NORMAL`
- contract type: `PARTTIME`
- logical workday: `2026-03-24`
- expected primary outcome label: `08:00 / 17:00`
- expected short tags: `none`
- expected severity family: `neutral`
- Admin / Spreadsheet / PDF / Portal: pastikan kontrak part-time tetap menghasilkan hari kerja normal tanpa label penalti palsu
- what blocks approval: salah satu artefak mengubah jam kerja part-time menjadi absence, short-work, atau label yang tidak konsisten

## overtime

- outlet mode: `NORMAL`
- contract type: `FULLTIME`
- logical workday: `2026-03-25`
- expected primary outcome label: `07:00 / 19:15`
- expected short tags: `OT`
- expected severity family: `yellow`
- Admin / Spreadsheet / PDF / Portal: pastikan tag lembur dan severity kuning muncul konsisten di semua artefak
- what blocks approval: tag `OT` hilang, severity berubah, atau salah satu artefak masih menampilkan hasil normal

## outlet 24 jam

- outlet mode: `TWENTY_FOUR_HOUR`
- contract type: `FULLTIME`
- logical workday: `2026-03-18`
- expected primary outcome label: `Terlambat`
- expected short tags: `TLT`
- expected severity family: `yellow`
- Admin / Spreadsheet / PDF / Portal: pastikan overnight logical day tetap dirangkum sebagai satu hari kerja yang sama di semua artefak
- what blocks approval: clock-out pindah ke hari berikutnya secara tidak konsisten, tag hilang, atau severity family tidak selaras

## outlet normal

- outlet mode: `NORMAL`
- contract type: `FULLTIME`
- logical workday: `2026-03-26`
- expected primary outcome label: `07:05 / 17:03`
- expected short tags: `none`
- expected severity family: `neutral`
- Admin / Spreadsheet / PDF / Portal: pastikan outlet reguler tetap memakai logical workday yang sama tanpa mode 24 jam
- what blocks approval: salah satu artefak memakai boundary overnight, label penalti palsu, atau data outlet berbeda

## break-first

- outlet mode: `NORMAL`
- contract type: `PARTTIME`
- logical workday: `2026-03-27`
- expected primary outcome label: `Terlambat`
- expected short tags: `TLT`
- expected severity family: `yellow`
- Admin / Spreadsheet / PDF / Portal: pastikan jalur break-first tetap terbaca sama pada empat artefak dan tidak menurunkan bukti parity
- what blocks approval: break-first hilang di salah satu artefak, severity bergeser, atau logical workday tidak sama

## no-show

- outlet mode: `NORMAL`
- contract type: `FULLTIME`
- logical workday: `2026-03-28`
- expected primary outcome label: `Tidak Hadir`
- expected short tags: `ABS`
- expected severity family: `red`
- Admin / Spreadsheet / PDF / Portal: pastikan status tidak hadir tetap merah dan memblokir approval di semua artefak
- what blocks approval: salah satu artefak tidak merah, menampilkan hadir, atau tidak membawa tag `ABS`

---

Catatan: legacy no-schedule compatibility tetap evidence-worthy untuk rollout review, tetapi tidak menjadi required eighth scenario di Phase 60.
