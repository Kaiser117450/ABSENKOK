// ---------------------------------------------------------------------------
// Portal streak loader + derived model
//
// Wraps the `get_portal_streak()` RPC (phase 64) and folds the raw streak
// counts into a UI-ready model with the same milestone taxonomy used by
// the Flutter kiosk streak experience:
//   - Visibility threshold: currentStreak >= 2 after masuk
//   - Milestones: 7 (week), 30 (month), 90 (quarter)
//
// This helper is the single source of truth for streak presentation on
// the portal. Components never compute tier or milestone math inline.
// ---------------------------------------------------------------------------
import type { AstroGlobal } from 'astro';
import { createSupabaseServerClient } from '../supabase/server';
import { resolvePortalEmployee } from './employee';
import type { PortalEmployee } from './employee';

/** Streak milestones shared with the kiosk celebration surface. */
export const STREAK_MILESTONES: readonly number[] = [7, 30, 90] as const;

/** Minimum currentStreak value before the portal card should render. */
export const STREAK_VISIBILITY_THRESHOLD = 2;

/** Tier bucket that drives gradient + flame colour choices in the UI. */
export type StreakTier = 'cold' | 'warm' | 'hot' | 'blazing';

export interface PortalStreakModel {
  employee: PortalEmployee;
  currentStreak: number;
  longestStreak: number;
  /** ISO "YYYY-MM-DD" of the most recent masuk scan, or null when none. */
  lastMasukDate: string | null;
  /** Next milestone (7/30/90) strictly greater than currentStreak, or null. */
  nextMilestone: number | null;
  /** Days remaining to nextMilestone, or null when past all milestones. */
  daysToNextMilestone: number | null;
  /** True when currentStreak equals longestStreak AND ≥ 3 (avoid celebrating 2). */
  atPersonalBest: boolean;
  /** Tier bucket derived from currentStreak magnitude. */
  tier: StreakTier;
  /** True when currentStreak ≥ STREAK_VISIBILITY_THRESHOLD. */
  visible: boolean;
}

export type PortalStreakResult =
  | { ok: true; streak: PortalStreakModel }
  | {
      ok: false;
      reason: 'unauthenticated' | 'no_mapping' | 'rpc_error';
      message: string;
    };

interface PortalStreakRow {
  current_streak: number | null;
  longest_streak: number | null;
  last_masuk_date: string | null;
}

// ---------------------------------------------------------------------------
// Derivation helpers — pure, exported for tests
// ---------------------------------------------------------------------------

export function deriveTier(currentStreak: number): StreakTier {
  if (currentStreak >= 30) return 'blazing';
  if (currentStreak >= 7) return 'hot';
  if (currentStreak >= STREAK_VISIBILITY_THRESHOLD) return 'warm';
  return 'cold';
}

export function deriveNextMilestone(currentStreak: number): number | null {
  return STREAK_MILESTONES.find((m) => m > currentStreak) ?? null;
}

export function buildStreakModel(
  employee: PortalEmployee,
  row: PortalStreakRow | null,
): PortalStreakModel {
  const currentStreak = Math.max(0, row?.current_streak ?? 0);
  const longestStreak = Math.max(0, row?.longest_streak ?? 0);
  const lastMasukDate = row?.last_masuk_date ?? null;
  const nextMilestone = deriveNextMilestone(currentStreak);
  const daysToNextMilestone = nextMilestone !== null ? nextMilestone - currentStreak : null;
  const atPersonalBest =
    currentStreak > 0 && currentStreak === longestStreak && currentStreak >= 3;
  const tier = deriveTier(currentStreak);
  const visible = currentStreak >= STREAK_VISIBILITY_THRESHOLD;

  return {
    employee,
    currentStreak,
    longestStreak,
    lastMasukDate,
    nextMilestone,
    daysToNextMilestone,
    atPersonalBest,
    tier,
    visible,
  };
}

// ---------------------------------------------------------------------------
// Loader
// ---------------------------------------------------------------------------

/**
 * Load the authenticated portal employee's streak and fold it into a
 * presentation-ready model. Never throws — callers branch on `ok`.
 */
export async function loadPortalStreak(Astro: AstroGlobal): Promise<PortalStreakResult> {
  const employeeResult = await resolvePortalEmployee(Astro);
  if (!employeeResult.ok) {
    return { ok: false, reason: employeeResult.reason, message: employeeResult.message };
  }

  const supabase = createSupabaseServerClient(
    Astro.request.headers.get('cookie') ?? '',
    Astro.response.headers,
  );

  const { data, error } = await supabase.rpc('get_portal_streak');
  if (error) {
    return { ok: false, reason: 'rpc_error', message: error.message };
  }

  const row: PortalStreakRow | null = Array.isArray(data)
    ? ((data[0] as PortalStreakRow) ?? null)
    : ((data as PortalStreakRow | null) ?? null);

  return {
    ok: true,
    streak: buildStreakModel(employeeResult.employee, row),
  };
}
