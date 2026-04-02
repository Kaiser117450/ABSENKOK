import type { AstroGlobal } from 'astro';
import { createSupabaseServerClient } from '../supabase/server';
import { resolvePortalEmployee } from './employee';
import type { PortalEmployee } from './employee';
import { getPortalReferenceDate } from './schedule';

// ---------------------------------------------------------------------------
// Types — raw RPC row contract (mirrors sql/phase_42_portal_attendance_recap)
// ---------------------------------------------------------------------------

/**
 * One raw row as returned by the `get_portal_attendance_recap` RPC.
 * Column names and types mirror the SQL contract exactly.
 */
interface PortalAttendanceRecapRow {
  logical_date: string;         // ISO date: "YYYY-MM-DD"
  has_schedule: boolean | null;
  is_day_off: boolean | null;
  outlet_id: string | null;
  outlet_name: string | null;
  shift_name: string | null;
  start_hour: number | null;
  start_minute: number | null;
  end_hour: number | null;
  end_minute: number | null;
  ends_next_day: boolean | null;
  attendance_status: string | null;
  first_masuk_at: string | null; // ISO timestamptz string
  first_break_at: string | null;
  last_kembali_at: string | null;
  last_pulang_at: string | null;
  total_break_minutes: number | null;
  work_minutes: number | null;
  scan_count: number | null;
  notes: string | null;
}

// ---------------------------------------------------------------------------
// Types — normalized portal model
// ---------------------------------------------------------------------------

/**
 * Typed attendance status values returned by the RPC day-status derivation.
 *
 * - `hadir`        — present: masuk and pulang recorded
 * - `sakit`        — sick-leave scan logged
 * - `izin`         — permitted-absence scan logged
 * - `belum_pulang` — has masuk but no pulang yet (prior days only)
 * - `sedang_bekerja` — currently working (active current day: masuk but no pulang)
 * - `tidak_hadir`  — scheduled workday with no attendance (prior days)
 * - `belum_masuk`  — scheduled workday, current day, no attendance yet
 * - `libur`        — scheduled day off
 */
export type AttendanceStatus =
  | 'hadir'
  | 'sakit'
  | 'izin'
  | 'belum_pulang'
  | 'sedang_bekerja'
  | 'tidak_hadir'
  | 'belum_masuk'
  | 'libur'
  | null;

/**
 * One normalized logical workday row for the portal attendance recap.
 * Preserves all named attendance timestamps and schedule context so that
 * Phase 43 UI components never need to re-query or re-derive these fields.
 */
export interface PortalRecapDay {
  /** ISO calendar date for this logical workday: "YYYY-MM-DD". */
  logicalDate: string;
  hasSchedule: boolean;
  isDayOff: boolean;
  outletId: string | null;
  outletName: string | null;
  shiftName: string | null;
  startHour: number;
  startMinute: number;
  endHour: number;
  endMinute: number;
  /** True when the shift ends past midnight on the next calendar day. */
  endsNextDay: boolean;
  /** Day-level attendance outcome — null only for unscheduled days without any scan. */
  attendanceStatus: AttendanceStatus;
  /** Timestamp of the first masuk (clock-in) scan for this logical day. */
  firstMasukAt: string | null;
  /** Timestamp of the first break scan. */
  firstBreakAt: string | null;
  /** Timestamp of the last kembali (return-from-break) scan. */
  lastKembaliAt: string | null;
  /** Timestamp of the last pulang (clock-out) scan. Overnight pulang scans before noon are repaired to this day. */
  lastPulangAt: string | null;
  /** Outer-envelope break duration in minutes (first_break → last_kembali). */
  totalBreakMinutes: number;
  /** Net work time in minutes (masuk → pulang minus breaks). Null when pulang not yet recorded. */
  workMinutes: number | null;
  /** Total attendance scan events counted against this logical day. */
  scanCount: number;
  /** Combined schedule and attendance notes, if any. */
  notes: string | null;
}

/**
 * Month-to-date summary counts derived from the same normalized day set.
 * Counts include all days within the current calendar month up to referenceDate.
 */
