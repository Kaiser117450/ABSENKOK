// ---------------------------------------------------------------------------
// Portal leaderboard loader + transparent scoring
//
// Wraps the `get_portal_leaderboard(reference_date, window_days)` RPC
// (phase 64) and folds the raw aggregate counts into a scored, ranked
// presentation model. The scoring formula lives here — in TypeScript —
// rather than inside SQL so that:
//
//   1. The weights are readable at the call site and auditable in review.
//   2. Portal UI can explain the score using the exact same constants.
//   3. Tuning weights never requires a database migration.
//
// The formula is additive and signed: positive weights reward good
// attendance behaviour, negative weights punish unresolved or problematic
// days. All inputs are already normalised to the same observation window
// by SQL — typically 14 days — so the score is directly comparable across
// outlets and employees.
//
// scoringFormula (default weights, kept in sync with portal UI copy):
//   score = +3.0 * currentStreak        (lightly capped at STREAK_CAP)
//         + +4.0 * hadir_count          (strong reward: showed up properly)
//         + -3.0 * late_count           (late scans)
//         + -2.0 * short_work_count     (went home more than an hour early)
//         + -2.0 * excess_break_count   (break > 90 minutes)
//         + -4.0 * belum_pulang_count   (prior-day missing pulang)
//         + -5.0 * tidak_hadir_count    (scheduled absence without note)
//
// sakit and izin are *not* scored — they are legitimate absences and the
// portal should never punish employees for documented leave. They are
// still returned as contextual counts.
// ---------------------------------------------------------------------------
import type { AstroGlobal } from 'astro';
import { createSupabaseServerClient } from '../supabase/server';
import { resolvePortalEmployee } from './employee';
import type { PortalEmployee } from './employee';
import { getPortalReferenceDate } from './schedule';
import type { AttendanceStatus } from './attendance-recap';

// ---------------------------------------------------------------------------
// Scoring constants — exported so the UI can show a legend
// ---------------------------------------------------------------------------

export const LEADERBOARD_WINDOW_DAYS = 14;
export const STREAK_CAP = 30;

export interface LeaderboardWeights {
  streak: number;
  hadir: number;
  late: number;
  shortWork: number;
  excessBreak: number;
  belumPulang: number;
  tidakHadir: number;
}

export const DEFAULT_WEIGHTS: LeaderboardWeights = {
  streak: 3,
  hadir: 4,
  late: -3,
  shortWork: -2,
  excessBreak: -2,
  belumPulang: -4,
  tidakHadir: -5,
};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Raw aggregate row as returned by `get_portal_leaderboard`. */
interface LeaderboardRpcRow {
  employee_id: string;
  employee_name: string;
  position: string | null;
  outlet_id: string | null;
  outlet_name: string | null;
  photo_url: string | null;
  current_streak: number | null;
  longest_streak: number | null;
  hadir_count: number | null;
  tidak_hadir_count: number | null;
  belum_pulang_count: number | null;
  sakit_count: number | null;
  izin_count: number | null;
  late_count: number | null;
  short_work_count: number | null;
  excess_break_count: number | null;
  /** Array of AttendanceStatus strings, newest last, null for days with no row. */
  sparkline: (string | null)[] | null;
}

/** Presentation model for one leaderboard row — sorted, scored, and ranked. */
export interface PortalLeaderboardEntry {
  rank: number;
  employeeId: string;
  employeeName: string;
  position: string | null;
  outletId: string | null;
  outletName: string | null;
  photoUrl: string | null;
  currentStreak: number;
  longestStreak: number;
  hadirCount: number;
  tidakHadirCount: number;
  belumPulangCount: number;
  sakitCount: number;
  izinCount: number;
  lateCount: number;
  shortWorkCount: number;
  excessBreakCount: number;
  /** Day-by-day statuses oldest → newest, length = window_days. Missing days are null. */
  sparkline: (AttendanceStatus | null)[];
  /** Final score (rounded to 1 decimal for display; raw internally). */
  score: number;
  /** True when this row is the authenticated viewer's own entry. */
  isSelf: boolean;
}

export interface PortalLeaderboardModel {
  viewer: PortalEmployee;
  referenceDate: string;
  windowDays: number;
  weights: LeaderboardWeights;
  entries: PortalLeaderboardEntry[];
  /** Entry matching the viewer, even if below visible cutoff. */
  selfEntry: PortalLeaderboardEntry | null;
}

export type PortalLeaderboardResult =
  | { ok: true; leaderboard: PortalLeaderboardModel }
  | {
      ok: false;
      reason: 'unauthenticated' | 'no_mapping' | 'rpc_error';
      message: string;
    };

// ---------------------------------------------------------------------------
// Pure scoring — exported for tests
// ---------------------------------------------------------------------------

export interface ScoreInputs {
  currentStreak: number;
  hadirCount: number;
  lateCount: number;
  shortWorkCount: number;
  excessBreakCount: number;
  belumPulangCount: number;
  tidakHadirCount: number;
}

