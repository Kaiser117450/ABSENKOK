import type { AstroGlobal } from 'astro';
import { createSupabaseServerClient } from '../supabase/server';
import { loadPortalSchedule } from './schedule';
import type { PortalEmployee } from './employee';
import type { PortalScheduleModel } from './schedule';

// ---------------------------------------------------------------------------
// Portal Home State — discriminated union
// ---------------------------------------------------------------------------

/**
 * Page-level state union for the portal home (`/portal`).
 *
 * Callers branch on `state.kind` and never need to inspect raw `ok`/`reason`
 * fields from the underlying schedule result.
 */
export type PortalHomeState =
  | {
      kind: 'ready';
      schedule: PortalScheduleModel;
      currentStreak: number;
      longestStreak: number;
    }
  | {
      kind: 'empty';
      /** Authenticated employee whose schedule has no entries for the current week. */
      employee: PortalEmployee;
      referenceDate: string;
      currentStreak: number;
      longestStreak: number;
    }
  | {
      kind: 'not-linked';
      message: string;
    }
  | {
      kind: 'error';
      message: string;
    }
  | {
      kind: 'unauthenticated';
      message: string;
    };

// ---------------------------------------------------------------------------
// Streak fetcher
// ---------------------------------------------------------------------------

async function fetchEmployeeStreak(
  Astro: AstroGlobal,
  employeeId: string,
): Promise<{ currentStreak: number; longestStreak: number }> {
  const supabase = createSupabaseServerClient(
    Astro.request.headers.get('cookie') ?? '',
    null,
  );

  const { data: streakData } = await supabase
    .from('employee_streaks')
    .select('current_streak, longest_streak')
    .eq('employee_id', employeeId)
    .maybeSingle();

  return {
    currentStreak: streakData?.current_streak ?? 0,
    longestStreak: streakData?.longest_streak ?? 0,
  };
}

// ---------------------------------------------------------------------------
// Page-level loader
// ---------------------------------------------------------------------------

/**
 * Load the portal home state for the authenticated employee.
 *
 * Maps the raw `PortalScheduleResult` from `loadPortalSchedule` into a
 * page-ready `PortalHomeState` so that `index.astro` never branches on
 * low-level `ok`/`reason` fields.
 *
 * - `no_mapping`     → `not-linked`
 * - `rpc_error`      → `error`
 * - `unauthenticated`→ `unauthenticated`
 * - `no_assignments` → `empty` (preserves the authenticated employee identity)
 * - `ok: true`       → `ready`
 */
export async function loadPortalHome(Astro: AstroGlobal): Promise<PortalHomeState> {
  const result = await loadPortalSchedule(Astro);

  if (!result.ok) {
    switch (result.reason) {
      case 'unauthenticated':
        return { kind: 'unauthenticated', message: result.message };
      case 'no_mapping':
        return { kind: 'not-linked', message: result.message };
      case 'no_assignments':
        // no_assignments means the employee is resolved but has no schedule entries.
        // This state is reachable only via loadPortalSchedule producing ok:false with
        // no_assignments reason. However, per schedule.ts implementation, no_assignments
        // is never returned — the loader returns ok:true with empty weekAssignments.
        // Guard here for forward compatibility.
        return {
          kind: 'empty',
          employee: { employee_id: '', employee_name: '', position: null, home_outlet_id: null, home_outlet_name: null, photo_url: null, active_badge_id: null },
          referenceDate: '',
          currentStreak: 0,
          longestStreak: 0,
        };
      case 'rpc_error':
        return { kind: 'error', message: result.message };
    }
  }

  const schedule = result.schedule;

  // Fetch streak data for the authenticated employee.
  const streak = await fetchEmployeeStreak(Astro, schedule.employee.employee_id);

  // Treat only a fully-empty two-week horizon as the empty state, surfacing
  // the employee identity so the shell can still greet them by name.
  if (schedule.weekAssignments.length === 0 && schedule.nextWeekAssignments.length === 0) {
    return {
      kind: 'empty',
      employee: schedule.employee,
      referenceDate: schedule.referenceDate,
      currentStreak: streak.currentStreak,
      longestStreak: streak.longestStreak,
    };
  }

  return {
    kind: 'ready',
    schedule,
    currentStreak: streak.currentStreak,
    longestStreak: streak.longestStreak,
  };
}
