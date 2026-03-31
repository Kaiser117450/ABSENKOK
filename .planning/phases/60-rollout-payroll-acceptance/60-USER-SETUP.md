# Phase 60: User Setup Required

**Generated:** 2026-03-31
**Phase:** 60-rollout-payroll-acceptance
**Status:** Incomplete

Phase 60 hanya menutup rollout dan acceptance untuk payroll recap yang sudah dikirim pada Phase 54-59. Live Supabase project tetap additive-only dan setiap langkah yang bisa memengaruhi database wajib melewati approval operator secara manual.

Checklist operator utama ada di `docs/payroll-rollout-acceptance.md`. Gunakan file ini sebagai handoff phase-local untuk memastikan bukti parity terkumpul sebelum payroll baru dipakai.
Worksheet pengisian bukti ada di `docs/payroll-rollout-review-worksheet.md`.

---

## Production Guardrails

- **Project ID:** `tmapxdftdhxovthgbhww`
- **Region:** ap-south-1 (Mumbai)
- **Status:** ACTIVE_HEALTHY — sistem absensi live untuk 4 outlet

Aturan Phase 60:

- Jangan jalankan perubahan database tanpa konfirmasi operator.
- Semua perubahan produksi harus additive-only.
- Bukti parity harus dikumpulkan dari Admin, Spreadsheet, PDF, dan Portal.
- `Tandai Siap Payroll` tidak boleh dianggap lolos hanya karena dokumen ini lengkap.

---

## Next Manual Steps

1. Buka `docs/payroll-rollout-acceptance.md` dan review seluruh guardrail rollout.
2. Buka `.planning/phases/60-rollout-payroll-acceptance/60-ACCEPTANCE-FIXTURES.md` untuk memilih tujuh skenario wajib.
3. Buka `docs/payroll-rollout-review-worksheet.md` untuk mencatat bukti per skenario tanpa mengubah checklist canonical.
4. Untuk setiap skenario:
   - ambil bukti dari Admin
   - ambil bukti dari Spreadsheet
   - ambil bukti dari PDF
   - buka Portal sebagai pembanding read-only
5. Isi tabel parity dengan vocabulary tetap: `Admin`, `Spreadsheet`, `PDF`, `Portal`, `Status`.
6. Catat baris yang masih blocked atau pending sebelum mencoba menandai payroll siap.
7. Jika ada langkah yang memengaruhi database, berhenti dan minta approval operator manual sebelum lanjut.

---

## Acceptance Evidence Expectations

- Setiap skenario wajib punya satu logical workday yang jelas.
- Label utama, short tags, dan severity family harus sama di semua artefak.
- Bukti yang masih berbeda antar artefak harus dibawa ke follow-up, bukan diabaikan.
- `Unduh Bukti Validasi` dipakai setelah hasil review terkumpul, bukan sebagai pengganti review manual.

---

## Manual Closeout Reminder

Setelah semua bukti lengkap:

- ubah `Status: Incomplete` menjadi `Status: Complete`
- tambahkan tanggal closeout di bawah status
- simpan referensi ke checklist canonical di `docs/payroll-rollout-acceptance.md`

Sampai langkah manual itu selesai, Phase 60 belum boleh dianggap siap dipakai.
