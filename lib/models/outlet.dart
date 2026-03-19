class Outlet {
  final String id;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? deviceId;
  final bool isActive;
  final String createdAt;

  // Heartbeat fields (Phase 27) — all nullable, populated by HeartbeatService
  final DateTime? lastHeartbeatAt;
  final int? batteryLevel;
  final bool? isCharging;
  final int? pendingSyncCount;
  final String? appVersion;

  const Outlet({
    required this.id,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.deviceId,
    required this.isActive,
    required this.createdAt,
    this.lastHeartbeatAt,
    this.batteryLevel,
    this.isCharging,
    this.pendingSyncCount,
    this.appVersion,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        deviceId: json['device_id'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] as String? ?? '',
        lastHeartbeatAt: json['last_heartbeat_at'] != null
            ? DateTime.parse(json['last_heartbeat_at'] as String)
            : null,
        batteryLevel: json['battery_level'] as int?,
        isCharging: json['is_charging'] as bool?,
        pendingSyncCount: json['pending_sync_count'] as int?,
        appVersion: json['app_version'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'device_id': deviceId,
        'is_active': isActive,
        'created_at': createdAt,
        'last_heartbeat_at': lastHeartbeatAt?.toIso8601String(),
        'battery_level': batteryLevel,
        'is_charging': isCharging,
        'pending_sync_count': pendingSyncCount,
        'app_version': appVersion,
      };
}
