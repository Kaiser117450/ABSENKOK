import type { AstroGlobal } from 'astro';
import { createSupabaseServerClient } from '../supabase/server';
import { resolvePortalEmployee } from './employee';
import type { PortalEmployee } from './employee';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type PortalAttendanceStatus =
  | 'hadir'
  | 'hadir_tanpa_jadwal'
  | 'sakit'
  | 'izin'
  | 'cuti'
  | 'libur'
  | 'belum_masuk'
  | 'tidak_hadir'
  | null;

export interface PortalScheduleEntry {
  logicalDate: string;
  outletId: string | null;
  outletName: string | null;
  shiftBandLabel: string | null;
  requiredWorkMinutes: number | null;
  requiredHoursLabel: string | null;
  workedMinutes: number | null;
  workedDisplayLabel: string | null;
  remainingWorkMinutes: number | null;
  comparisonDisplayLabel: string | null;
  attendanceStatus: PortalAttendanceStatus;
  strictPrimaryStatus: string | null;
  strictOutcomeLabel: string | null;
  shortTags: string[];
  helperCopy: string | null;
  isInProgress: boolean;
  isCompatibilityMode: boolean;
  isDayOff: boolean;
  notes: string | null;
}

export interface PortalScheduleModel {
  employee: PortalEmployee;
  referenceDate: string;
  todayAssignment: PortalScheduleEntry | null;
  weekAssignments: PortalScheduleEntry[];
  nextWeekAssignments: PortalScheduleEntry[];
  upcomingAssignments: PortalScheduleEntry[];
}

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

export function getPortalReferenceDate(): string {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'Asia/Makassar',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(now);
}

// ---------------------------------------------------------------------------
// Raw RPC row contract
// ---------------------------------------------------------------------------

interface PortalScheduleParityRow {
  logical_date: string;
  outlet_id: string | null;
  outlet_name: string | null;
  shift_band_label: string | null;
  required_work_minutes: number | null;
  worked_minutes: number | null;
  remaining_work_minutes: number | null;
  attendance_status: string | null;
  strict_primary_status: string | null;
  strict_outcome_label: string | null;
  short_tags: string[] | null;
  helper_copy: string | null;
  is_in_progress: boolean | null;
  is_compatibility_mode: boolean | null;
  is_day_off: boolean | null;
  notes: string | null;
}

// ---------------------------------------------------------------------------
// Shared formatting helpers
// ---------------------------------------------------------------------------

function formatMinutes(minutes: number | null): string | null {
  if (minutes == null) return null;
  const safeMinutes = Math.max(minutes, 0);
  const hours = Math.floor(safeMinutes / 60);
  const remainder = safeMinutes % 60;

  if (hours === 0) return `${remainder}m`;
  if (remainder === 0) return `${hours}j`;
  return `${hours}j ${remainder}m`;
}

function normalizeAttendanceStatus(
  status: string | null,
): PortalAttendanceStatus {
  switch (status) {
    case 'hadir':
    case 'hadir_tanpa_jadwal':
    case 'sakit':
    case 'izin':
    case 'cuti':
    case 'libur':
    case 'belum_masuk':
    case 'tidak_hadir':
      return status;
    default:
      return null;
  }
}

function normalizeShortTags(shortTags: string[] | null | undefined): string[] {
  if (!Array.isArray(shortTags)) {
    return [];
  }

  return shortTags.filter((tag): tag is string => typeof tag === 'string');
}

function formatRequiredHoursLabel(requiredWorkMinutes: number | null): string | null {
  const value = formatMinutes(requiredWorkMinutes);
  return value ? `Wajib ${value}` : null;
}

function formatWorkedDisplayLabel(
  workedMinutes: number | null,
  isInProgress: boolean,
): string | null {
  const worked = formatMinutes(workedMinutes);
  if (!worked) return null;

  return `${isInProgress ? 'Sudah berjalan' : 'Tercatat'} ${worked}`;
}