export interface AttendanceSummaryCounts {
  /** Number of days with `hadir` status within the current month window. */
  hadir: number;
  /** Number of days with `sakit` status within the current month window. */
  sakit: number;
  /** Number of days with `izin` status within the current month window. */
  izin: number;
  /** Number of scheduled workdays (not day-off) with no attendance in prior days this month. */
  tidakHadir: number;
  /** Number of days with `belum_pulang` status within the current month window. */
  belumPulang: number;
  /** Number of scheduled day-off days within the current month window. */
  libur: number;
}

/**
 * The fully-typed portal attendance recap model returned to pages and Phase 43 components.
 */
export interface PortalAttendanceRecapModel {
  employee: PortalEmployee;
  /** Business-local reference date used to anchor this recap. ISO date string "YYYY-MM-DD". */
  referenceDate: string;
  /** First day of the current calendar month. ISO date string "YYYY-MM-DD". */
  monthStart: string;
  /** Month-to-date summary counts, derived from `days` filtered to the current month. */
  summaryCounts: AttendanceSummaryCounts;
  /** All normalized logical-day rows from the recap dataset (history_start → referenceDate), ordered descending by date. */
  days: PortalRecapDay[];
  /**
   * Recent-history slice: up to 14 days ending at referenceDate.
   * May include pre-month lookback rows from the SQL recap horizon.
   * Derived from the same `days` dataset — no second query.
   */
  recentDays: PortalRecapDay[];
}

/** Typed result union — never throws; callers decide how to handle each failure. */
export type PortalAttendanceRecapResult =
  | { ok: true; recap: PortalAttendanceRecapModel }
  | {
      ok: false;
      reason: 'unauthenticated' | 'no_mapping' | 'rpc_error';
      message: string;
    };

// ---------------------------------------------------------------------------
// Row normalizer
// ---------------------------------------------------------------------------

function normalizeRecapRow(row: PortalAttendanceRecapRow): PortalRecapDay {
  return {
    logicalDate: row.logical_date,
    hasSchedule: row.has_schedule ?? false,
    isDayOff: row.is_day_off ?? false,
    outletId: row.outlet_id ?? null,
    outletName: row.outlet_name ?? null,
    shiftName: row.shift_name ?? null,
    startHour: typeof row.start_hour === 'number' ? row.start_hour : 0,
    startMinute: typeof row.start_minute === 'number' ? row.start_minute : 0,
    endHour: typeof row.end_hour === 'number' ? row.end_hour : 0,
    endMinute: typeof row.end_minute === 'number' ? row.end_minute : 0,
    endsNextDay: row.ends_next_day ?? false,
    attendanceStatus: (row.attendance_status as AttendanceStatus) ?? null,
    firstMasukAt: row.first_masuk_at ?? null,
    firstBreakAt: row.first_break_at ?? null,
    lastKembaliAt: row.last_kembali_at ?? null,
    lastPulangAt: row.last_pulang_at ?? null,
    totalBreakMinutes: row.total_break_minutes ?? 0,
    workMinutes: row.work_minutes ?? null,
    scanCount: row.scan_count ?? 0,
    notes: row.notes ?? null,
  };
}

// ---------------------------------------------------------------------------
// Derive summary counts from normalized rows (current-month window only)
// ---------------------------------------------------------------------------

function deriveMonthStart(referenceDate: string): string {
  // referenceDate is "YYYY-MM-DD"; month start is always "YYYY-MM-01".
  return referenceDate.slice(0, 7) + '-01';
}

