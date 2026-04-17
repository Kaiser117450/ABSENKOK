import { getPortalReferenceDate } from './portal/schedule';
import { createSupabaseAdminClient } from './supabase/admin';
import { hasSupabaseAdminEnv } from './supabase/env';
import { createSupabasePublicClient } from './supabase/public';

type LeaderboardSource = 'public_rpc' | 'admin_fallback';
type ScoreTone = 'excellent' | 'steady' | 'warning' | 'critical' | 'unrated';

interface SiteLeaderboardRpcRow {
  employee_id: string;
  employee_name: string;
  employee_position: string | null;
  home_outlet_id: string | null;
  home_outlet_name: string | null;
  measured_days: number | null;
  safe_days: number | null;
  issue_days: number | null;
  neutral_days: number | null;
  overtime_only_days: number | null;
  late_count: number | null;
  absence_count: number | null;
  short_work_count: number | null;
  excess_break_count: number | null;
  overtime_count: number | null;
  unresolved_count: number | null;
  current_streak: number | null;
  longest_streak: number | null;
}

interface ActiveEmployeeRow {
  id: string;
  name: string;
  position: string | null;
  home_outlet_id: string | null;
}

interface OutletRow {
  id: string;
  name: string;
}

interface StreakRow {
  employee_id: string;
  current_streak: number | null;
  longest_streak: number | null;
}

interface StrictRecapRow {
  employee_id: string;
  attendance_status: string | null;
  primary_status: string | null;
  logical_day_complete: boolean | null;
  detail_signals: string[] | null;
}

export interface LeaderboardEntry {
  rank: number;
  employeeId: string;
  employeeName: string;
  position: string | null;
  homeOutletName: string | null;
  measuredDays: number;
  safeDays: number;
  issueDays: number;
  neutralDays: number;
  overtimeOnlyDays: number;
  lateCount: number;
  absenceCount: number;
  shortWorkCount: number;
  excessBreakCount: number;
  overtimeCount: number;
  unresolvedCount: number;
  totalIssues: number;
  currentStreak: number;
  longestStreak: number;
  score: number;
  scoreLabel: string;
  scoreTone: ScoreTone;
  insight: string;
}

export interface LeaderboardSummary {
  employeeCount: number;
  ratedEmployeeCount: number;
  averageScore: number;
  topScore: number;
  bestStreak: number;
  totalIssueDays: number;
}

export interface SiteLeaderboardModel {
  referenceDate: string;
  monthLabel: string;
  source: LeaderboardSource;
  summary: LeaderboardSummary;
  entries: LeaderboardEntry[];
}

export type SiteLeaderboardState =
  | { ok: true; leaderboard: SiteLeaderboardModel }
  | { ok: false; title: string; message: string };

export async function loadSiteLeaderboard(): Promise<SiteLeaderboardState> {
  const referenceDate = getPortalReferenceDate();

  try {
    const rows = await fetchPublicLeaderboard(referenceDate);
    return {
      ok: true,
      leaderboard: buildLeaderboardModel(rows, referenceDate, 'public_rpc'),
    };
  } catch (publicError) {
    console.error('[leaderboard] public RPC failed:', publicError);

    if (hasSupabaseAdminEnv()) {
      try {
        const rows = await fetchAdminFallbackLeaderboard(referenceDate);
        return {
          ok: true,
          leaderboard: buildLeaderboardModel(rows, referenceDate, 'admin_fallback'),
        };
      } catch (adminError) {
        console.error('[leaderboard] admin fallback failed:', adminError);
        return {
          ok: false,
          title: 'Tidak dapat memuat peringkat',
          message: buildLeaderboardErrorMessage(publicError, adminError),
        };
      }
    }

    return {
      ok: false,
      title: 'Tidak dapat memuat peringkat',
      message: buildLeaderboardErrorMessage(publicError, null),
    };
  }
}

async function fetchPublicLeaderboard(referenceDate: string) {
  const supabase = createSupabasePublicClient();
  const { data, error } = await supabase.rpc('get_site_leaderboard', {
    p_reference_date: referenceDate,
  });

  if (error) {
    throw new Error(error.message);
  }

  return extractRows<SiteLeaderboardRpcRow>(data);
}

