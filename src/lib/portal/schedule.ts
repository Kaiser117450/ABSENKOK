import type { AstroGlobal } from 'astro';
import { createSupabaseAdminClient } from '../supabase/admin';
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

interface ShiftSlotRow {
  name?: string;
  start_hour?: number;
  start_minute?: number;
  end_hour?: number;
  end_minute?: number;
}

interface ScheduleEntryRow {
  date: string;
  shift_slot: ShiftSlotRow | null;
  is_day_off: boolean | null;
  notes: string | null;
  schedule_id: string;
}

interface ScheduleRow {
  id: string;
  outlet_id: string | null;
  is_active: boolean;
}

interface OutletRow {
  id: string;
  name: string;
}

// ---------------------------------------------------------------------------
// Row normalizer
// ---------------------------------------------------------------------------

function normalizeRow(
  row: ScheduleEntryRow,
  outletName: string | null,
  outletId: string | null,
): PortalScheduleEntry {
  const shift = row.shift_slot ?? {};
  const startHour = typeof shift.start_hour === 'number' ? shift.start_hour : 0;
  const startMinute = typeof shift.start_minute === 'number' ? shift.start_minute : 0;
  const endHour = typeof shift.end_hour === 'number' ? shift.end_hour : 0;
  const endMinute = typeof shift.end_minute === 'number' ? shift.end_minute : 0;
  const isDayOff = row.is_day_off ?? false;

  return {
    logicalDate: row.date,
    outletId,
    outletName,
    shiftName: shift.name ?? null,
    startHour,
    startMinute,
    endHour,
    endMinute,
    endsNextDay: !isDayOff && (endHour < startHour || (endHour === startHour && endMinute <= startMinute)),
    isDayOff,
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

// ---------------------------------------------------------------------------
// Main helper
// ---------------------------------------------------------------------------

/**
 * Load the current-week portal schedule for the authenticated employee.
 *
 * Security: employee identity is resolved server-side through
 * `resolvePortalEmployee()`. The page never supplies the employee ID — the
 * authenticated portal session carries the employee id in `app_metadata`.
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

  const admin = createSupabaseAdminClient();

  const { data: entries, error: entriesError } = await admin
    .from('schedule_entries')
    .select('date, shift_slot, is_day_off, notes, schedule_id')
    .eq('employee_id', employee.employee_id)
    .gte('date', weekStart)
    .lte('date', weekEnd)
    .order('date', { ascending: true })
    .returns<ScheduleEntryRow[]>();

  if (entriesError) {
    return {
      ok: false,
      reason: 'rpc_error',
      message: entriesError.message,
    };
  }

  const scheduleIds = Array.from(new Set((entries ?? []).map((entry) => entry.schedule_id)));
  const { data: schedules, error: schedulesError } = scheduleIds.length === 0
    ? { data: [] as ScheduleRow[], error: null }
    : await admin
        .from('schedules')
        .select('id, outlet_id, is_active')
        .in('id', scheduleIds)
        .eq('is_active', true)
        .returns<ScheduleRow[]>();

  if (schedulesError) {
    return {
      ok: false,
      reason: 'rpc_error',
      message: schedulesError.message,
    };
  }

  const outletIds = Array.from(new Set((schedules ?? []).map((schedule) => schedule.outlet_id).filter(Boolean))) as string[];
  const { data: outlets, error: outletsError } = outletIds.length === 0
    ? { data: [] as OutletRow[], error: null }
    : await admin
        .from('outlets')
        .select('id, name')
        .in('id', outletIds)
        .returns<OutletRow[]>();

  if (outletsError) {
    return {
      ok: false,
      reason: 'rpc_error',
      message: outletsError.message,
    };
  }

  const scheduleMap = new Map((schedules ?? []).map((schedule) => [schedule.id, schedule]));
  const outletMap = new Map((outlets ?? []).map((outlet) => [outlet.id, outlet.name]));

  const rows: PortalScheduleEntry[] = (entries ?? [])
    .filter((entry) => scheduleMap.has(entry.schedule_id))
    .map((entry) => {
      const schedule = scheduleMap.get(entry.schedule_id) ?? null;
      const outletId = schedule?.outlet_id ?? null;
      return normalizeRow(entry, outletId ? outletMap.get(outletId) ?? null : null, outletId);
    })
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
