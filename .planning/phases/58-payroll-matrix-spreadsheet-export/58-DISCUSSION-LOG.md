# Phase 58: Payroll Matrix & Spreadsheet Export - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `58-CONTEXT.md` - this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 58-payroll-matrix-spreadsheet-export
**Areas discussed:** Spreadsheet, Summary, Matrix UI

---

## Spreadsheet

### Export format

| Option | Description | Selected |
|--------|-------------|----------|
| XLSX tunggal | Workbook `.xlsx` utama untuk warna sel, freeze pane, dan payroll matrix. | ✓ |
| XLSX + audit | Workbook `.xlsx` utama plus sheet audit/detail tambahan. | |
| Lainnya | Format selain workbook Excel biasa. | |

**User's choice:** `XLSX tunggal`
**Notes:** Repo saat ini hanya punya CSV/PDF flow; Phase 58 mengunci workbook `.xlsx` sebagai output payroll utama.

### Workbook structure

| Option | Description | Selected |
|--------|-------------|----------|
| 1 sheet matrix | Satu sheet utama berisi matrix harian dan kolom summary. | ✓ |
| 2 sheet split | Sheet matrix dipisah dari sheet summary. | |
| Matrix + legend | Sheet matrix utama plus sheet kecil legenda warna/kode. | |

**User's choice:** `1 sheet matrix`
**Notes:** User tidak ingin memecah laporan payroll utama ke sheet terpisah.

### Cell payload

| Option | Description | Selected |
|--------|-------------|----------|
| Masuk/Pulang | Hanya jam masuk dan pulang yang compact. | |
| Masuk/Pulang+tag | Jam masuk/pulang plus tag singkat untuk signal tambahan. | ✓ |
| Kode ringkas | Kode/simbol sangat padat. | |

**User's choice:** `Masuk/Pulang+tag`
**Notes:** Workbook tetap salary-facing tetapi signal tambahan tidak hilang.

### Summary scope

| Option | Description | Selected |
|--------|-------------|----------|
| Payroll inti | Hitung `late`, `short work`, `excess break`, `overtime`, `absence` saja. | ✓ |
| Payroll + audit | Tambah `manager exempt`, `belum absen pulang`, `hadir tanpa jadwal`. | |
| Minimalis | Hanya total merah/kuning/tidak hadir. | |

**User's choice:** `Payroll inti`
**Notes:** Status audit tambahan tetap boleh muncul di sel/tag, tetapi tidak jadi kolom summary inti.

### Export scope

| Option | Description | Selected |
|--------|-------------|----------|
| Per outlet | Satu workbook untuk satu outlet. | ✓ |
| Gabung outlet | Satu workbook menggabungkan banyak outlet. | |
| Opsional dua mode | Mendukung keduanya. | |

**User's choice:** `Per outlet`
**Notes:** Selaras dengan recap policy saat ini yang memang satu outlet per range.

### Multi-signal rendering

| Option | Description | Selected |
|--------|-------------|----------|
| Primary + tags | Warna mengikuti primary status, signal lain ikut sebagai tag. | ✓ |
| Semua teks | Semua signal ditulis sebagai teks/kode. | |
| Primary only | Hanya primary status yang terlihat. | |

**User's choice:** `Primary + tags`
**Notes:** Phase 58 harus mempertahankan sinyal secondary tanpa mengorbankan warna strict utama.

---

## Summary

### Row population

| Option | Description | Selected |
|--------|-------------|----------|
| Ada aktivitas/rencana | Hanya karyawan dengan jadwal/log pada range terpilih. | |
| Seluruh roster aktif | Semua karyawan aktif outlet tampil meski range itu kosong. | ✓ |
| Termasuk histori arsip | Siapa pun yang punya histori pada range itu, termasuk yang sekarang arsip. | |

**User's choice:** `Seluruh roster aktif`
**Notes:** User ingin matrix default mengikuti roster aktif outlet, bukan hanya activity-driven rows.

### Row order

