String _normalizeAttendancePolicyToken(String? raw) {
  return raw?.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '') ?? '';
}

enum AttendancePolicySeverity {
  info('info', 'Info'),
  yellow('yellow', 'Perlu perhatian'),
  red('red', 'Pelanggaran');

  const AttendancePolicySeverity(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static AttendancePolicySeverity parse(String? raw) {
    return tryParse(raw) ?? AttendancePolicySeverity.info;
  }

  static AttendancePolicySeverity? tryParse(String? raw) {
    switch (_normalizeAttendancePolicyToken(raw)) {
      case 'info':
        return AttendancePolicySeverity.info;
      case 'yellow':
      case 'warning':
        return AttendancePolicySeverity.yellow;
      case 'red':
      case 'danger':
        return AttendancePolicySeverity.red;
      default:
        return null;
    }
  }
}

enum AttendancePolicyPrimaryStatus {
  hadir('hadir', 'Hadir'),
  late('late', 'Terlambat'),
  shortWork('short_work', 'Kurang jam kerja'),
  excessBreak('excess_break', 'Istirahat berlebih'),
  overtime('overtime', 'Lembur'),
  absence('absence', 'Tidak hadir'),
  exemptManager('exempt_manager', 'Manager exempt'),
  hadirTanpaJadwal('hadir_tanpa_jadwal', 'Hadir tanpa jadwal'),
  belumAbsenPulang('belum_absen_pulang', 'Belum absen pulang'),
  activeIncomplete('active_incomplete', 'Hari masih berjalan'),
  belumMasuk('belum_masuk', 'Belum masuk'),
  sakit('sakit', 'Sakit'),
  izin('izin', 'Izin'),
  cuti('cuti', 'Cuti'),
  libur('libur', 'Libur');

  const AttendancePolicyPrimaryStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static AttendancePolicyPrimaryStatus parse(String? raw) {
    return tryParse(raw) ?? AttendancePolicyPrimaryStatus.hadir;
  }

  static AttendancePolicyPrimaryStatus? tryParse(String? raw) {
    switch (_normalizeAttendancePolicyToken(raw)) {
      case 'hadir':
        return AttendancePolicyPrimaryStatus.hadir;
      case 'late':
      case 'terlambat':
        return AttendancePolicyPrimaryStatus.late;
      case 'shortwork':
      case 'kurangjamkerja':
        return AttendancePolicyPrimaryStatus.shortWork;
      case 'excessbreak':
      case 'istirahatberlebih':
        return AttendancePolicyPrimaryStatus.excessBreak;
      case 'overtime':
      case 'lembur':
        return AttendancePolicyPrimaryStatus.overtime;
      case 'absence':
      case 'tidakhadir':
        return AttendancePolicyPrimaryStatus.absence;
      case 'exemptmanager':
      case 'managerexempt':
        return AttendancePolicyPrimaryStatus.exemptManager;
      case 'hadirtanpajadwal':
        return AttendancePolicyPrimaryStatus.hadirTanpaJadwal;
      case 'belumabsenpulang':
        return AttendancePolicyPrimaryStatus.belumAbsenPulang;
      case 'activeincomplete':
        return AttendancePolicyPrimaryStatus.activeIncomplete;
      case 'belummasuk':
        return AttendancePolicyPrimaryStatus.belumMasuk;
      case 'sakit':
        return AttendancePolicyPrimaryStatus.sakit;
      case 'izin':
        return AttendancePolicyPrimaryStatus.izin;
      case 'cuti':
        return AttendancePolicyPrimaryStatus.cuti;
      case 'libur':
        return AttendancePolicyPrimaryStatus.libur;
      default:
        return null;
    }
  }
}

enum AttendancePolicySignal {
  late('late', 'Terlambat'),
  shortWork('short_work', 'Kurang jam kerja'),
  excessBreak('excess_break', 'Istirahat berlebih'),
  overtime('overtime', 'Lembur'),
  absence('absence', 'Tidak hadir'),
  exemptManager('exempt_manager', 'Manager exempt'),
  hadirTanpaJadwal('hadir_tanpa_jadwal', 'Hadir tanpa jadwal'),
  belumAbsenPulang('belum_absen_pulang', 'Belum absen pulang'),
  activeIncomplete('active_incomplete', 'Hari masih berjalan');

  const AttendancePolicySignal(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static AttendancePolicySignal parse(String? raw) {
    return tryParse(raw) ?? AttendancePolicySignal.late;
  }

  static AttendancePolicySignal? tryParse(String? raw) {
    switch (_normalizeAttendancePolicyToken(raw)) {
      case 'late':
      case 'terlambat':
        return AttendancePolicySignal.late;
      case 'shortwork':
      case 'kurangjamkerja':
        return AttendancePolicySignal.shortWork;
      case 'excessbreak':
      case 'istirahatberlebih':
        return AttendancePolicySignal.excessBreak;
      case 'overtime':
      case 'lembur':
        return AttendancePolicySignal.overtime;
      case 'absence':
      case 'tidakhadir':
        return AttendancePolicySignal.absence;
      case 'exemptmanager':
      case 'managerexempt':
        return AttendancePolicySignal.exemptManager;
      case 'hadirtanpajadwal':
        return AttendancePolicySignal.hadirTanpaJadwal;
      case 'belumabsenpulang':
        return AttendancePolicySignal.belumAbsenPulang;
      case 'activeincomplete':
        return AttendancePolicySignal.activeIncomplete;
      default:
        return null;
    }
  }
}
