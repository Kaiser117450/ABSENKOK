import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';

class GroomingRow {
  final String attendanceLogId;
  final String photoUrl;
  final String employeeId;
  final String employeeName;
  final String employeePosition;
  final String outletId;
  final String outletName;
  final String attendanceType;
  final DateTime scannedAt;
  final DateTime? analyzedAt;
  final bool faceDetected;
  final int faceCount;
  final String photoQuality;
  final double? groomingScore;
  final double? qcOverrideScore;
  final String? qcOverrideNote;
  final String? qcOverriddenBy;
  final DateTime? qcOverriddenAt;
  final bool safeSearchPassed;
  final String? faceCleanShave;
  final String? uniformCompliant;
  final String? hairNeat;
  final String? hairLength;
  final String? headCovering;
  final String? reasoning;
  // Per-criterion {face,uniform,hair,photo,total,max} points from the rubric.
  final Map<String, dynamic>? scoreBreakdown;
  // Per-criterion admin corrections. Keys: face_clean_shave, uniform_compliant,
  // hair_neat, hair_length. Value of `true` means "admin marked AI's bad
  // judgement as OK".
  final Map<String, bool> qcCorrections;

  const GroomingRow({
    required this.attendanceLogId,
    required this.photoUrl,
    required this.employeeId,
    required this.employeeName,
    required this.employeePosition,
    required this.outletId,
    required this.outletName,
    required this.attendanceType,
    required this.scannedAt,
    required this.analyzedAt,
    required this.faceDetected,
    required this.faceCount,
    required this.photoQuality,
    required this.groomingScore,
    required this.qcOverrideScore,
    required this.qcOverrideNote,
    required this.qcOverriddenBy,
    required this.qcOverriddenAt,
    required this.safeSearchPassed,
    required this.faceCleanShave,
    required this.uniformCompliant,
    required this.hairNeat,
    required this.headCovering,
    required this.reasoning,
    required this.qcCorrections,
    this.hairLength,
    this.scoreBreakdown,
  });

  double? get effectiveScore => qcOverrideScore ?? groomingScore;

  bool get isOverridden => qcOverriddenAt != null;

  /// True when the admin has corrected at least one AI criterion verdict.
  bool get hasCorrections => qcCorrections.values.any((v) => v == true);

  // Per-criterion getters that fold in the admin's corrections.
  bool get faceCleanShaveOk =>
      qcCorrections['face_clean_shave'] == true || faceCleanShave == 'ok';
  bool get uniformCompliantOk =>
      qcCorrections['uniform_compliant'] == true || uniformCompliant == 'ok';
  bool get hairNeatOk =>
      qcCorrections['hair_neat'] == true ||
      hairNeat == 'ok' ||
      hairNeat == 'not_visible' ||
      hairNeat == null;
  // Long hair is the only "bad" hair_length verdict; everything else is OK.
  bool get hairLengthOk =>
      qcCorrections['hair_length'] == true || hairLength != 'long';
  // Hair points (3) require both neatness and acceptable length.
  bool get hairOk => hairNeatOk && hairLengthOk;

  /// Recomputes a 0–10 score from corrected per-criterion judgements using
  /// the same weights as the Cloud Vision rubric (face/uniform/hair + photo).
  double get correctedScore {
    double score = 0;
    if (faceCleanShaveOk) score += 3;
    if (uniformCompliantOk) score += 3;
    if (hairOk) score += 3;
    if (photoQuality == 'clear') score += 1;
    return score.clamp(0, 10).toDouble();
  }

  bool get needsReview {
    final s = effectiveScore;
    if (s != null && s < 6) return true;
    if (!faceDetected || faceCount != 1) return true;
    if (!safeSearchPassed) return true;
    return false;
  }

