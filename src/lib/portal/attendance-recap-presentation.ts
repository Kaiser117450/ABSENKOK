// ---------------------------------------------------------------------------
// Portal recap presentation helper
//
// Single source of meaning for recap attendance statuses on the portal side.
// Mirrors the exception taxonomy documented in:
//   sql/phase_42_portal_attendance_recap_20260323.sql (with_status derivation)
//
// Follow-up gaps (prior-day unresolved):    belum_pulang, tidak_hadir
// Current-day in-progress (informational): sedang_bekerja, belum_masuk
// Resolved outcomes (no follow-up needed): hadir, sakit, izin, libur
//
// Phase 44 UI components should import from here instead of re-deriving the
// same follow-up semantics inline.
// ---------------------------------------------------------------------------

import type { AttendanceStatus, PortalRecapDay } from './attendance-recap';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Visual tone family for a recap day card.
 *
 * - `success`  — positive resolved outcome (hadir)
 * - `neutral`  — resolved or no-action (izin, sakit, libur, null)
 * - `accent`   — current-day in-progress, informational (sedang_bekerja, belum_masuk)
 * - `warning`  — prior-day follow-up gap needs review (belum_pulang, tidak_hadir)
 * - `danger`   — reserved for future escalation states
 */
export type RecapDayTone = 'neutral' | 'success' | 'warning' | 'danger' | 'accent';

/**
 * Presentation data for one recap day status.
 *
 * Created by `getRecapDayPresentation(status)` — never derive these values
 * directly in components.
 */
export type RecapDayPresentation = {
  /** Short employee-facing status label (e.g. "Hadir", "Belum Pulang"). */
  label: string;
  /** Tone family used by UI components for colour and icon selection. */
  tone: RecapDayTone;
  /**
   * True when this day is a prior-day unresolved gap requiring follow-up.
   * Only `belum_pulang` and `tidak_hadir` return true.
   * Current-day in-progress states (`sedang_bekerja`, `belum_masuk`) return false.
   */
  needsFollowUp: boolean;
  /**
   * Short action-oriented label shown when `needsFollowUp` is true.
   * Null for non-follow-up statuses.
   */
  followUpLabel: string | null;
  /**
   * Optional one-sentence explanation for exceptional days.
   * Null for normal resolved outcomes that need no further description.
   */
  supportingCopy: string | null;
};

// ---------------------------------------------------------------------------
// Presentation map
// ---------------------------------------------------------------------------

const PRESENTATION_MAP: Record<NonNullable<AttendanceStatus>, RecapDayPresentation> = {
  hadir: {
    label: 'Hadir',
    tone: 'success',
    needsFollowUp: false,
    followUpLabel: null,
    supportingCopy: null,
  },
  sakit: {
    label: 'Sakit',
    tone: 'neutral',
    needsFollowUp: false,
    followUpLabel: null,
    supportingCopy: 'Karyawan tercatat sakit pada hari ini.',
  },
  izin: {
    label: 'Izin',
    tone: 'neutral',
    needsFollowUp: false,
    followUpLabel: null,
    supportingCopy: 'Karyawan tercatat izin pada hari ini.',
  },
  libur: {
    label: 'Libur',
    tone: 'neutral',
    needsFollowUp: false,
    followUpLabel: null,
    supportingCopy: null,
  },
  // ── Follow-up gaps ────────────────────────────────────────────────────────
  belum_pulang: {
    label: 'Belum Pulang',
    tone: 'warning',
    needsFollowUp: true,
    followUpLabel: 'Absensi pulang belum tercatat',
    supportingCopy:
      'Karyawan tercatat masuk namun tidak ada scan pulang pada hari ini. Perlu ditindaklanjuti.',
  },
  tidak_hadir: {
    label: 'Tidak Hadir',
    tone: 'warning',
    needsFollowUp: true,
    followUpLabel: 'Tidak ada kehadiran tercatat',
    supportingCopy:
      'Karyawan terjadwal masuk namun tidak ada scan kehadiran sama sekali pada hari ini. Perlu ditindaklanjuti.',
  },
  // ── Current-day informational states — not follow-up ─────────────────────
  sedang_bekerja: {
    label: 'Sedang Bekerja',
    tone: 'accent',
    needsFollowUp: false,
    followUpLabel: null,
    supportingCopy: 'Karyawan sedang dalam jam kerja. Absensi pulang belum tercatat hari ini.',
  },
  belum_masuk: {
    label: 'Belum Masuk',
    tone: 'accent',
    needsFollowUp: false,
    followUpLabel: null,
    supportingCopy: 'Karyawan terjadwal masuk hari ini namun belum melakukan scan absensi.',
  },
};

/** Fallback used when status is null (unscheduled day with no attendance). */
const NULL_PRESENTATION: RecapDayPresentation = {
  label: '—',
  tone: 'neutral',
  needsFollowUp: false,
  followUpLabel: null,
  supportingCopy: null,
};

// ---------------------------------------------------------------------------
// Public helpers
// ---------------------------------------------------------------------------

/**
 * Return the employee-facing presentation data for a given `AttendanceStatus`.
 *
 * Always returns a valid `RecapDayPresentation` — null status maps to a
 * neutral fallback so callers do not need null-guards.
 */
export function getRecapDayPresentation(status: AttendanceStatus): RecapDayPresentation {
  if (status === null) return NULL_PRESENTATION;
  return PRESENTATION_MAP[status] ?? NULL_PRESENTATION;
}

/**
 * Return true when the status is a prior-day follow-up gap.
 *
 * - `belum_pulang` → true (masuk recorded, pulang missing)
 * - `tidak_hadir`  → true (scheduled workday, no scans at all)
 * - All other statuses including `sedang_bekerja` and `belum_masuk` → false
 */
export function isFollowUpStatus(status: AttendanceStatus): boolean {
  return status === 'belum_pulang' || status === 'tidak_hadir';
}

/**
 * Count the number of days in a recap day array that need follow-up.
 *
 * Intended for page-level framing copy such as "3 hari perlu ditindaklanjuti".
 * Operates on `PortalRecapDay[]` — no second query required.
 */
export function countFollowUpDays(days: PortalRecapDay[]): number {
  return days.filter((d) => isFollowUpStatus(d.attendanceStatus)).length;
}