async function fetchAdminFallbackLeaderboard(referenceDate: string) {
  const supabase = createSupabaseAdminClient();
  const monthStart = deriveMonthStart(referenceDate);
  const [
    { data: employeesData, error: employeesError },
    { data: outletsData, error: outletsError },
    { data: streaksData, error: streaksError },
  ] = await Promise.all([
    supabase
      .from('employees')
      .select('id, name, position, home_outlet_id')
      .eq('is_active', true)
      .is('archived_at', null)
      .order('name'),
    supabase.from('outlets').select('id, name'),
    supabase.from('employee_streaks').select('employee_id, current_streak, longest_streak'),
  ]);

  if (employeesError) throw new Error(employeesError.message);
  if (outletsError) throw new Error(outletsError.message);
  if (streaksError) throw new Error(streaksError.message);

  const employees = extractRows<ActiveEmployeeRow>(employeesData);
  const outlets = extractRows<OutletRow>(outletsData);
  const streaks = extractRows<StreakRow>(streaksData);
  const outletNameById = new Map(outlets.map((outlet) => [outlet.id, outlet.name]));

  const recapGroups = await Promise.all(
    outlets.map(async (outlet) => {
      const { data, error } = await supabase.rpc('get_admin_schedule_policy_recap', {
        p_outlet_id: outlet.id,
        p_start_date: monthStart,
        p_end_date: referenceDate,
      });

      if (error) {
        throw new Error(`Outlet ${outlet.name}: ${error.message}`);
      }

      return extractRows<StrictRecapRow>(data);
    }),
  );

  const streakByEmployeeId = new Map(streaks.map((row) => [row.employee_id, row]));
  const aggregateByEmployeeId = new Map<string, SiteLeaderboardRpcRow>();

  for (const employee of employees) {
    const streak = streakByEmployeeId.get(employee.id);
    aggregateByEmployeeId.set(employee.id, {
      employee_id: employee.id,
      employee_name: employee.name,
      employee_position: employee.position,
      home_outlet_id: employee.home_outlet_id,
      home_outlet_name: employee.home_outlet_id
        ? outletNameById.get(employee.home_outlet_id) ?? null
        : null,
      measured_days: 0,
      safe_days: 0,
      issue_days: 0,
      neutral_days: 0,
      overtime_only_days: 0,
      late_count: 0,
      absence_count: 0,
      short_work_count: 0,
      excess_break_count: 0,
      overtime_count: 0,
      unresolved_count: 0,
      current_streak: streak?.current_streak ?? 0,
      longest_streak: streak?.longest_streak ?? 0,
    });
  }

  for (const row of recapGroups.flat()) {
    const aggregate = aggregateByEmployeeId.get(row.employee_id);
    if (!aggregate) continue;

    const signals = new Set((row.detail_signals ?? []).filter(Boolean));
    const hasIssue =
      signals.has('late') ||
      signals.has('short_work') ||
      signals.has('excess_break') ||
      signals.has('absence') ||
      signals.has('belum_absen_pulang') ||
      row.primary_status === 'absence' ||
      row.primary_status === 'belum_absen_pulang' ||
      row.attendance_status === 'tidak_hadir';
    const hasOvertime =
      signals.has('overtime') || row.primary_status === 'overtime';
    const isSafe =
      row.attendance_status === 'hadir' &&
      row.logical_day_complete !== false &&
      !hasIssue &&
      !hasOvertime;

    aggregate.measured_days = asCount(aggregate.measured_days) + 1;

    if (signals.has('late')) aggregate.late_count = asCount(aggregate.late_count) + 1;
    if (
      signals.has('absence') ||
      row.primary_status === 'absence' ||
      row.attendance_status === 'tidak_hadir'
    ) {
      aggregate.absence_count = asCount(aggregate.absence_count) + 1;
    }
    if (signals.has('short_work')) {
      aggregate.short_work_count = asCount(aggregate.short_work_count) + 1;
    }
    if (signals.has('excess_break')) {
      aggregate.excess_break_count = asCount(aggregate.excess_break_count) + 1;
    }
    if (hasOvertime) {
      aggregate.overtime_count = asCount(aggregate.overtime_count) + 1;
    }
    if (signals.has('belum_absen_pulang') || row.primary_status === 'belum_absen_pulang') {
      aggregate.unresolved_count = asCount(aggregate.unresolved_count) + 1;
    }

    if (isSafe) {
      aggregate.safe_days = asCount(aggregate.safe_days) + 1;
    } else if (hasIssue) {
      aggregate.issue_days = asCount(aggregate.issue_days) + 1;
    } else if (hasOvertime) {
      aggregate.overtime_only_days = asCount(aggregate.overtime_only_days) + 1;
    } else {
      aggregate.neutral_days = asCount(aggregate.neutral_days) + 1;
    }
  }

  return Array.from(aggregateByEmployeeId.values());
}