  factory GroomingRow.fromRow(Map<String, dynamic> json) {
    final log = Map<String, dynamic>.from(
      (json['attendance_logs'] as Map?) ?? const {},
    );
    final employee = Map<String, dynamic>.from(
      (log['employees'] as Map?) ?? const {},
    );
    final outlet = Map<String, dynamic>.from(
      (log['outlets'] as Map?) ?? const {},
    );
    return GroomingRow(
      attendanceLogId: (json['attendance_log_id'] ?? log['id']).toString(),
      photoUrl: (json['photo_url'] ?? '').toString(),
      employeeId: (employee['id'] ?? '').toString(),
      employeeName: (employee['name'] ?? '-').toString(),
      employeePosition: (employee['position'] ?? '-').toString(),
      outletId: (log['scan_outlet_id'] ?? '').toString(),
      outletName: (outlet['name'] ?? '-').toString(),
      attendanceType: (log['type'] ?? 'masuk').toString(),
      scannedAt: DateTime.tryParse(log['scanned_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      analyzedAt: DateTime.tryParse(json['analyzed_at']?.toString() ?? ''),
      faceDetected: json['face_detected'] == true,
      faceCount: (json['face_count'] as num?)?.toInt() ?? 0,
      photoQuality: (json['photo_quality'] ?? 'clear').toString(),
      groomingScore: (json['grooming_score'] as num?)?.toDouble(),
      qcOverrideScore: (json['qc_override_score'] as num?)?.toDouble(),
      qcOverrideNote: json['qc_override_note']?.toString(),
      qcOverriddenBy: json['qc_overridden_by']?.toString(),
      qcOverriddenAt:
          DateTime.tryParse(json['qc_overridden_at']?.toString() ?? ''),
      safeSearchPassed: json['safe_search_passed'] != false,
      faceCleanShave: json['face_clean_shave']?.toString(),
      uniformCompliant: json['uniform_compliant']?.toString(),
      hairNeat: json['hair_neat']?.toString(),
      hairLength: json['hair_length']?.toString(),
      headCovering: json['head_covering']?.toString(),
      reasoning: json['reasoning']?.toString(),
      scoreBreakdown: json['score_breakdown'] is Map
          ? Map<String, dynamic>.from(json['score_breakdown'] as Map)
          : null,
      qcCorrections: _parseCorrections(json['qc_corrections']),
    );
  }

  static Map<String, bool> _parseCorrections(dynamic raw) {
    if (raw is Map) {
      return {
        for (final entry in raw.entries)
          entry.key.toString(): entry.value == true,
      };
    }
    return const {};
  }
}

class GroomingFilter {
  final DateTime since;
  final DateTime until;
  final Set<String> outletIds;
  final String? employeeQuery;
  final bool needsReviewOnly;
  final bool overriddenOnly;

  const GroomingFilter({
    required this.since,
    required this.until,
    this.outletIds = const {},
    this.employeeQuery,
    this.needsReviewOnly = false,
    this.overriddenOnly = false,
  });

  factory GroomingFilter.last30Days() {
    final now = DateTime.now();
    return GroomingFilter(
      since: now.subtract(const Duration(days: 30)),
      until: now,
    );
  }
}

class GroomingQcService {
  GroomingQcService._();
  static final GroomingQcService instance = GroomingQcService._();

  static const _projection = 'attendance_log_id, photo_url, face_detected, '
      'face_confidence, face_count, photo_quality, grooming_labels, '
      'grooming_score, safe_search_passed, analyzed_at, face_clean_shave, '
      'uniform_compliant, hair_neat, hair_length, head_covering, reasoning, '
      'score_breakdown, model_name, '
      'qc_override_score, qc_override_note, qc_overridden_by, qc_overridden_at, '
      'qc_corrections, '
      'attendance_logs!inner(id, type, scanned_at, scan_outlet_id, employee_id, '
      'employees(id, name, position), outlets(name))';

  Future<List<GroomingRow>> fetchRows(GroomingFilter filter) async {
    var query = SupabaseClientFactory.admin
        .from('attendance_photo_analysis')
        .select(_projection)
        .gte('analyzed_at', filter.since.toUtc().toIso8601String())
        .lte('analyzed_at', filter.until.toUtc().toIso8601String());
    if (filter.overriddenOnly) {
      query = query.not('qc_overridden_at', 'is', null);
    }
    final raw = await query.order('analyzed_at', ascending: false).limit(500);
    final rows = (raw as List)
        .map((row) =>
            GroomingRow.fromRow(Map<String, dynamic>.from(row as Map)))
        .where((row) =>
            filter.outletIds.isEmpty ||
            filter.outletIds.contains(row.outletId))
        .where((row) {
          if (filter.employeeQuery == null || filter.employeeQuery!.isEmpty) {
            return true;
          }
          return row.employeeName
              .toLowerCase()
              .contains(filter.employeeQuery!.toLowerCase());
        })
        .where((row) => !filter.needsReviewOnly || row.needsReview)
        .toList(growable: false);
    return rows;
  }

  Stream<List<GroomingRow>> watchRows(GroomingFilter filter) async* {
    yield await fetchRows(filter);
    final controller = StreamController<List<GroomingRow>>();
    Timer? debounce;
    final channel = SupabaseClientFactory.admin
        .channel('grooming_qc_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance_photo_analysis',
          callback: (_) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 400), () async {
              try {
                controller.add(await fetchRows(filter));
              } catch (_) {}
            });
          },
        )
        .subscribe();
    controller.onCancel = () async {
      debounce?.cancel();
      await channel.unsubscribe();
      await controller.close();
    };
    yield* controller.stream;
  }

  Future<void> applyOverride({
    required String attendanceLogId,
    required double score,
    required String note,
    Map<String, bool>? corrections,
  }) async {
    await SupabaseClientFactory.admin.rpc(
      'apply_grooming_qc_override',
      params: {
        'p_attendance_log_id': attendanceLogId,
        'p_score': score,
        'p_note': note,
        if (corrections != null) 'p_corrections': corrections,
      },
    );
  }
}
