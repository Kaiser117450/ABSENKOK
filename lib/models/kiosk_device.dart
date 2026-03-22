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

  String get displayName =>
      nickname ?? 'Kiosk ${deviceUuid.substring(0, 8)}';

  factory KioskDevice.fromJson(Map<String, dynamic> json) => KioskDevice(
        id: json['id'] as String,
        deviceUuid: json['device_uuid'] as String,
        outletId: json['outlet_id'] as String?,
        lastHeartbeatAt: json['last_heartbeat_at'] != null
            ? DateTime.parse(json['last_heartbeat_at'] as String)
            : null,
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
}
