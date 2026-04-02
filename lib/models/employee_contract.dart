/// Canonical employee contract types stored in `public.employees.employment_contract`.
enum EmployeeContract {
  fulltime,
  parttime;

  /// The canonical uppercase value persisted in the database.
  String get dbValue {
    switch (this) {
      case EmployeeContract.fulltime:
        return 'FULLTIME';
      case EmployeeContract.parttime:
        return 'PARTTIME';
    }
  }

  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case EmployeeContract.fulltime:
        return 'Full-Time';
      case EmployeeContract.parttime:
        return 'Part-Time';
    }
  }

  /// Parse a raw database or CSV value into a typed contract.
  ///
  /// Normalizes common aliases (`PARTIME`, `part-time`, `full-time`, mixed case).
  /// Returns [EmployeeContract.fulltime] for null or unrecognized values so the
  /// app degrades safely during staged rollout.
  static EmployeeContract parse(String? raw) {
    return tryParse(raw) ?? EmployeeContract.fulltime;
  }

  /// Parse a raw value only when it matches one of the supported aliases.
  ///
  /// Returns null for empty or unsupported values so validation flows can
  /// surface a clear operator error instead of silently defaulting.
  static EmployeeContract? tryParse(String? raw) {
    if (raw == null) return null;
    final normalized =
        raw.replaceAll(RegExp(r'[\s_-]+'), '').trim().toUpperCase();
    if (normalized.isEmpty) return null;

    switch (normalized) {
      case 'FULLTIME':
        return EmployeeContract.fulltime;
      case 'PARTTIME':
      case 'PARTIME': // common typo
        return EmployeeContract.parttime;
      default:
        return null;
    }
  }
}
