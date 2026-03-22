import type { AstroGlobal } from 'astro';
import { createSupabaseServerClient } from '../supabase/server';
import { resolvePortalEmployee } from './employee';
import type { PortalEmployee } from './employee';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** One schedule assignment row as returned by the portal schedule helper. */
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
  /** Assignments after today within the current week, ordered by logicalDate ascending. */
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

interface RpcScheduleRow {
  logical_date: string;
  outlet_id: string | null;
  outlet_name: string | null;
  shift_name: string | null;
  start_hour: number;
  start_minute: number;
  end_hour: number;
  end_minute: number;
  is_day_off: boolean;
  ends_next_day: boolean;
  notes: string | null;
}

// ---------------------------------------------------------------------------
// Row normalizer
// ---------------------------------------------------------------------------

function normalizeRow(row: RpcScheduleRow): PortalScheduleEntry {
  return {
    logicalDate: row.logical_date,
    outletId: row.outlet_id ?? null,
    outletName: row.outlet_name ?? null,
    shiftName: row.shift_name ?? null,
    startHour: row.start_hour,
    startMinute: row.start_minute,
    endHour: row.end_hour,
    endMinute: row.end_minute,
    endsNextDay: row.ends_next_day,
    isDayOff: row.is_day_off,
    notes: row.notes ?? null,
  };
}

// ---------------------------------------------------------------------------
// Main helper
// ---------------------------------------------------------------------------

/**
 * Load the current-week portal schedule for the authenticated employee.
 *
 * Security: employee identity is resolved server-side through
 * `resolvePortalEmployee()`. The page never supplies the employee ID — the
 * RPC `get_portal_schedule_week` resolves it internally from `auth.uid()`.
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

  // 2. Compute one explicit business-local reference date for the RPC.
  const referenceDate = getPortalReferenceDate();

  // 3. Call the employee-scoped schedule RPC.
  const supabase = createSupabaseServerClient(
    Astro.request.headers.get('cookie') ?? '',
    Astro.response.headers,
  );

  const { data, error } = await supabase
    .rpc('get_portal_schedule_week', { reference_date: referenceDate });

  if (error) {
    return {
      ok: false,
      reason: 'rpc_error',
      message: error.message,
    };
  }

  const rows: PortalScheduleEntry[] = ((data ?? []) as RpcScheduleRow[])
    .map(normalizeRow)
    .sort((a, b) => a.logicalDate.localeCompare(b.logicalDate));

  // 4. Derive today and upcoming from one dataset.
  const todayAssignment = rows.find((r) => r.logicalDate === referenceDate) ?? null;
  const upcomingAssignments = rows.filter((r) => r.logicalDate > referenceDate);

  return {
    ok: true,
    schedule: {
      employee,
      referenceDate,
      todayAssignment,
      weekAssignments: rows,
      upcomingAssignments,
    },
  };
}