function buildLeaderboardModel(
  rows: SiteLeaderboardRpcRow[],
  referenceDate: string,
  source: LeaderboardSource,
): SiteLeaderboardModel {
  const entries = rows
    .map((row) => normalizeLeaderboardRow(row))
    .sort(compareLeaderboardEntries)
    .map((entry, index) => ({
      ...entry,
      rank: index + 1,
    }));
  const ratedEntries = entries.filter((entry) => entry.measuredDays > 0);

  return {
    referenceDate,
    monthLabel: formatMonthLabel(referenceDate),
    source,
    summary: {
      employeeCount: entries.length,
      ratedEmployeeCount: ratedEntries.length,
      averageScore: ratedEntries.length > 0
        ? Math.round(
            ratedEntries.reduce((sum, entry) => sum + entry.score, 0) /
              ratedEntries.length,
          )
        : 0,
      topScore: entries[0]?.score ?? 0,
      bestStreak: entries.reduce(
        (best, entry) => Math.max(best, entry.currentStreak),
        0,
      ),
      totalIssueDays: entries.reduce((sum, entry) => sum + entry.issueDays, 0),
    },
    entries,
  };
}

function normalizeLeaderboardRow(row: SiteLeaderboardRpcRow): LeaderboardEntry {
  const measuredDays = asCount(row.measured_days);
  const safeDays = asCount(row.safe_days);
  const issueDays = asCount(row.issue_days);
  const neutralDays = asCount(row.neutral_days);
  const overtimeOnlyDays = asCount(row.overtime_only_days);
  const lateCount = asCount(row.late_count);
  const absenceCount = asCount(row.absence_count);
  const shortWorkCount = asCount(row.short_work_count);
  const excessBreakCount = asCount(row.excess_break_count);
  const overtimeCount = asCount(row.overtime_count);
  const unresolvedCount = asCount(row.unresolved_count);
  const currentStreak = asCount(row.current_streak);
  const longestStreak = asCount(row.longest_streak);
  const score = scoreEmployee({
    measuredDays,
    safeDays,
    neutralDays,
    overtimeOnlyDays,
    lateCount,
    absenceCount,
    shortWorkCount,
    excessBreakCount,
    unresolvedCount,
    currentStreak,
    longestStreak,
  });

  return {
    rank: 0,
    employeeId: row.employee_id,
    employeeName: row.employee_name,
    position: row.employee_position ?? null,
    homeOutletName: row.home_outlet_name ?? null,
    measuredDays,
    safeDays,
    issueDays,
    neutralDays,
    overtimeOnlyDays,
    lateCount,
    absenceCount,
    shortWorkCount,
    excessBreakCount,
    overtimeCount,
    unresolvedCount,
    totalIssues:
      lateCount + absenceCount + shortWorkCount + excessBreakCount + unresolvedCount,
    currentStreak,
    longestStreak,
    score,
    scoreLabel: resolveScoreLabel(score, measuredDays),
    scoreTone: resolveScoreTone(score, measuredDays),
    insight: buildInsightLabel({
      measuredDays,
      safeDays,
      lateCount,
      absenceCount,
      shortWorkCount,
      excessBreakCount,
      overtimeOnlyDays,
      unresolvedCount,
      currentStreak,
    }),
  };
}

function scoreEmployee(input: {
  measuredDays: number;
  safeDays: number;
  neutralDays: number;
  overtimeOnlyDays: number;
  lateCount: number;
  absenceCount: number;
  shortWorkCount: number;
  excessBreakCount: number;
  unresolvedCount: number;
  currentStreak: number;
  longestStreak: number;
}) {
  if (input.measuredDays === 0) return 0;

  let score = 52;
  score += Math.min(input.safeDays * 2.6, 28);
  score += Math.min(input.neutralDays * 0.8, 6);
  score += Math.min(input.currentStreak * 1.5, 18);
  score += Math.min(input.longestStreak * 0.25, 8);
  score -= input.lateCount * 4;
  score -= input.shortWorkCount * 5;
  score -= input.excessBreakCount * 4;
  score -= input.absenceCount * 12;
  score -= input.unresolvedCount * 8;
  score -= input.overtimeOnlyDays * 1.5;

  return clampScore(Math.round(score));
}