export function computeScore(
  inputs: ScoreInputs,
  weights: LeaderboardWeights = DEFAULT_WEIGHTS,
): number {
  const cappedStreak = Math.min(inputs.currentStreak, STREAK_CAP);
  return (
    weights.streak * cappedStreak +
    weights.hadir * inputs.hadirCount +
    weights.late * inputs.lateCount +
    weights.shortWork * inputs.shortWorkCount +
    weights.excessBreak * inputs.excessBreakCount +
    weights.belumPulang * inputs.belumPulangCount +
    weights.tidakHadir * inputs.tidakHadirCount
  );
}

// ---------------------------------------------------------------------------
// Row normalisation + ranking
// ---------------------------------------------------------------------------

function normaliseRow(
  row: LeaderboardRpcRow,
  viewerEmployeeId: string,
  weights: LeaderboardWeights,
): Omit<PortalLeaderboardEntry, 'rank'> {
  const currentStreak = Math.max(0, row.current_streak ?? 0);
  const longestStreak = Math.max(0, row.longest_streak ?? 0);
  const hadirCount = Math.max(0, row.hadir_count ?? 0);
  const tidakHadirCount = Math.max(0, row.tidak_hadir_count ?? 0);
  const belumPulangCount = Math.max(0, row.belum_pulang_count ?? 0);
  const sakitCount = Math.max(0, row.sakit_count ?? 0);
  const izinCount = Math.max(0, row.izin_count ?? 0);
  const lateCount = Math.max(0, row.late_count ?? 0);
  const shortWorkCount = Math.max(0, row.short_work_count ?? 0);
  const excessBreakCount = Math.max(0, row.excess_break_count ?? 0);

  const score = computeScore(
    {
      currentStreak,
      hadirCount,
      lateCount,
      shortWorkCount,
      excessBreakCount,
      belumPulangCount,
      tidakHadirCount,
    },
    weights,
  );

  const sparkline = Array.isArray(row.sparkline)
    ? row.sparkline.map((v) => (v as AttendanceStatus | null) ?? null)
    : [];

  return {
    employeeId: row.employee_id,
    employeeName: row.employee_name,
    position: row.position ?? null,
    outletId: row.outlet_id ?? null,
    outletName: row.outlet_name ?? null,
    photoUrl: row.photo_url ?? null,
    currentStreak,
    longestStreak,
    hadirCount,
    tidakHadirCount,
    belumPulangCount,
    sakitCount,
    izinCount,
    lateCount,
    shortWorkCount,
    excessBreakCount,
    sparkline,
    score: Math.round(score * 10) / 10,
    isSelf: row.employee_id === viewerEmployeeId,
  };
}

// ---------------------------------------------------------------------------
// Loader
// ---------------------------------------------------------------------------

export async function loadPortalLeaderboard(
  Astro: AstroGlobal,
  options?: { windowDays?: number; weights?: LeaderboardWeights },
): Promise<PortalLeaderboardResult> {
  const employeeResult = await resolvePortalEmployee(Astro);
  if (!employeeResult.ok) {
    return { ok: false, reason: employeeResult.reason, message: employeeResult.message };
  }

  const viewer = employeeResult.employee;
  const windowDays = options?.windowDays ?? LEADERBOARD_WINDOW_DAYS;
  const weights = options?.weights ?? DEFAULT_WEIGHTS;
  const referenceDate = getPortalReferenceDate();

  const supabase = createSupabaseServerClient(
    Astro.request.headers.get('cookie') ?? '',
    Astro.response.headers,
  );

  const { data, error } = await supabase.rpc('get_portal_leaderboard', {
    reference_date: referenceDate,
    window_days: windowDays,
  });

  if (error) {
    return { ok: false, reason: 'rpc_error', message: error.message };
  }

  const rawRows: LeaderboardRpcRow[] = Array.isArray(data)
    ? (data as LeaderboardRpcRow[])
    : [];

  // Normalise + score each row.
  const scored = rawRows.map((row) => normaliseRow(row, viewer.employee_id, weights));

  // Rank: highest score wins. Ties broken by:
  //   1. higher currentStreak
  //   2. more hadir days
  //   3. alphabetical employee name
  scored.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    if (b.currentStreak !== a.currentStreak) return b.currentStreak - a.currentStreak;
    if (b.hadirCount !== a.hadirCount) return b.hadirCount - a.hadirCount;
    return a.employeeName.localeCompare(b.employeeName, 'id-ID');
  });

  const entries: PortalLeaderboardEntry[] = scored.map((e, idx) => ({
    ...e,
    rank: idx + 1,
  }));

  const selfEntry = entries.find((e) => e.isSelf) ?? null;

  return {
    ok: true,
    leaderboard: {
      viewer,
      referenceDate,
      windowDays,
      weights,
      entries,
      selfEntry,
    },
  };
}
