import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  /// Returns true if device has biometric hardware AND user has enrolled biometrics.
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on Exception catch (e) {
      debugPrint('[BiometricService] isAvailable error: $e');
      return false;
    }
  }

  /// Returns list of available biometric types (for UI display).
  static Future<List<BiometricType>> getAvailableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on Exception {
      return [];
    }
  }

  /// Prompts biometric authentication. Returns true on success.
  /// Returns false on cancel, failure, or error.
  static Future<bool> authenticate({
    String reason = 'Verifikasi identitas untuk masuk',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on Exception catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      return false;
    }
  }
}
