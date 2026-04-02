import type { AstroGlobal } from 'astro';
import { createSupabaseServerClient } from '../supabase/server';
import { resolvePortalEmployee } from './employee';
import type { PortalEmployee } from './employee';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** One schedule assignment row as returned by the portal schedule helper. */
export type PortalScheduleStatus = 'normal' | 'libur' | 'sakit' | 'izin';

export interface PortalScheduleEntry {
  /** Logical calendar date for this assignment (always the scheduled start day). */
  logicalDate: string; // ISO date string: "YYYY-MM-DD"
  outletId: string | null;
  outletName: string | null;
  shiftName: string | null;
  startHour: number;
  startMinute: number;
  endHour: number;
  endMinute: number;
  /** True when the shift ends past midnight on the next day. */
  endsNextDay: boolean;
  /** True when this slot is a scheduled day off (libur). */
  isDayOff: boolean;
  /** Employee-specific state overlayed from schedule + attendance status sources. */
  status: PortalScheduleStatus;
  notes: string | null;
}

/** The fully-typed portal schedule model returned to pages. */
export interface PortalScheduleModel {
  employee: PortalEmployee;
  /** The explicit business-local reference date used to anchor the week. ISO date string. */
  referenceDate: string;
  /** Assignment for today (matches referenceDate), or null when there is none. */
  todayAssignment: PortalScheduleEntry | null;
  /** All assignments for the current ISO week, ordered by logicalDate ascending. */
  weekAssignments: PortalScheduleEntry[];
  /** All assignments for the next ISO week, ordered by logicalDate ascending. */
  nextWeekAssignments: PortalScheduleEntry[];
  /** Assignments after today within the fetched two-week horizon, ordered by logicalDate ascending. */
  upcomingAssignments: PortalScheduleEntry[];
}

/** Typed result union — never throws; callers decide how to handle each failure. */
export type PortalScheduleResult =
  | { ok: true; schedule: PortalScheduleModel }
  | {
      ok: false;
      reason: 'unauthenticated' | 'no_mapping' | 'rpc_error' | 'no_assignments';
      message: string;
    };

// ---------------------------------------------------------------------------
// Business-local date helper
// ---------------------------------------------------------------------------

/**
 * Derive the current business-local date as an ISO date string (YYYY-MM-DD).
 *
 * The portal is server-rendered on Vercel (UTC). The business timezone is
 * Asia/Makassar (WITA, UTC+8). This helper centralises the assumption so a
 * future timezone field can replace it without touching every portal page.
 */
export function getPortalReferenceDate(): string {
  const now = new Date();
  // Format in the business timezone to get the local calendar date.
  const formatter = new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'Asia/Makassar',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(now); // "YYYY-MM-DD" (sv-SE locale produces ISO format)
}

// ---------------------------------------------------------------------------
// Raw RPC row type
// ---------------------------------------------------------------------------

interface PortalScheduleOverviewRow {
  logical_date: string;
  outlet_id: string | null;
  outlet_name: string | null;
  shift_name: string | null;
  start_hour: number | null;
  start_minute: number | null;
  end_hour: number | null;
  end_minute: number | null;
  is_day_off: boolean | null;
  ends_next_day: boolean | null;
  entry_status: string | null;
  notes: string | null;
}

// ---------------------------------------------------------------------------
// Row normalizer
// ---------------------------------------------------------------------------

function normalizeRow(
  row: PortalScheduleOverviewRow,
): PortalScheduleEntry {
  const startHour = typeof row.start_hour === 'number' ? row.start_hour : 0;
  const startMinute = typeof row.start_minute === 'number' ? row.start_minute : 0;
  const endHour = typeof row.end_hour === 'number' ? row.end_hour : 0;
  const endMinute = typeof row.end_minute === 'number' ? row.end_minute : 0;
  const isDayOff = row.is_day_off ?? false;
  const status = normalizeStatus(row.entry_status, isDayOff);

  return {
    logicalDate: row.logical_date,
    outletId: row.outlet_id ?? null,
    outletName: row.outlet_name ?? null,
    shiftName: row.shift_name ?? null,
    startHour,
    startMinute,
    endHour,
    endMinute,
    endsNextDay: row.ends_next_day ?? (!isDayOff && (endHour < startHour || (endHour === startHour && endMinute <= startMinute))),
    isDayOff,
    status,
    notes: row.notes ?? null,
  };
}

