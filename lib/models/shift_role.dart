/// Dynamic shift role model fetched from Supabase `shift_roles` table.
///
/// Replaces hardcoded role lists so admin can manage roles from database
/// without requiring an APK update.
class ShiftRole {
  final String id;
  final String name;
  final String? outletModeFilter; // null = all outlets, 'TWENTY_FOUR_HOUR' = 24h only
  final int sortOrder;
  final bool isActive;

  const ShiftRole({
    required this.id,
    required this.name,
    this.outletModeFilter,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory ShiftRole.fromJson(Map<String, dynamic> json) => ShiftRole(
        id: json['id'] as String,
        name: json['name'] as String,
        outletModeFilter: json['outlet_mode_filter'] as String?,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );

  /// Hardcoded fallback for offline mode — matches initial seed data.
  static const List<ShiftRole> fallbackRoles = [
    ShiftRole(id: 'fb-1', name: 'Kasir', sortOrder: 1),
    ShiftRole(id: 'fb-2', name: 'Assambler', sortOrder: 2),
    ShiftRole(id: 'fb-3', name: 'Housekeeping', sortOrder: 3),
    ShiftRole(id: 'fb-4', name: 'Checker', sortOrder: 4),
    ShiftRole(id: 'fb-5', name: 'Ayam', sortOrder: 5),
    ShiftRole(id: 'fb-6', name: 'Kitchen', sortOrder: 6),
    ShiftRole(
        id: 'fb-7',
        name: 'Kopi',
        outletModeFilter: 'TWENTY_FOUR_HOUR',
        sortOrder: 7),
  ];
}