| Option | Description | Selected |
|--------|-------------|----------|
| Nama A-Z | Urut nama penuh. | |
| Kontrak lalu nama | Grup `FULLTIME` / `PARTTIME`, lalu nama. | ✓ |
| Pelanggaran terbanyak | Problem days tertinggi di atas. | |

**User's choice:** `Kontrak lalu nama`
**Notes:** Ringkasan payroll perlu tetap mudah dipindai per tipe kontrak.

### Summary column order

| Option | Description | Selected |
|--------|-------------|----------|
| Merah lalu kuning | `late`, `short work`, `excess break`, `absence`, lalu `overtime`. | ✓ |
| Absen dulu | `absence` lebih dulu, lalu lainnya. | |
| Total dulu | Total merah/kuning di depan, rincian setelahnya. | |

**User's choice:** `Merah lalu kuning`
**Notes:** User ingin urutan membaca summary dimulai dari problem/red counts, lalu pengecualian kuning.

### Archived historical rows

| Option | Description | Selected |
|--------|-------------|----------|
| Tetap tampil | Histori payroll arsip tetap ikut tampil. | |
| Jangan tampil | Matrix hanya mengikuti karyawan aktif saat ini. | ✓ |
| Section terpisah | Histori arsip dipisah bloknya. | |

**User's choice:** `Jangan tampil`
**Notes:** User sempat mengklarifikasi makna `arsip`; setelah dijelaskan bahwa arsip di repo ini adalah soft-archive, user tetap memilih agar karyawan arsip tidak tampil di matrix Phase 58.

---

## Matrix UI

### Grid style

| Option | Description | Selected |
|--------|-------------|----------|
| Pinned grid | Kolom identitas karyawan tetap, tanggal scroll ke kanan. | ✓ |
| Plain table | Tabel biasa tanpa pinned behavior yang kuat. | |
| Paged weeks | Dibagi per blok/rentang kecil. | |

**User's choice:** `Pinned grid`
**Notes:** User menjelaskan secara bebas bahwa bagian nama harus tetap, sedangkan tanggal memanjang ke kanan mengikuti rentang yang dipilih.

### Cell interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Buka detail hari | Tap membuka detail audit harian. | |
| Read only | Matrix hanya untuk baca. | ✓ |
| Quick tooltip | Tap/hover menampilkan info singkat. | |

**User's choice:** `Read only`
**Notes:** Phase 58 tidak perlu memperluas scope ke flow detail per sel.

### Summary position on screen

| Option | Description | Selected |
|--------|-------------|----------|
| Tetap di kanan | Ikuti workbook persis, summary hanya terlihat setelah scroll jauh. | |
| Sticky summary | Summary tetap mudah dibaca saat matrix melebar. | ✓ |
| Toggle mode | Matrix dan summary dipisah ke mode tampilan berbeda. | |

**User's choice:** `Sticky summary`
**Notes:** User membedakan kebutuhan layar admin dari workbook export; di UI, summary harus tetap cepat terbaca.

### Non-time cell states

| Option | Description | Selected |
|--------|-------------|----------|
| Label eksplisit | Status seperti `Libur`, `Izin`, `Sakit`, `Tidak Hadir` ditulis jelas. | ✓ |
| Kode singkat | Pakai singkatan sangat padat. | |
| Kosong saja | Andalkan warna/tooltip tanpa label. | |

**User's choice:** `Label eksplisit`
**Notes:** User tidak ingin blank cells menciptakan ambiguitas di laporan payroll.

---

## the agent's Discretion

- Exact `.xlsx` generation library and workbook styling implementation.
- Exact short-tag abbreviations used in matrix cells.
- Exact sticky-summary technique on the admin screen.
- Exact performance/virtualization strategy for wide date ranges.

## Deferred Ideas

- Separate audit/detail sheet in the workbook.
- Multi-outlet workbook export.
- Interactive per-cell drilldown.
- Archived historical rows in the main Phase 58 matrix.

