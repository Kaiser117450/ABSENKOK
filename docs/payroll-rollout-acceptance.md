# Rollout Payroll

Checklist ini khusus untuk Phase 60 rollout dan acceptance. Phase ini tidak menulis ulang aturan payroll ketat dari Phase 54-59; checklist ini hanya memastikan operator punya jalur review yang aman sebelum payroll baru dipakai.

Lihat juga:
- `docs/android-release-runbook.md` untuk pola runbook operator yang sudah dipakai di repo ini
- `.planning/phases/60-rollout-payroll-acceptance/60-ACCEPTANCE-FIXTURES.md` untuk pack skenario wajib yang harus direview

---

## 1. Scope dan Boundary

Phase 60 adalah rollout-and-acceptance only.

- Tidak ada aturan payroll baru di dokumen ini.
- Tidak ada SQL baru, perubahan portal baru, atau tooling release baru di dokumen ini.
- Checklist ini hanya merekam bahwa langkah manual direview dan dikonfirmasi.
- Checklist ini tidak meng-approve atau mengeksekusi SQL secara otomatis.

**Yang tetap menjadi sumber bukti resmi:**

| Sumber | Peran |
|--------|-------|
| Admin | Permukaan review utama di recap shell |
| Spreadsheet | Artefak salary-facing untuk review operasional |
| PDF | Artefak ringkas yang dibagikan ke reviewer |
| Portal | Permukaan pembanding read-only untuk parity |

---

## 2. Guardrail Produksi

Sebelum memulai review rollout:

- [ ] Database production yang dipakai adalah database live.
- [ ] Mode rollout additive dikonfirmasi untuk seluruh langkah production.
- [ ] Operator memahami bahwa setiap langkah yang memengaruhi database wajib mendapat konfirmasi eksplisit sebelum dijalankan.
- [ ] Parity wajib direview di empat kolom bukti: **Admin**, **Spreadsheet**, **PDF**, dan **Portal**.
- [ ] Checklist ini dipakai untuk pencatatan acceptance, bukan untuk approval otomatis.

**Aturan tetap:**

1. Gunakan data dan artefak yang sudah dihasilkan oleh stack recap Phase 54-59.
2. Jangan tandai payroll siap bila ada satu saja skenario wajib yang belum direview.
3. Jangan jalankan langkah database dari checklist ini tanpa approval operator yang jelas.

---

## 3. Skenario Wajib

Semua skenario di bawah harus direview dengan logical workday yang sama di empat permukaan bukti.

| Skenario | Fokus review | Status awal |
|----------|--------------|-------------|
| Full-time | Kontrak penuh, output payroll normal | Belum direview |
| Part-time | Kontrak paruh waktu, jam kerja kontrak | Belum direview |
| Lembur | Tag lembur dan severity kuning tetap konsisten | Belum direview |
| Outlet 24 jam | Overnight logical day tetap utuh | Belum direview |
| Outlet normal | Flow outlet reguler tanpa mode 24 jam | Belum direview |
| Break-first | Jalur break-first tidak merusak parity | Belum direview |
| No-show | Tidak Hadir dan blok approval tetap jelas | Belum direview |

Jangan menambah skenario kedelapan ke checklist wajib ini.

---

## 4. Tabel Bukti Parity

Gunakan tabel ini untuk setiap skenario. Nama kolom harus dipakai persis seperti di bawah agar vocabulary operator dan UI tetap sama.

| Skenario | Admin | Spreadsheet | PDF | Portal | Status |
|----------|-------|-------------|-----|--------|--------|
| Full-time | | | | | Pending |
| Part-time | | | | | Pending |
| Lembur | | | | | Pending |
| Outlet 24 jam | | | | | Pending |
| Outlet normal | | | | | Pending |
| Break-first | | | | | Pending |
| No-show | | | | | Pending |

Checklist parity per baris:

- Pastikan label utama sama di Admin, Spreadsheet, PDF, dan Portal.
- Pastikan short tags yang muncul tetap sama di semua artefak.
- Pastikan severity family tidak bergeser antar artefak.
- Jika ada satu mismatch saja, status skenario tetap blocked sampai bukti diperbaiki atau dijelaskan.

---

## 5. Action Bar dan Copy Terkunci

Copy berikut harus dipertahankan apa adanya di rollout surface dan dokumen acceptance:

| Elemen | Copy |
|--------|------|
| Judul layar | Rollout Payroll |
| CTA utama | Tandai Siap Payroll |
| CTA sekunder | Unduh Bukti Validasi |
| Banner rollout | Mode rollout additive |
| Headline sukses | Payroll siap dipakai |
| Headline gagal | Payroll belum aman dipakai |

Gunakan wording ini hanya setelah operator selesai mereview bukti.

---

## 6. Urutan Review Operator

### Langkah 1. Siapkan fixture

- Buka `.planning/phases/60-rollout-payroll-acceptance/60-ACCEPTANCE-FIXTURES.md`
- Pilih logical workday yang sesuai untuk tiap skenario wajib
- Pastikan outlet mode dan contract type sesuai fixture

### Langkah 2. Kumpulkan bukti parity

- Catat hasil Admin untuk skenario yang sedang direview
- Unduh Spreadsheet dari flow recap yang sudah ada
- Unduh PDF dari flow recap yang sudah ada
- Buka Portal sebagai permukaan pembanding read-only

### Langkah 3. Isi tabel bukti

- Isi kolom **Admin**, **Spreadsheet**, **PDF**, dan **Portal**
- Tandai `Status` sebagai `Passed`, `Pending`, atau `Blocked`
- Catat mismatch sebelum lanjut ke skenario berikutnya

### Langkah 4. Review gate manual

- `Tandai Siap Payroll` hanya boleh dipakai setelah semua skenario wajib lulus
- `Unduh Bukti Validasi` dipakai untuk mengemas hasil review, bukan untuk mengeksekusi perubahan produksi
- Untuk langkah apa pun yang memengaruhi database, operator harus memberi konfirmasi manual terpisah

---

## 7. Catatan Approval Manual

Checklist ini tidak pernah:

- mengeksekusi SQL secara otomatis
- menyetujui perubahan database tanpa manusia
- menandai rollout selesai hanya karena file dokumen ini ada

Checklist ini hanya menyimpan review bahwa langkah manual sudah diperiksa dan dikonfirmasi. Bila ada langkah yang memengaruhi database, status aman baru boleh diberikan setelah operator meninjau langkah tersebut secara manual dan menyetujui bahwa perubahan tetap additive-only.