function buildInsightLabel(input: {
  measuredDays: number;
  safeDays: number;
  lateCount: number;
  absenceCount: number;
  shortWorkCount: number;
  excessBreakCount: number;
  overtimeOnlyDays: number;
  unresolvedCount: number;
  currentStreak: number;
}) {
  if (input.measuredDays === 0) {
    return 'Belum ada data penilaian bulan ini.';
  }
  if (
    input.absenceCount === 0 &&
    input.unresolvedCount === 0 &&
    input.lateCount === 0 &&
    input.shortWorkCount === 0 &&
    input.excessBreakCount === 0 &&
    input.overtimeOnlyDays === 0
  ) {
    return `Konsisten aman ${input.safeDays} hari dengan streak ${input.currentStreak} hari.`;
  }
  if (input.absenceCount > 0) return `${input.absenceCount} hari tidak hadir masih dominan.`;
  if (input.unresolvedCount > 0) {
    return `${input.unresolvedCount} hari belum absen pulang perlu ditutup rapi.`;
  }
  if (input.lateCount > 0) return `${input.lateCount} kali melewati cutoff bulan ini.`;
  if (input.shortWorkCount > 0) return `${input.shortWorkCount} hari kurang jam kerja.`;
  if (input.excessBreakCount > 0) return `${input.excessBreakCount} hari istirahat berlebih.`;
  if (input.overtimeOnlyDays > 0) {
    return `${input.overtimeOnlyDays} hari overtime tercatat sebagai insight beban kerja.`;
  }
  return 'Performa masih bergerak dan perlu dipantau.';
}

function resolveScoreTone(score: number, measuredDays: number): ScoreTone {
  if (measuredDays === 0) return 'unrated';
  if (score >= 85) return 'excellent';
  if (score >= 72) return 'steady';
  if (score >= 55) return 'warning';
  return 'critical';
}

function resolveScoreLabel(score: number, measuredDays: number) {
  if (measuredDays === 0) return 'Belum dinilai';
  if (score >= 85) return 'Sangat stabil';
  if (score >= 72) return 'Stabil';
  if (score >= 55) return 'Perlu perhatian ringan';
  return 'Perlu perhatian';
}

function compareLeaderboardEntries(left: LeaderboardEntry, right: LeaderboardEntry) {
  if (right.score !== left.score) return right.score - left.score;
  if (right.currentStreak !== left.currentStreak) {
    return right.currentStreak - left.currentStreak;
  }
  if (right.safeDays !== left.safeDays) return right.safeDays - left.safeDays;
  if (right.measuredDays !== left.measuredDays) return right.measuredDays - left.measuredDays;
  return left.employeeName.localeCompare(right.employeeName, 'id-ID');
}

function buildLeaderboardErrorMessage(publicError: unknown, adminError: unknown) {
  const publicMessage = errorMessage(publicError);
  const adminMessage = errorMessage(adminError);

  if (isMissingRpcError(publicMessage) && !adminMessage) {
    return 'Data peringkat belum tersedia dari database leaderboard. Terapkan migrasi leaderboard lalu muat ulang halaman ini.';
  }
  if (isMissingRpcError(publicMessage) && adminMessage) {
    return 'Loader publik belum tersedia dan fallback server-side juga gagal. Periksa migrasi SQL leaderboard atau konfigurasi server Supabase.';
  }
  if (publicMessage?.toLowerCase().includes('permission')) {
    return 'Akses data leaderboard ditolak oleh database. Periksa grant function atau kebijakan akses yang dipakai route ini.';
  }
  return 'Terjadi kesalahan saat memuat data peringkat. Muat ulang halaman atau coba beberapa saat lagi.';
}

function isMissingRpcError(message: string | null) {
  if (!message) return false;
  const normalized = message.toLowerCase();
  return normalized.includes('get_site_leaderboard') &&
    (normalized.includes('function') || normalized.includes('find the function'));
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : null;
}

function formatMonthLabel(referenceDate: string) {
  const date = new Date(`${referenceDate}T00:00:00`);
  return new Intl.DateTimeFormat('id-ID', {
    month: 'long',
    year: 'numeric',
  }).format(date);
}

function deriveMonthStart(referenceDate: string) {
  return `${referenceDate.slice(0, 7)}-01`;
}

function clampScore(score: number) {
  return Math.max(0, Math.min(100, score));
}

function asCount(value: number | null | undefined) {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function extractRows<T>(raw: unknown): T[] {
  const unwrapped = unwrapData(raw);
  if (unwrapped == null) return [];
  if (Array.isArray(unwrapped)) return unwrapped.map(asRecord) as T[];
  if (typeof unwrapped === 'object') {
    const record = asRecord(unwrapped);
    const nested = record.rows ?? record.data ?? record.result;
    if (Array.isArray(nested)) return nested.map(asRecord) as T[];
    return [record as T];
  }
  throw new Error(`Unexpected response shape: ${typeof unwrapped}`);
}

function unwrapData(raw: unknown): unknown {
  let current = raw;
  while (
    current &&
    typeof current === 'object' &&
    'data' in current &&
    (current as Record<string, unknown>).data !== current
  ) {
    current = (current as Record<string, unknown>).data;
  }
  return current;
}

function asRecord(value: unknown) {
  if (!value || typeof value !== 'object') {
    throw new Error(`Expected response row object, received ${typeof value}`);
  }
  return value as Record<string, unknown>;
}
