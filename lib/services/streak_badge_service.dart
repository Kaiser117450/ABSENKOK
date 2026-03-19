import 'package:flutter/foundation.dart';
import '../core/supabase_client.dart';
import '../main.dart'; // supabaseReady
import 'badge_service.dart';

class StreakBadgeService {
  StreakBadgeService._();
  static final instance = StreakBadgeService._();

  /// Milestone thresholds and their badge definitions
  static const _milestones = {
    7: _MilestoneDef(name: 'Streak 7 Hari', emoji: '\u{1F525}', color: '#F59E0B'),
    30: _MilestoneDef(name: 'Streak 30 Hari', emoji: '\u{2B50}', color: '#F59E0B'),
    90: _MilestoneDef(name: 'Streak 90 Hari', emoji: '\u{1F3C6}', color: '#F59E0B'),
  };

  /// Check if currentStreak hits a milestone and award badge if so.
  /// Returns the milestone hit (7, 30, or 90) or null if no milestone.
  Future<int?> checkAndAwardMilestone({
    required String employeeId,
    required int currentStreak,
  }) async {
    final milestone = _milestones.keys.cast<int?>().firstWhere(
      (m) => currentStreak == m,
      orElse: () => null,
    );
    if (milestone == null) return null;

    final def = _milestones[milestone]!;
    try {
      // Find or create the milestone badge definition
      final badgeId = await _ensureBadgeExists(def);
      if (badgeId != null) {
        await BadgeService.instance.assignBadge(employeeId, badgeId);
        debugPrint('[StreakBadgeService] Awarded ${def.name} to $employeeId');
      }
    } catch (e) {
      debugPrint('[StreakBadgeService] Award failed: $e');
    }
    return milestone;
  }

  /// Ensure the streak badge definition exists, create if not. Returns badge ID.
  Future<String?> _ensureBadgeExists(_MilestoneDef def) async {
    if (!supabaseReady) return null;
    try {
      // Check if badge with this name already exists
      final existing = await SupabaseClientFactory.admin
          .from('badges')
          .select('id')
          .eq('name', def.name)
          .maybeSingle();
      if (existing != null) return existing['id'] as String;

      // Create new badge definition
      final badge = await BadgeService.instance.createBadge(
        name: def.name,
        emoji: def.emoji,
        borderColor: def.color,
        borderStyle: 'solid',
      );
      return badge.id;
    } catch (e) {
      debugPrint('[StreakBadgeService] _ensureBadgeExists failed: $e');
      return null;
    }
  }
}

class _MilestoneDef {
  final String name;
  final String emoji;
  final String color;
  const _MilestoneDef({required this.name, required this.emoji, required this.color});
}
