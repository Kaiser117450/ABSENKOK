import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';

/// Manages a persistent installation-level device identity (UUIDv4).
///
/// The UUID is generated on first boot and persisted in SharedPreferences.
/// It survives kiosk logout, re-setup, and outlet reassignment.
/// Only app reinstall or data clear generates a new UUID.
///
/// Usage:
///   final deviceUuid = await DeviceIdentityService.getOrCreateDeviceUuid();
class DeviceIdentityService {
  static const _uuid = Uuid();

  /// UUIDv4 regex pattern per RFC 4122.
  static final _uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// Get or create the persistent installation UUID.
  ///
  /// - If a valid UUIDv4 exists in SharedPreferences, returns it.
  /// - If an old-format device ID exists (non-UUID), generates a new UUIDv4
  ///   and replaces it (auto-upgrade).
  /// - If no ID exists, generates a new UUIDv4.
  static Future<String> getOrCreateDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(AppConstants.installationDeviceUuidKey);

    if (existing != null && isValidUuidV4(existing)) {
      debugPrint('[DeviceIdentity] existing UUID: $existing');
      return existing;
    }

    // Auto-upgrade or first boot: generate new UUIDv4
    final newUuid = _uuid.v4();
    await prefs.setString(AppConstants.installationDeviceUuidKey, newUuid);

    if (existing != null) {
      debugPrint('[DeviceIdentity] upgraded old ID "$existing" → $newUuid');
    } else {
      debugPrint('[DeviceIdentity] generated new UUID: $newUuid');
    }

    return newUuid;
  }

  /// Validates that a string is a well-formed UUIDv4.
  static bool isValidUuidV4(String value) {
    return _uuidV4Pattern.hasMatch(value);
  }
}