function getPortalWeekRange(referenceDate: string) {
  const current = new Date(`${referenceDate}T00:00:00Z`);
  const isoDay = ((current.getUTCDay() + 6) % 7) + 1;
  const weekStart = new Date(current);
  weekStart.setUTCDate(current.getUTCDate() - (isoDay - 1));
  const weekEnd = new Date(weekStart);
  weekEnd.setUTCDate(weekStart.getUTCDate() + 6);

  return {
    weekStart: weekStart.toISOString().slice(0, 10),
    weekEnd: weekEnd.toISOString().slice(0, 10),
  };
}

function shiftIsoDate(date: string, offsetDays: number): string {
  const shifted = new Date(`${date}T00:00:00Z`);
  shifted.setUTCDate(shifted.getUTCDate() + offsetDays);
  return shifted.toISOString().slice(0, 10);
}

function normalizeStatus(
  status: string | null,
  isDayOff: boolean,
): PortalScheduleStatus {
  switch (status) {
    case 'sakit':
      return 'sakit';
    case 'izin':
      return 'izin';
    case 'libur':
      return 'libur';
    default:
      return isDayOff ? 'libur' : 'normal';
  }
}

// ---------------------------------------------------------------------------
// Main helper
// ---------------------------------------------------------------------------

/**
 * Load the current-week portal schedule for the authenticated employee.
 *
 * Security: employee identity is resolved server-side through
 * `resolvePortalEmployee()` and the schedule rows come from an authenticated
 * RPC scoped by the portal session. The page never supplies employee ID.
 *
 * Returns a typed empty-state result (`no_assignments`) when the employee
 * exists but has no schedule entries for the current week.
 */
export async function loadPortalSchedule(Astro: AstroGlobal): Promise<PortalScheduleResult> {
  // 1. Resolve employee identity first.
  const employeeResult = await resolvePortalEmployee(Astro);
  if (!employeeResult.ok) {
    return {
      ok: false,
      reason: employeeResult.reason,
      message: employeeResult.message,
    };
  }

  const employee = employeeResult.employee;

  // 2. Compute one explicit business-local reference date and week boundaries.
  const referenceDate = getPortalReferenceDate();
  const { weekStart, weekEnd } = getPortalWeekRange(referenceDate);
  const nextWeekStart = shiftIsoDate(weekEnd, 1);
  const nextWeekEnd = shiftIsoDate(nextWeekStart, 6);

  const supabase = createSupabaseServerClient(
    Astro.request.headers.get('cookie') ?? '',
    Astro.response.headers,
  );
  const { data, error } = await supabase.rpc('get_portal_schedule_overview', {
    reference_date: referenceDate,
  });

  if (error) {
    return {
      ok: false,
      reason: 'rpc_error',
      message: error.message,
    };
  }

  const rows = (Array.isArray(data) ? data : [])
    .map((row) => normalizeRow(row as PortalScheduleOverviewRow))
    .sort((a, b) => a.logicalDate.localeCompare(b.logicalDate));

  // 4. Derive today and upcoming from one dataset.
  const todayAssignment = rows.find((r) => r.logicalDate === referenceDate) ?? null;
  const upcomingAssignments = rows.filter((r) => r.logicalDate > referenceDate);
  const weekAssignments = rows.filter((r) => r.logicalDate >= weekStart && r.logicalDate <= weekEnd);
  const nextWeekAssignments = rows.filter((r) => r.logicalDate >= nextWeekStart && r.logicalDate <= nextWeekEnd);

  return {
    ok: true,
    schedule: {
      employee,
      referenceDate,
      todayAssignment,
      weekAssignments,
      nextWeekAssignments,
      upcomingAssignments,
    },
  };
}
