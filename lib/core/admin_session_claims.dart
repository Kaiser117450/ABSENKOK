import 'package:supabase_flutter/supabase_flutter.dart';

enum AdminSessionRole {
  admin,
  kepalaGerai,
  areaSupervisor,

  /// Read-only Quality Control reviewer. Sees grooming QC for the outlet(s)
  /// it is scoped to, but cannot change anything (no overrides, no rules,
  /// no user/outlet management). Beta feature (Phase 74).
  qc,
}

class AdminSessionClaims {
  const AdminSessionClaims._({
    required this.role,
    this.managedOutletId,
    this.managedOutletIds = const <String>[],
  });

  const AdminSessionClaims.admin() : this._(role: AdminSessionRole.admin);

  const AdminSessionClaims.kepalaGerai(String managedOutletId)
      : this._(
          role: AdminSessionRole.kepalaGerai,
          managedOutletId: managedOutletId,
          managedOutletIds: const <String>[],
        );

  AdminSessionClaims.areaSupervisor(List<String> managedOutletIds)
      : this._(
          role: AdminSessionRole.areaSupervisor,
          managedOutletId:
              managedOutletIds.isEmpty ? null : managedOutletIds.first,
          managedOutletIds: List.unmodifiable(managedOutletIds),
        );

  /// Read-only QC reviewer scoped to one or more outlets. Mirrors the
  /// area-supervisor shape so a QC can cover a single gerai or a small set.
  AdminSessionClaims.qc(List<String> managedOutletIds)
      : this._(
          role: AdminSessionRole.qc,
          managedOutletId:
              managedOutletIds.isEmpty ? null : managedOutletIds.first,
          managedOutletIds: List.unmodifiable(managedOutletIds),
        );

  final AdminSessionRole role;
  final String? managedOutletId;
  final List<String> managedOutletIds;

  bool get isAdmin => role == AdminSessionRole.admin;
  bool get isKepalaGerai => role == AdminSessionRole.kepalaGerai;
  bool get isAreaSupervisor => role == AdminSessionRole.areaSupervisor;
  bool get isQc => role == AdminSessionRole.qc;
  bool get isScopedOutletAdmin => isKepalaGerai || isAreaSupervisor;

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
      case 'area_supervisor':
        final outletIds = _readNonEmptyStringList(
          appMetadata?['managed_outlet_ids'],
        );
        final legacyOutletId = _readNonEmptyString(
          appMetadata?['managed_outlet_id'],
        );
        final scopedOutletIds = <String>{
          ...outletIds,
          if (legacyOutletId != null) legacyOutletId,
        }.toList(growable: false);
        if (scopedOutletIds.isEmpty) {
          return null;
        }
        return AdminSessionClaims.areaSupervisor(scopedOutletIds);
      case 'qc':
        final outletIds = _readNonEmptyStringList(
          appMetadata?['managed_outlet_ids'],
        );
        final legacyOutletId = _readNonEmptyString(
          appMetadata?['managed_outlet_id'],
        );
        final scopedOutletIds = <String>{
          ...outletIds,
          if (legacyOutletId != null) legacyOutletId,
        }.toList(growable: false);
        if (scopedOutletIds.isEmpty) {
          return null;
        }
        return AdminSessionClaims.qc(scopedOutletIds);
      default:
        return null;
    }
  }

  List<String> get effectiveManagedOutletIds {
    if (managedOutletIds.isNotEmpty) {
      return managedOutletIds;
    }
    final outletId = managedOutletId;
    if (outletId == null) {
      return const <String>[];
    }
    return <String>[outletId];
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

  static List<String> _readNonEmptyStringList(Object? value) {
    if (value is List) {
      return value
          .map(_readNonEmptyString)
          .nonNulls
          .toSet()
          .toList(growable: false);
    }

    final single = _readNonEmptyString(value);
    if (single == null) {
      return const <String>[];
    }

    return single
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
