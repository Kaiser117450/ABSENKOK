# Worksheet Review Rollout Payroll

Worksheet ini dipakai saat operator menjalankan review manual Phase 60. Jangan ubah checklist canonical di `docs/payroll-rollout-acceptance.md`; gunakan file ini untuk mencatat bukti yang ditemukan di lapangan.

Sumber fixture resmi:

- `.planning/phases/60-rollout-payroll-acceptance/60-ACCEPTANCE-FIXTURES.md`

Vocabulary kolom wajib:

- `Admin`
- `Spreadsheet`
- `PDF`
- `Portal`
- `Status`

Nilai `Status` yang diizinkan:

- `Passed`
- `Pending`
- `Blocked`

---

## 1. Informasi Review

| Field | Isi |
|-------|-----|
| Tanggal review | |
| Reviewer | |
| Outlet / ruang lingkup | |
| Logical workday range | |
| Bundle bukti validasi | |
| Catatan umum | |

## 2. Guardrail Sebelum Review

- [ ] Database yang direview adalah database production yang benar.
- [ ] Semua langkah yang mungkin memengaruhi database tetap additive-only.
- [ ] Tidak ada approval database yang dianggap otomatis dari worksheet ini.
- [ ] Evidence akan dibandingkan di empat permukaan: `Admin`, `Spreadsheet`, `PDF`, `Portal`.
- [ ] Semua tujuh skenario wajib akan direview sebelum `Tandai Siap Payroll`.

## 3. Ringkasan Hasil Cepat

| Skenario | Expected label | Expected tags | Expected severity | Status | Follow-up |
|----------|----------------|---------------|-------------------|--------|-----------|
| Full-time | `07:00 / 17:00` | `none` | `neutral` | Pending | |
| Part-time | `08:00 / 17:00` | `none` | `neutral` | Pending | |
| Lembur | `07:00 / 19:15` | `OT` | `yellow` | Pending | |
| Outlet 24 jam | `Terlambat` | `TLT` | `yellow` | Pending | |
| Outlet normal | `07:05 / 17:03` | `none` | `neutral` | Pending | |
| Break-first | `Terlambat` | `TLT` | `yellow` | Pending | |
| No-show | `Tidak Hadir` | `ABS` | `red` | Pending | |

## 4. Evidence Per Skenario

### Full-time

| Field | Value |
|-------|-------|
| Expected label | `07:00 / 17:00` |
| Expected tags | `none` |
| Expected severity | `neutral` |
| Logical workday | `2026-03-24` |
| Outlet mode | `NORMAL` |
| Contract type | `FULLTIME` |

| Admin | Spreadsheet | PDF | Portal | Status |
|-------|-------------|-----|--------|--------|
| | | | | Pending |

Mismatch / note:

Approval blocker:

### Part-time

| Field | Value |
|-------|-------|
| Expected label | `08:00 / 17:00` |
| Expected tags | `none` |
| Expected severity | `neutral` |
| Logical workday | `2026-03-24` |
| Outlet mode | `NORMAL` |
| Contract type | `PARTTIME` |

| Admin | Spreadsheet | PDF | Portal | Status |
|-------|-------------|-----|--------|--------|
| | | | | Pending |

Mismatch / note:

Approval blocker:

### Lembur

| Field | Value |
|-------|-------|
| Expected label | `07:00 / 19:15` |
| Expected tags | `OT` |
| Expected severity | `yellow` |
| Logical workday | `2026-03-25` |
| Outlet mode | `NORMAL` |
| Contract type | `FULLTIME` |

| Admin | Spreadsheet | PDF | Portal | Status |
|-------|-------------|-----|--------|--------|
| | | | | Pending |

Mismatch / note:

Approval blocker:

### Outlet 24 jam

| Field | Value |
|-------|-------|
| Expected label | `Terlambat` |
| Expected tags | `TLT` |
| Expected severity | `yellow` |
| Logical workday | `2026-03-18` |
| Outlet mode | `TWENTY_FOUR_HOUR` |
| Contract type | `FULLTIME` |

| Admin | Spreadsheet | PDF | Portal | Status |
|-------|-------------|-----|--------|--------|
| | | | | Pending |

Mismatch / note:

Approval blocker:

### Outlet normal

| Field | Value |
|-------|-------|
| Expected label | `07:05 / 17:03` |
| Expected tags | `none` |
| Expected severity | `neutral` |
| Logical workday | `2026-03-26` |
| Outlet mode | `NORMAL` |
| Contract type | `FULLTIME` |

| Admin | Spreadsheet | PDF | Portal | Status |
|-------|-------------|-----|--------|--------|
| | | | | Pending |

Mismatch / note:

Approval blocker:

### Break-first

| Field | Value |
|-------|-------|
| Expected label | `Terlambat` |
| Expected tags | `TLT` |
| Expected severity | `yellow` |
| Logical workday | `2026-03-27` |
| Outlet mode | `NORMAL` |
| Contract type | `PARTTIME` |

| Admin | Spreadsheet | PDF | Portal | Status |
|-------|-------------|-----|--------|--------|
| | | | | Pending |

Mismatch / note:

Approval blocker:

### No-show

| Field | Value |
|-------|-------|
| Expected label | `Tidak Hadir` |
| Expected tags | `ABS` |
| Expected severity | `red` |
| Logical workday | `2026-03-28` |
| Outlet mode | `NORMAL` |
| Contract type | `FULLTIME` |

| Admin | Spreadsheet | PDF | Portal | Status |
|-------|-------------|-----|--------|--------|
| | | | | Pending |

Mismatch / note:

Approval blocker:

## 5. Final Decision

- [ ] Semua tujuh skenario berstatus `Passed`
- [ ] Tidak ada mismatch label utama
- [ ] Tidak ada mismatch short tags
- [ ] Tidak ada mismatch severity family
- [ ] Langkah database yang relevan sudah direview manual dan tetap additive-only

Final decision:

- `Payroll siap dipakai`
- `Payroll belum aman dipakai`

Reviewer sign-off:

Closeout date:
