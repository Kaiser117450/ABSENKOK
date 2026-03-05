class Outlet {
  final String id;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? deviceId;
  final bool isActive;
  final String createdAt;

  const Outlet({
    required this.id,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.deviceId,
    required this.isActive,
    required this.createdAt,
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
      };
}
