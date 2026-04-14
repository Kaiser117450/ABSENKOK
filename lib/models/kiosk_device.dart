class KioskDevice {
  final String id;
  final String deviceUuid;
  final String? outletId;
  final DateTime? lastHeartbeatAt;
  final int? batteryLevel;
  final bool? isCharging;
  final int? pendingSyncCount;
  final String? appVersion;
  final String? nickname;
  final bool isActive;

  const KioskDevice({
    required this.id,
    required this.deviceUuid,
    this.outletId,
    this.lastHeartbeatAt,
    this.batteryLevel,
    this.isCharging,
    this.pendingSyncCount,
    this.appVersion,
    this.nickname,
    this.isActive = true,
  });

  bool get isOnline =>
      lastHeartbeatAt != null &&
      DateTime.now().difference(lastHeartbeatAt!).inMinutes <= 30;

  /// Device offline > 4 hari — otomatis di-archive saat load dashboard
  bool get isStale =>
      lastHeartbeatAt != null &&
      !isOnline &&
      DateTime.now().difference(lastHeartbeatAt!).inDays >= 4;

  String get displayName {
    final trimmedNickname = nickname?.trim();
    if (trimmedNickname != null && trimmedNickname.isNotEmpty) {
      return trimmedNickname;
    }
    return _buildFallbackDisplayName(deviceUuid);
  }

  factory KioskDevice.fromJson(Map<String, dynamic> json) => KioskDevice(
        id: json['id'] as String,
        deviceUuid: _parseDeviceUuid(json['device_uuid']),
        outletId: json['outlet_id'] as String?,
        lastHeartbeatAt: _parseTimestamp(json['last_heartbeat_at']),
        batteryLevel: json['battery_level'] as int?,
        isCharging: json['is_charging'] as bool?,
        pendingSyncCount: json['pending_sync_count'] as int?,
        appVersion: json['app_version'] as String?,
        nickname: json['nickname'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  KioskDevice copyWith({
    String? nickname,
    bool? isActive,
    int? batteryLevel,
    bool? isCharging,
    int? pendingSyncCount,
    DateTime? lastHeartbeatAt,
  }) =>
      KioskDevice(
        id: id,
        deviceUuid: deviceUuid,
        outletId: outletId,
        lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
        batteryLevel: batteryLevel ?? this.batteryLevel,
        isCharging: isCharging ?? this.isCharging,
        pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
        appVersion: appVersion,
        nickname: nickname ?? this.nickname,
        isActive: isActive ?? this.isActive,
      );

  static String _parseDeviceUuid(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static DateTime? _parseTimestamp(dynamic value) {
    final rawValue = value?.toString().trim();
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(rawValue);
    } on FormatException {
      return null;
    }
  }

  static String _buildFallbackDisplayName(String value) {
    final safeValue = value.trim();
    if (safeValue.length < 8) {
      return 'Kiosk';
    }
    return 'Kiosk ${safeValue.substring(0, 8)}';
  }
}
