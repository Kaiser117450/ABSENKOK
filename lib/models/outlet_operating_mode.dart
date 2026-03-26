/// Canonical outlet operating modes stored in `public.outlets.operating_mode`.
enum OutletOperatingMode {
  normal,
  twentyFourHour;

  /// The canonical uppercase value persisted in the database.
  String get dbValue {
    switch (this) {
      case OutletOperatingMode.normal:
        return 'NORMAL';
      case OutletOperatingMode.twentyFourHour:
        return 'TWENTY_FOUR_HOUR';
    }
  }

  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case OutletOperatingMode.normal:
        return 'Normal';
      case OutletOperatingMode.twentyFourHour:
        return '24 Jam';
    }
  }

  /// Parse a raw database value into a typed operating mode.
  ///
  /// Returns [OutletOperatingMode.normal] for null or unrecognized values so
  /// the app degrades safely during staged rollout.
  static OutletOperatingMode parse(String? raw) {
    if (raw == null) return OutletOperatingMode.normal;
    final normalized = raw.trim().toUpperCase();
    switch (normalized) {
      case 'NORMAL':
        return OutletOperatingMode.normal;
      case 'TWENTY_FOUR_HOUR':
        return OutletOperatingMode.twentyFourHour;
      default:
        return OutletOperatingMode.normal;
    }
  }
}
