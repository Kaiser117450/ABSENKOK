import 'package:supabase_flutter/supabase_flutter.dart';

enum AdminSessionRole {
  admin,
  kepalaGerai,
}

class AdminSessionClaims {
  const AdminSessionClaims._({
    required this.role,
    this.managedOutletId,
  });

  const AdminSessionClaims.admin()
      : this._(role: AdminSessionRole.admin);

  const AdminSessionClaims.kepalaGerai(String managedOutletId)
      : this._(
          role: AdminSessionRole.kepalaGerai,
          managedOutletId: managedOutletId,
        );

  final AdminSessionRole role;
  final String? managedOutletId;

  bool get isAdmin => role == AdminSessionRole.admin;
  bool get isKepalaGerai => role == AdminSessionRole.kepalaGerai;

  static AdminSessionClaims? fromUser(User? user) {
    return fromMetadata(
      appMetadata: user?.appMetadata,
      userMetadata: user?.userMetadata,
    );
  }

  static AdminSessionClaims? fromMetadata({
    Map<String, dynamic>? appMetadata,
    Map<String, dynamic>? userMetadata,
  }) {
    // Privileged access is derived from server-issued app metadata only.
    final role = _readNonEmptyString(appMetadata?['app_role']);

    switch (role) {
      case 'admin':
        return const AdminSessionClaims.admin();
      case 'kepala_gerai':
        final outletId = _readNonEmptyString(appMetadata?['managed_outlet_id']);
        if (outletId == null) {
          return null;
        }
        return AdminSessionClaims.kepalaGerai(outletId);
      default:
        return null;
    }
  }

  static String? _readNonEmptyString(Object? value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
