---
status: verified
score: 100
human_verification: required-for-overnight-live-data
---

# Phase 42 Verification Report: Attendance Recap Read Model

## Goal Achievement

Phase 42 delivered the trusted recap read model required by v6.3.

| Requirement | Delivered | Evidence |
|---|---|---|
| ATTN-02 — Attendance recap RPC scoped by authenticated session | Yes | `get_portal_attendance_recap` SECURITY DEFINER RPC; employee identity resolved via `resolve_portal_employee()` — no caller-supplied ID |
| ATTN-03 — Overnight pulang repair attached to logical workday | Yes | SQL overnight-repair block; TypeScript helper `lastPulangAt` on the normalized `PortalRecapDay` row |

---

## Observable Truths

### Truth 1 — Employee identity resolved server-side

The `get_portal_attendance_recap` RPC calls `resolve_portal_employee()` internally. The function accepts no `employee_id` parameter from the caller. The TypeScript loader (`attendance-recap.ts`) also resolves identity via `resolvePortalEmployee(Astro)` before calling the RPC — the page never supplies an employee identifier.

**Grounded in:** `sql/phase_42_portal_attendance_recap_20260323.sql` (RPC signature); `src/lib/portal/attendance-recap.ts` (lines 259–266 — `resolvePortalEmployee` returns early on failure before the RPC call is made).

### Truth 2 — The recap contract exposes named timestamps and summary derivation inputs

The 20-column RPC row contract includes four named attendance timestamps:

- `first_masuk_at` (clock-in)
- `first_break_at` (break start)
- `last_kembali_at` (return from break)
- `last_pulang_at` (clock-out, overnight-repaired)

The TypeScript normalizer maps these to camelCase `PortalRecapDay` fields (`firstMasukAt`, `firstBreakAt`, `lastKembaliAt`, `lastPulangAt`). The `deriveSummaryCounts` function in `attendance-recap.ts` derives six summary counts (hadir, sakit, izin, tidakHadir, belumPulang, libur) purely from the normalized day array with no second RPC call.

**Grounded in:** `src/lib/portal/attendance-recap.ts` — `PortalAttendanceRecapRow` interface (lines 15–36), `PortalRecapDay` interface (lines 70–102), `deriveSummaryCounts` function (lines 191–235).

### Truth 3 — Overnight handling stays attached to the intended logical workday

The SQL overnight-repair logic reassigns a `pulang` scan logged before noon on the next calendar day to the prior logical day, but only when that prior day has a `masuk` scan. This mirrors the admin Rekap Harian Dart logic already in production. The repair is applied at the SQL layer; the `last_pulang_at` column in every exported row already reflects the repaired assignment. The TypeScript normalizer preserves `lastPulangAt` without re-derivation.

The `sedang_bekerja` status is applied to the current effective date when `masuk` exists but `pulang` has not yet been recorded — preventing a false `belum_pulang` alarm while the employee is still on shift. This is a named, distinct status in the `AttendanceStatus` discriminated union.

**Grounded in:** `sql/phase_42_portal_attendance_recap_20260323.sql` (overnight-repair CTE, `sedang_bekerja` CASE branch); `src/lib/portal/attendance-recap.ts` `AttendanceStatus` union type (lines 54–63).

---

## Required Artifacts

| Artifact | Path | Status |
|---|---|---|
| SQL migration — recap RPC + index | `sql/phase_42_portal_attendance_recap_20260323.sql` | Shipped (commit b1e6279) |
| TypeScript helper — loader, types, normalizer | `src/lib/portal/attendance-recap.ts` (absenkok-website) | Shipped (commit fff126e) |

---

## Key Link Verification

| From | To | Via | Pattern present |
|---|---|---|---|
| `42-VERIFICATION.md` | `src/lib/portal/attendance-recap.ts` | Documents the same recap contract and logical-day proof already shipped by Phase 42 | `summaryCounts` present (line 133, 301) |
| `attendance-recap.ts` loader | `get_portal_attendance_recap` RPC | `supabase.rpc('get_portal_attendance_recap', { reference_date: referenceDate })` | `get_portal_attendance_recap` present (line 281) |

---

## Requirements Coverage

| Requirement ID | Description | Evidence |
|---|---|---|
| ATTN-02 | Employee attendance recap RPC, authenticated, employee-scoped | `get_portal_attendance_recap` SECURITY DEFINER; ACL: REVOKE from PUBLIC/anon, GRANT to authenticated; `resolve_portal_employee()` called internally |
| ATTN-03 | Overnight pulang repair preserves logical workday boundary | Overnight-repair CTE in SQL migration; `last_pulang_at` on every RPC row; `lastPulangAt` in `PortalRecapDay`; `sedang_bekerja` status prevents false alarm on active shift |

---

## Human Verification Required

The following checks require a live Supabase session and cannot be automated from planning files:

1. **Overnight data scenario (real shift):** Verify that a `pulang` scan logged before noon the next calendar day appears on the prior day's row in the portal recap, not the next calendar day's row. Trigger: any employee who clocked out overnight past midnight.

2. **`sedang_bekerja` active shift:** Verify that a currently-on-shift employee sees `sedang_bekerja` (not `belum_pulang`) for today's row while they are mid-shift.

3. **SQL migration applied:** Completed during v6.3 milestone closeout on 2026-03-23. `get_portal_attendance_recap` and `idx_attendance_logs_employee_recap` were confirmed present in the production Supabase project (`tmapxdftdhxovthgbhww`) after applying migration `phase_42_portal_attendance_recap_20260323`.

---

*Phase: 42-attendance-recap-read-model*
*Verified: 2026-03-23*