function formatComparisonDisplayLabel(
  requiredWorkMinutes: number | null,
  workedMinutes: number | null,
  remainingWorkMinutes: number | null,
  isInProgress: boolean,
): string | null {
  if (requiredWorkMinutes == null) {
    return null;
  }

  if (isInProgress) {
    const remaining = formatMinutes(
      remainingWorkMinutes ?? Math.max(requiredWorkMinutes - (workedMinutes ?? 0), 0),
    );
    return remaining ? `Sisa ${remaining}` : null;
  }

  if (workedMinutes == null) {
    return null;
  }

  const delta = workedMinutes - requiredWorkMinutes;
  if (delta > 0) {
    const formatted = formatMinutes(delta);
    return formatted ? `Lebih ${formatted} dari target` : null;
  }

  if (delta < 0) {
    const formatted = formatMinutes(Math.abs(delta));
    return formatted ? `Kurang ${formatted} dari target` : null;
  }

  return 'Sesuai target';
}

function defaultOutcomeLabel(
  strictPrimaryStatus: string | null,
  attendanceStatus: PortalAttendanceStatus,
  isDayOff: boolean,
): string | null {
  switch (strictPrimaryStatus) {
    case 'late':
      return 'Terlambat';
    case 'short_work':
      return 'Kurang jam kerja';
    case 'excess_break':
      return 'Istirahat berlebih';
    case 'overtime':
      return 'Lembur';
    case 'absence':
      return 'Tidak hadir';
    case 'exempt_manager':
      return 'Manager exempt';
    case 'hadir_tanpa_jadwal':
      return 'Hadir tanpa jadwal';
    case 'belum_absen_pulang':
      return 'Belum absen pulang';
    case 'active_incomplete':
      return 'Sedang berjalan';
    case 'belum_masuk':
      return 'Belum masuk';
    default:
      break;
  }

  if (isDayOff || attendanceStatus === 'libur') return 'Libur';
  if (attendanceStatus === 'sakit') return 'Sakit';
  if (attendanceStatus === 'izin') return 'Izin';
  if (attendanceStatus === 'cuti') return 'Cuti';
  if (attendanceStatus === 'hadir_tanpa_jadwal') return 'Hadir tanpa jadwal';

  return null;
}

function defaultHelperCopy(
  strictPrimaryStatus: string | null,
  attendanceStatus: PortalAttendanceStatus,
  workedMinutes: number | null,
  requiredWorkMinutes: number | null,
  isInProgress: boolean,
): string | null {
  switch (strictPrimaryStatus) {
    case 'late':
      return 'Jam masuk hari ini tercatat melewati batas shift.';
    case 'short_work':
      return 'Jam kerja yang tercatat masih di bawah target kontrak.';
    case 'excess_break':
      return 'Total istirahat hari ini melewati batas yang diizinkan.';
    case 'overtime':
      return 'Jam kerja hari ini melebihi target kontrak.';
    case 'absence':
      return 'Tidak ada scan pada hari kerja yang sudah selesai.';
    case 'exempt_manager':
      return 'Kehadiran tetap tercatat, tetapi posisi manajerial tidak dikenai penalti merah.';
    case 'hadir_tanpa_jadwal':
      return 'Kehadiran tetap tercatat walau jadwal belum tersedia untuk hari ini.';
    case 'belum_absen_pulang':
      return 'Hari kerja sudah selesai, tetapi absensi pulang belum tercatat.';
    case 'active_incomplete':
      return 'Hari kerja masih berjalan. Target dan sisa waktu akan diperbarui sampai chain selesai.';
    case 'belum_masuk':
      return 'Hari kerja hari ini belum memiliki scan masuk.';
    default:
      break;
  }

  if (attendanceStatus === 'sakit') return 'Kehadiran hari ini ditandai sakit.';
  if (attendanceStatus === 'izin') return 'Kehadiran hari ini ditandai izin.';
  if (attendanceStatus === 'cuti') return 'Kehadiran hari ini ditandai cuti.';
  if (attendanceStatus === 'libur') return 'Hari ini tidak memiliki target kerja.';

  if (
    !isInProgress &&
    workedMinutes != null &&
    requiredWorkMinutes != null &&
    workedMinutes >= requiredWorkMinutes
  ) {
    return 'Target kerja hari ini sudah terpenuhi.';
  }

  return null;
}

// ---------------------------------------------------------------------------
// Row normalizer
// ---------------------------------------------------------------------------