function deriveSummaryCounts(
  days: PortalRecapDay[],
  monthStart: string,
  referenceDate: string,
): AttendanceSummaryCounts {
  const counts: AttendanceSummaryCounts = {
    hadir: 0,
    sakit: 0,
    izin: 0,
    tidakHadir: 0,
    belumPulang: 0,
    libur: 0,
  };

  for (const day of days) {
    // Filter to current-month window only (monthStart ≤ logicalDate ≤ referenceDate).
    if (day.logicalDate < monthStart || day.logicalDate > referenceDate) {
      continue;
    }

    switch (day.attendanceStatus) {
      case 'hadir':
        counts.hadir++;
        break;
      case 'sakit':
        counts.sakit++;
        break;
      case 'izin':
        counts.izin++;
        break;
      case 'tidak_hadir':
        counts.tidakHadir++;
        break;
      case 'belum_pulang':
        counts.belumPulang++;
        break;
      case 'libur':
        counts.libur++;
        break;
      // sedang_bekerja, belum_masuk, null — not counted in summary chips
    }
  }

  return counts;
}

// ---------------------------------------------------------------------------
// Main loader
// ---------------------------------------------------------------------------

/**
 * Load the portal attendance recap for the authenticated employee.
 *
 * Security: employee identity is resolved server-side through
 * `resolvePortalEmployee()` and the recap rows come from an authenticated
 * SECURITY DEFINER RPC scoped by the portal session.
 * The page never supplies an employee identifier.
 *
 * Calls `get_portal_attendance_recap` exactly once. All derived datasets
 * (`summaryCounts`, `recentDays`) are computed from that single row set.
 *
 * Returns a typed result — never throws. Callers decide how to handle each
 * failure case (redirect, block render, etc.).
 */
export async function loadPortalAttendanceRecap(
  Astro: AstroGlobal,
): Promise<PortalAttendanceRecapResult> {
  // 1. Resolve employee identity — never accept an employee id from the page.
  const employeeResult = await resolvePortalEmployee(Astro);
  if (!employeeResult.ok) {
    return {
      ok: false,
      reason: employeeResult.reason,
      message: employeeResult.message,
    };
  }

  const employee = employeeResult.employee;

  // 2. Derive the business-local reference date using the same helper used by
  //    the schedule path so that schedule and recap always agree on the current day.
  const referenceDate = getPortalReferenceDate();

  // 3. Call the recap RPC exactly once — pass referenceDate to prevent UTC drift
  //    on Vercel server-rendered pages.
  const supabase = createSupabaseServerClient(
    Astro.request.headers.get('cookie') ?? '',
    Astro.response.headers,
  );

  const { data, error } = await supabase.rpc('get_portal_attendance_recap', {
    reference_date: referenceDate,
  });

  if (error) {
    return {
      ok: false,
      reason: 'rpc_error',
      message: error.message,
    };
  }

  // 4. Normalize the raw RPC rows into typed PortalRecapDay entries.
  //    The RPC already returns rows ordered DESC by logical_date.
  const days: PortalRecapDay[] = (Array.isArray(data) ? data : []).map((row) =>
    normalizeRecapRow(row as PortalAttendanceRecapRow),
  );

  // 5. Derive monthStart and summary counts from the same normalized dataset.
  const monthStart = deriveMonthStart(referenceDate);
  const summaryCounts = deriveSummaryCounts(days, monthStart, referenceDate);

  // 6. Derive recentDays: up to 14 days ending at referenceDate.
  //    Pre-month lookback rows (from the SQL 14-day horizon) are intentionally
  //    included here — the SQL recap horizon covers both the current month and
  //    a 14-day lookback, so recentDays may include pre-month days.
  //    Uses the same `days` slice: no second query.
  const recentCutoff = shiftIsoDate(referenceDate, -13); // referenceDate - 13 days
  const recentDays = days.filter((d) => d.logicalDate >= recentCutoff);

  return {
    ok: true,
    recap: {
      employee,
      referenceDate,
      monthStart,
      summaryCounts,
      days,
      recentDays,
    },
  };
}

// ---------------------------------------------------------------------------
// Internal date helper
// ---------------------------------------------------------------------------

/**
 * Shift an ISO date string by `offsetDays` (positive = future, negative = past).
 * Returns an ISO date string "YYYY-MM-DD".
 */
function shiftIsoDate(date: string, offsetDays: number): string {
  const shifted = new Date(`${date}T00:00:00Z`);
  shifted.setUTCDate(shifted.getUTCDate() + offsetDays);
  return shifted.toISOString().slice(0, 10);
}
