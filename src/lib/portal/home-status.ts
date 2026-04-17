// ---------------------------------------------------------------------------
// Portal home-status derivation
//
// Converts the already-fetched Phase 42 recap dataset into the single
// current-status model consumed by the portal home page — current phase,
// realtime timer anchors (as absolute +08:00 instants), shift start and
// late cutoff, and a small set of day totals.
//
// Taxonomy alignment:
//   Uses the same attendance statuses emitted by
//   sql/phase_42_portal_attendance_recap_20260323.sql and mirrored in
//   src/lib/portal/attendance-recap.ts — this file never invents a new
//   status name. It only maps the existing row into a phase suitable
//   for presentation on the home page.
//
// Timezone contract:
//   The recap RPC returns WITA (Asia/Makassar, UTC+8) wall-clock timestamps
//   as naive ISO strings ("YYYY-MM-DDTHH:MM:SS[.ffffff]", no offset).
//   We append "+08:00" to promote them to absolute instants so browser
//   `Date.parse()` always yields the same moment regardless of the
//   client's local timezone.
// ---------------------------------------------------------------------------
import type { AttendanceStatus, PortalAttendanceRecapModel, PortalRecapDay } from './attendance-recap';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * The home-page lifecycle phase for today.
 *
 * - `belum_masuk`      — scheduled workday, not yet clocked in (before or after shift start).
 * - `sedang_bekerja`   — clocked in, currently working (no active break).
 * - `istirahat`        — on break (break scan after last kembali/masuk).
 * - `selesai`          — clocked out for today.
 * - `libur`            — scheduled day-off.
 * - `sakit`            — sick-leave scan logged for today.
 * - `izin`             — permitted-absence scan logged for today.
 * - `belum_pulang`     — prior-day unresolved: masuk recorded, pulang missing.
 * - `tidak_hadir`      — prior-day scheduled workday with no scan at all.
 * - `tidak_ada_jadwal` — no schedule for today and no attendance scans either.
 */
export type PortalHomePhase =
  | 'belum_masuk'
  | 'sedang_bekerja'
  | 'istirahat'
  | 'selesai'
  | 'libur'
  | 'sakit'
  | 'izin'
  | 'belum_pulang'
  | 'tidak_hadir'
  | 'tidak_ada_jadwal';

export type PortalHomeTone = 'neutral' | 'accent' | 'success' | 'warning';

/**
 * Everything the home-page current-status card needs in a single object.
 *
 * All timestamps are absolute instants encoded as ISO strings with explicit
 * "+08:00" offset. Callers can pass them to client-side `Date.parse()`
 * without worrying about the browser's local timezone.
 */
export interface PortalHomeStatus {
  phase: PortalHomePhase;
  label: string;
  tone: PortalHomeTone;

  /** Human-readable positional context ("Karyawan · Outlet Pusat"). */
  identityLine: string;
  positionLabel: string | null;
  outletName: string | null;
  shiftName: string | null;

  /** Shift start as an absolute instant (ISO + "+08:00"), null when no schedule. */
  shiftStartAt: string | null;
  /** Shift end as an absolute instant, null when no schedule. */
  shiftEndAt: string | null;
  /** Late cutoff = shiftStart + lateGraceMinutes, null when no schedule. */
  lateCutoffAt: string | null;
  /** Late-grace window in minutes (default 15). */
  lateGraceMinutes: number;
  /** True when masuk already recorded and it occurred after the late cutoff. */
  isLate: boolean;

  /** Anchor for the realtime "sedang bekerja" timer. Null unless phase === sedang_bekerja. */
  workStartedAt: string | null;
  /** Anchor for the realtime "istirahat" timer. Null unless phase === istirahat. */
  breakStartedAt: string | null;

  /** Day totals — all timestamps promoted to absolute instants. */
  firstMasukAt: string | null;
  firstBreakAt: string | null;
  lastKembaliAt: string | null;
  lastPulangAt: string | null;
  totalBreakMinutes: number;
  workMinutes: number | null;

