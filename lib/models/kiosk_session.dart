import 'dart:convert';

/// Persisted kiosk device session stored in FlutterSecureStorage.
/// One session per device, configured at first-run setup.
/// Auth: uses Supabase anon key (password verified via RPC on setup).
class KioskSession {
  final String outletId;
  final String outletName;
  final String deviceId;

  const KioskSession({
    required this.outletId,
    required this.outletName,
    required this.deviceId,
  });

  factory KioskSession.fromJson(Map<String, dynamic> json) {
    final outletId = json['outlet_id'] as String?;
    final outletName = json['outlet_name'] as String?;
    final deviceId = json['device_id'] as String?;
    // If any required field is missing (e.g. stale data from old schema),
    // throw so loadSession() can discard it cleanly.
    if (outletId == null || outletName == null || deviceId == null) {
      throw const FormatException('KioskSession: missing required fields');
    }
    return KioskSession(
      outletId: outletId,
      outletName: outletName,
      deviceId: deviceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'outlet_id': outletId,
        'outlet_name': outletName,
        'device_id': deviceId,
      };

  String toJsonString() => jsonEncode(toJson());

  factory KioskSession.fromJsonString(String raw) =>
      KioskSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