function normalizeRow(row: PortalScheduleParityRow): PortalScheduleEntry {
  const attendanceStatus = normalizeAttendanceStatus(row.attendance_status);
  const strictPrimaryStatus = row.strict_primary_status ?? null;
  const requiredWorkMinutes =
    typeof row.required_work_minutes === 'number'
      ? row.required_work_minutes
      : null;
  const workedMinutes =
    typeof row.worked_minutes === 'number' ? row.worked_minutes : null;
  const remainingWorkMinutes =
    typeof row.remaining_work_minutes === 'number'
      ? row.remaining_work_minutes
      : null;
  const isInProgress = row.is_in_progress ?? false;
  const isDayOff = row.is_day_off ?? attendanceStatus === 'libur';

  return {
    logicalDate: row.logical_date,
    outletId: row.outlet_id ?? null,
    outletName: row.outlet_name ?? null,
    shiftBandLabel: row.shift_band_label ?? null,
    requiredWorkMinutes,
    requiredHoursLabel: formatRequiredHoursLabel(requiredWorkMinutes),
    workedMinutes,
    workedDisplayLabel: formatWorkedDisplayLabel(workedMinutes, isInProgress),
    remainingWorkMinutes,
    comparisonDisplayLabel: formatComparisonDisplayLabel(
      requiredWorkMinutes,
      workedMinutes,
      remainingWorkMinutes,
      isInProgress,
    ),
    attendanceStatus,
    strictPrimaryStatus,
    strictOutcomeLabel:
      row.strict_outcome_label ??
      defaultOutcomeLabel(strictPrimaryStatus, attendanceStatus, isDayOff),
    shortTags: normalizeShortTags(row.short_tags),
    helperCopy:
      row.helper_copy ??
      defaultHelperCopy(
        strictPrimaryStatus,
        attendanceStatus,
        workedMinutes,
        requiredWorkMinutes,
        isInProgress,
      ),
    isInProgress,
    isCompatibilityMode: row.is_compatibility_mode ?? false,
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

function shiftIsoDate(date: string, offsetDays: number): string {
  const shifted = new Date(`${date}T00:00:00Z`);
  shifted.setUTCDate(shifted.getUTCDate() + offsetDays);
  return shifted.toISOString().slice(0, 10);
}

// ---------------------------------------------------------------------------
// Main helper
// ---------------------------------------------------------------------------

export async function loadPortalSchedule(
  Astro: AstroGlobal,
): Promise<PortalScheduleResult> {
  const employeeResult = await resolvePortalEmployee(Astro);
  if (!employeeResult.ok) {
    return {
      ok: false,
      reason: employeeResult.reason,
      message: employeeResult.message,
    };
  }

  const employee = employeeResult.employee;
  const referenceDate = getPortalReferenceDate();
  const { weekStart, weekEnd } = getPortalWeekRange(referenceDate);
  const nextWeekStart = shiftIsoDate(weekEnd, 1);
  const nextWeekEnd = shiftIsoDate(nextWeekStart, 6);

  const supabase = createSupabaseServerClient(
    Astro.request.headers.get('cookie') ?? '',
    Astro.response.headers,
  );

  const { data, error } = await supabase.rpc(
    'get_portal_schedule_parity_overview',
    {
      reference_date: referenceDate,
    },
  );

  if (error) {
    return {
      ok: false,
      reason: 'rpc_error',
      message: error.message,
    };
  }

  const rows = (Array.isArray(data) ? data : [])
    .map((row) => normalizeRow(row as PortalScheduleParityRow))
    .sort((left, right) => left.logicalDate.localeCompare(right.logicalDate));

  const todayAssignment =
    rows.find((entry) => entry.logicalDate === referenceDate) ?? null;
  const weekAssignments = rows.filter(
    (entry) => entry.logicalDate >= weekStart && entry.logicalDate <= weekEnd,
  );
  const nextWeekAssignments = rows.filter(
    (entry) =>
      entry.logicalDate >= nextWeekStart && entry.logicalDate <= nextWeekEnd,
  );
  const upcomingAssignments = rows.filter(
    (entry) => entry.logicalDate > referenceDate,
  );

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
