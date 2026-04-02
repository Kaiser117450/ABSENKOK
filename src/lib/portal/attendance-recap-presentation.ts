import type { PortalRecapDay } from './attendance-recap';

export type RecapDayTone =
  | 'neutral'
  | 'success'
  | 'warning'
  | 'danger'
  | 'accent';

export type RecapDayPresentation = {
  label: string;
  tone: RecapDayTone;
  needsFollowUp: boolean;
  followUpLabel: string | null;
  supportingCopy: string | null;
};

const NULL_PRESENTATION: RecapDayPresentation = {
  label: 'Tanpa jadwal',
  tone: 'neutral',
  needsFollowUp: false,
  followUpLabel: null,
  supportingCopy: null,
};

function defaultSupportingCopy(day: PortalRecapDay): string | null {
  if (day.helperCopy) {
    return day.helperCopy;
  }

  switch (day.strictPrimaryStatus) {
    case 'late':
      return 'Jam masuk hari tersebut tercatat melewati batas shift.';
    case 'short_work':
      return 'Jam kerja yang tercatat masih di bawah target kontrak.';
    case 'excess_break':
      return 'Total istirahat hari tersebut melewati batas yang diizinkan.';
    case 'overtime':
      return 'Jam kerja hari tersebut melebihi target kontrak.';
    case 'absence':
      return 'Tidak ada scan pada hari kerja yang sudah selesai.';
    case 'belum_absen_pulang':
      return 'Hari kerja sudah selesai, tetapi absensi pulang belum tercatat.';
    case 'active_incomplete':
      return 'Hari kerja masih berjalan. Target dan sisa waktu akan diperbarui sampai chain selesai.';
    case 'exempt_manager':
      return 'Kehadiran tetap tercatat, tetapi posisi manajerial tidak dikenai penalti merah.';
    case 'hadir_tanpa_jadwal':
      return 'Kehadiran tetap tercatat walau jadwal belum tersedia.';
    default:
      break;
  }

  switch (day.attendanceStatus) {
    case 'sakit':
      return 'Karyawan tercatat sakit pada hari tersebut.';
    case 'izin':
      return 'Karyawan tercatat izin pada hari tersebut.';
    case 'cuti':
      return 'Karyawan tercatat cuti pada hari tersebut.';
    case 'libur':
      return 'Hari tersebut tidak memiliki target kerja.';
    case 'belum_masuk':
      return 'Hari kerja hari ini belum memiliki scan masuk.';
    default:
      return null;
  }
}

function buildPresentation(day: PortalRecapDay): RecapDayPresentation {
  // Libur always wins — regardless of any strictPrimaryStatus that the RPC
  // might have set (e.g. data inconsistency), a libur day is always neutral.
  if (day.attendanceStatus === 'libur') {
    return {
      label: 'Libur',
      tone: 'neutral',
      needsFollowUp: false,
      followUpLabel: null,
      supportingCopy: day.helperCopy ?? 'Hari tersebut tidak memiliki target kerja.',
    };
  }

  const label =
    day.strictOutcomeLabel ??
    (day.attendanceStatus === 'hadir'
      ? 'Hadir'
      : day.attendanceStatus === 'hadir_tanpa_jadwal'
        ? 'Hadir tanpa jadwal'
        : day.attendanceStatus === 'belum_masuk'
          ? 'Belum masuk'
          : day.attendanceStatus === 'sakit'
            ? 'Sakit'
            : day.attendanceStatus === 'izin'
              ? 'Izin'
              : day.attendanceStatus === 'cuti'
                ? 'Cuti'
                : 'Tanpa jadwal');

  switch (day.strictPrimaryStatus) {
    case 'late':
      return {
        label,
        tone: 'warning',
        needsFollowUp: false,
        followUpLabel: null,
        supportingCopy: defaultSupportingCopy(day),
      };
    case 'overtime':
      return {
        label,
        tone: 'warning',
        needsFollowUp: false,
        followUpLabel: null,
        supportingCopy: defaultSupportingCopy(day),
      };
    case 'short_work':
    case 'excess_break':
      return {
        label,
        tone: 'danger',
        needsFollowUp: false,
        followUpLabel: null,
        supportingCopy: defaultSupportingCopy(day),
      };
    case 'absence':
      return {
        label,
        tone: 'danger',
        needsFollowUp: true,
        followUpLabel: 'Tidak ada kehadiran tercatat',
        supportingCopy: defaultSupportingCopy(day),
      };
    case 'belum_absen_pulang':
      return {
        label,
        tone: 'danger',
        needsFollowUp: true,
        followUpLabel: 'Absensi pulang belum tercatat',
        supportingCopy: defaultSupportingCopy(day),
      };
    case 'active_incomplete':
      return {
        label,
        tone: 'accent',
        needsFollowUp: false,
        followUpLabel: null,
        supportingCopy: defaultSupportingCopy(day),
      };
    case 'exempt_manager':
    case 'hadir_tanpa_jadwal':
      return {
        label,
        tone: 'neutral',
        needsFollowUp: false,
        followUpLabel: null,
        supportingCopy: defaultSupportingCopy(day),
      };
    default:
      break;
  }

  switch (day.attendanceStatus) {
    case 'hadir':
      return {
        label,
        tone: 'success',
        needsFollowUp: false,
        followUpLabel: null,
        supportingCopy: defaultSupportingCopy(day),
      };
    case 'belum_masuk':
      return {
        label,
        tone: 'accent',
        needsFollowUp: false,
        followUpLabel: null,
        supportingCopy: defaultSupportingCopy(day),
      };
    case 'sakit':
    case 'izin':
    case 'cuti':
      return {
        label,
        tone: 'neutral',
        needsFollowUp: false,
        followUpLabel: null,
        supportingCopy: defaultSupportingCopy(day),
      };
    default:
      return {
        ...NULL_PRESENTATION,
        supportingCopy: defaultSupportingCopy(day),
      };
  }
}

export function getRecapDayPresentationForDay(
  day: PortalRecapDay,
  _referenceDate: string,
): RecapDayPresentation {
  return buildPresentation(day);
}

export function countFollowUpDays(days: PortalRecapDay[]): number {
  return days.filter((day) => buildPresentation(day).needsFollowUp).length;
}