  /** ISO instant (UTC "Z") captured when the server rendered this status. */
  serverRenderedAt: string;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/**
 * Default late-grace window in minutes. Chosen to match the implicit
 * tolerance used across the kiosk/admin surfaces. A future phase may wire
 * a per-shift late cutoff from `shift_slot` into the recap RPC and this
 * helper will pick it up through an optional override argument.
 */
export const PORTAL_LATE_GRACE_MINUTES = 15;

const WITA_OFFSET = '+08:00';

// ---------------------------------------------------------------------------
// WITA timestamp helpers
// ---------------------------------------------------------------------------

/**
 * Promote a WITA naive ISO string to an absolute instant ISO string.
 *
 * Input shapes produced by the recap RPC:
 *   "2026-04-17T07:30:00"
 *   "2026-04-17T07:30:00.123456"
 *
 * We trim sub-millisecond precision (browsers only accept 3-digit ms) and
 * append "+08:00". Returns null when the input is null or empty.
 */
export function witaNaiveToInstant(value: string | null): string | null {
  if (!value) return null;
  const trimmed = value.replace(/(\.\d{3})\d+$/, '$1');
  return `${trimmed}${WITA_OFFSET}`;
}

/**
 * Build an absolute instant from a WITA calendar date + hour/minute pair.
 * Used for shift start/end anchors which come as integers from the RPC.
 */
export function witaDatePartsToInstant(
  isoDate: string,
  hour: number,
  minute: number,
  addDays = 0,
): string {
  // Shift the date by addDays when the shift runs past midnight.
  const base = new Date(`${isoDate}T00:00:00${WITA_OFFSET}`);
  base.setUTCDate(base.getUTCDate() + addDays);
  const yyyy = base.getUTCFullYear();
  const mm = String(base.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(base.getUTCDate()).padStart(2, '0');
  const hh = String(hour).padStart(2, '0');
  const mi = String(minute).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}T${hh}:${mi}:00${WITA_OFFSET}`;
}

/**
 * Add `minutes` to an ISO instant string, preserving the "+08:00" offset.
 * Returns null when input is null.
 */
export function addMinutesToInstant(instant: string | null, minutes: number): string | null {
  if (!instant) return null;
  const ts = Date.parse(instant);
  if (Number.isNaN(ts)) return null;
  const shifted = new Date(ts + minutes * 60_000);
  // Emit as WITA with +08:00 for visual consistency.
  const parts = new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'Asia/Makassar',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).formatToParts(shifted);
  const byType: Record<string, string> = {};
  for (const p of parts) byType[p.type] = p.value;
  return `${byType.year}-${byType.month}-${byType.day}T${byType.hour}:${byType.minute}:${byType.second}${WITA_OFFSET}`;
}

// ---------------------------------------------------------------------------
// Phase derivation
// ---------------------------------------------------------------------------

/**
 * Map today's status + scan fingerprint to a display phase.
 *
 * Key subtleties:
 * - `sedang_bekerja` from SQL may split into `istirahat` here when the last
 *   break scan is more recent than the last kembali scan.
 * - Missing-schedule + some-scan days come back as `hadir` from SQL; we map
 *   those into `sedang_bekerja` / `selesai` based on pulang presence.
 * - Prior-day gaps `belum_pulang` and `tidak_hadir` surface here only when
 *   the caller passes a non-current-day row (e.g. there is no row for today
 *   but a yesterday row is unresolved). The caller decides whether to pass
 *   the current-day row or the most recent recap row.
 */
function derivePhase(day: PortalRecapDay | null, referenceDate: string): PortalHomePhase {
  if (!day) {
    return 'tidak_ada_jadwal';
  }

  // Prior-day follow-up gaps — keep the SQL semantics verbatim.
  if (day.logicalDate !== referenceDate) {
    switch (day.attendanceStatus) {
      case 'belum_pulang':
        return 'belum_pulang';
      case 'tidak_hadir':
        return 'tidak_hadir';
      default:
        // Any other historical status means today is effectively quiet.
        return 'tidak_ada_jadwal';
    }
  }

  switch (day.attendanceStatus) {
    case 'libur':
      return 'libur';
    case 'sakit':
      return 'sakit';
    case 'izin':
      return 'izin';
    case 'hadir':
      // Unscheduled-but-scanned days may also land in 'hadir' — treat them
      // as either working or finished based on pulang presence.
      return day.lastPulangAt ? 'selesai' : 'sedang_bekerja';
    case 'sedang_bekerja':
      return isOnBreak(day) ? 'istirahat' : 'sedang_bekerja';
    case 'belum_masuk':
      return 'belum_masuk';
    case 'belum_pulang':
      // Edge case: SQL would normally return sedang_bekerja on the current
      // day, but defend against this branch anyway.
      return 'sedang_bekerja';
    case 'tidak_hadir':
      // Defensive — SQL suppresses this on the current day, but keep a path.
      return 'belum_masuk';
    default:
      return 'tidak_ada_jadwal';
  }
}

/** True when the most recent scan is a break that has not been closed by a kembali. */
function isOnBreak(day: PortalRecapDay): boolean {
  if (!day.firstBreakAt) return false;
  if (!day.lastKembaliAt) return true; // break without kembali
  return Date.parse(witaNaiveToInstant(day.firstBreakAt) ?? '') >
         Date.parse(witaNaiveToInstant(day.lastKembaliAt) ?? '');
}

// ---------------------------------------------------------------------------
// Phase presentation map
// ---------------------------------------------------------------------------

interface PhasePresentation {
  label: string;
  tone: PortalHomeTone;
}

const PHASE_PRESENTATION: Record<PortalHomePhase, PhasePresentation> = {
  belum_masuk:      { label: 'Belum Masuk',        tone: 'accent'  },
  sedang_bekerja:   { label: 'Sedang Bekerja',     tone: 'success' },
  istirahat:        { label: 'Istirahat',          tone: 'accent'  },
  selesai:          { label: 'Selesai Hari Ini',   tone: 'neutral' },
  libur:            { label: 'Libur',              tone: 'neutral' },
  sakit:            { label: 'Sakit',              tone: 'neutral' },
  izin:             { label: 'Izin',               tone: 'neutral' },
  belum_pulang:     { label: 'Belum Pulang Kemarin', tone: 'warning' },
  tidak_hadir:      { label: 'Tidak Hadir Kemarin', tone: 'warning' },
  tidak_ada_jadwal: { label: 'Tidak Ada Jadwal',   tone: 'neutral' },
};

// ---------------------------------------------------------------------------
// Identity line
// ---------------------------------------------------------------------------

function buildIdentityLine(position: string | null, outletName: string | null): string {
  const parts: string[] = [];
  if (position && position.trim().length > 0) parts.push(position.trim());
  if (outletName && outletName.trim().length > 0) parts.push(outletName.trim());
  return parts.length === 0 ? 'Karyawan Aktif' : parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Derive the portal home-status model from an already-loaded recap.
 *
 * The caller is responsible for selecting the recap row to focus on; by
 * default we pick today's row when it exists, else the most recent row
 * (lets prior-day follow-up gaps surface on the home page).
 *
 * @param recap           already-loaded recap model
 * @param lateGraceMinutes override the default late grace window
 */
export function derivePortalHomeStatus(
  recap: PortalAttendanceRecapModel,
  lateGraceMinutes: number = PORTAL_LATE_GRACE_MINUTES,
): PortalHomeStatus {
  const { referenceDate, days, employee } = recap;

  // Prefer today's row; fall back to the most recent row so follow-up gaps
  // from yesterday still surface with correct framing.
  const todayRow = days.find((d) => d.logicalDate === referenceDate) ?? null;
  const focusRow =
    todayRow ??
    days.find((d) =>
      d.attendanceStatus === 'belum_pulang' || d.attendanceStatus === 'tidak_hadir',
    ) ??
    null;

  const phase = derivePhase(focusRow, referenceDate);
  const presentation = PHASE_PRESENTATION[phase];

  // Shift anchors come from the focused row's schedule fields — they are
  // meaningful only when the row represents a scheduled day.
  let shiftStartAt: string | null = null;
  let shiftEndAt: string | null = null;
  if (focusRow && focusRow.hasSchedule && !focusRow.isDayOff) {
    shiftStartAt = witaDatePartsToInstant(
      focusRow.logicalDate,
      focusRow.startHour,
      focusRow.startMinute,
    );
    shiftEndAt = witaDatePartsToInstant(
      focusRow.logicalDate,
      focusRow.endHour,
      focusRow.endMinute,
      focusRow.endsNextDay ? 1 : 0,
    );
  }
  const lateCutoffAt = addMinutesToInstant(shiftStartAt, lateGraceMinutes);

  const firstMasukAt = focusRow ? witaNaiveToInstant(focusRow.firstMasukAt) : null;
  const firstBreakAt = focusRow ? witaNaiveToInstant(focusRow.firstBreakAt) : null;
  const lastKembaliAt = focusRow ? witaNaiveToInstant(focusRow.lastKembaliAt) : null;
  const lastPulangAt = focusRow ? witaNaiveToInstant(focusRow.lastPulangAt) : null;

  // Late flag: only meaningful when both a shift cutoff and a masuk scan exist.
  const isLate =
    !!lateCutoffAt &&
    !!firstMasukAt &&
    Date.parse(firstMasukAt) > Date.parse(lateCutoffAt);

  // Realtime anchors.
  const workStartedAt = phase === 'sedang_bekerja' ? firstMasukAt : null;
  const breakStartedAt = phase === 'istirahat' ? firstBreakAt : null;

  return {
    phase,
    label: presentation.label,
    tone: presentation.tone,
    identityLine: buildIdentityLine(employee.position, focusRow?.outletName ?? employee.home_outlet_name),
    positionLabel: employee.position,
    outletName: focusRow?.outletName ?? employee.home_outlet_name,
    shiftName: focusRow?.shiftName ?? null,
    shiftStartAt,
    shiftEndAt,
    lateCutoffAt,
    lateGraceMinutes,
    isLate,
    workStartedAt,
    breakStartedAt,
    firstMasukAt,
    firstBreakAt,
    lastKembaliAt,
    lastPulangAt,
    totalBreakMinutes: focusRow?.totalBreakMinutes ?? 0,
    workMinutes: focusRow?.workMinutes ?? null,
    serverRenderedAt: new Date().toISOString(),
  };
}

// ---------------------------------------------------------------------------
// Testing helpers — also usable from the inline browser script
// ---------------------------------------------------------------------------

/** Humanize elapsed milliseconds to "Hh MMm" or "MMm SSs" form. */
export function formatElapsed(ms: number): string {
  const totalSeconds = Math.max(0, Math.floor(ms / 1000));
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  if (hours > 0) {
    return `${hours}j ${String(minutes).padStart(2, '0')}m`;
  }
  return `${minutes}m ${String(seconds).padStart(2, '0')}d`;
}

/** Export the raw phase → presentation map for tests. */
export function phasePresentation(phase: PortalHomePhase): PhasePresentation {
  return PHASE_PRESENTATION[phase];
}

// Re-export AttendanceStatus for convenience so callers do not need to pull
// it from two different modules.
export type { AttendanceStatus };
