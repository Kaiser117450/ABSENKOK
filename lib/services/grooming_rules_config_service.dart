import '../core/supabase_client.dart';

/// One version of the admin-editable grooming rule config (the JSONB the
/// analyze-attendance-photo edge function reads at runtime).
class GroomingRulesConfig {
  final String? id;
  final int version;
  final Map<String, dynamic> config; // raw JSONB: thresholds/weights/label_sets/flagged_labels
  final String? note;
  final DateTime? updatedAt;

  const GroomingRulesConfig({
    this.id,
    required this.version,
    required this.config,
    this.note,
    this.updatedAt,
  });

  factory GroomingRulesConfig.fromJson(Map<String, dynamic> j) {
    return GroomingRulesConfig(
      id: j['id']?.toString(),
      version: (j['version'] as num?)?.toInt() ?? 0,
      config: j['config'] is Map
          ? Map<String, dynamic>.from(j['config'] as Map)
          : <String, dynamic>{},
      note: j['note']?.toString(),
      updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? ''),
    );
  }
}

class GroomingRulesConfigService {
  GroomingRulesConfigService._();
  static final GroomingRulesConfigService instance =
      GroomingRulesConfigService._();

  /// Returns the active rule config, or null if none exists yet.
  Future<GroomingRulesConfig?> fetchActive() async {
    final res = await SupabaseClientFactory.admin
        .rpc('get_active_grooming_rules');
    if (res == null) return null;
    return GroomingRulesConfig.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Saves a new active config version. Returns the new version number.
  Future<int> save(Map<String, dynamic> config, {String? note}) async {
    final res =
        await SupabaseClientFactory.admin.rpc('save_grooming_rules', params: {
      'p_config': config,
      if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
    });
    final map = Map<String, dynamic>.from(res as Map);
    return (map['version'] as num?)?.toInt() ?? 0;
  }
}
