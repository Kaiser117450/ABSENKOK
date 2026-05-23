// test/phase67/phase_67_grooming_qc_rubric_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('phase_67_grooming_qc_rubric.sql', () {
    late String sql;

    setUpAll(() {
      sql = File('sql/phase_67_grooming_qc_rubric.sql').readAsStringSync();
    });

    test('adds all 10 required additive columns with IF NOT EXISTS', () {
      const required = [
        'face_clean_shave',
        'uniform_compliant',
        'hair_neat',
        'head_covering',
        'reasoning',
        'model_name',
        'qc_override_score',
        'qc_override_note',
        'qc_overridden_by',
        'qc_overridden_at',
      ];
      for (final col in required) {
        expect(
          sql,
          contains('ADD COLUMN IF NOT EXISTS $col'),
          reason: 'missing additive ALTER for $col',
        );
      }
    });

    test('defines the override RPC with SECURITY DEFINER and safe search_path', () {
      expect(
        sql,
        contains('CREATE OR REPLACE FUNCTION public.apply_grooming_qc_override'),
        reason: 'missing RPC CREATE',
      );
      expect(
        sql,
        contains('SECURITY DEFINER'),
        reason: 'missing SECURITY DEFINER',
      );
      expect(
        sql,
        contains('SET search_path = public'),
        reason: 'missing search_path hardening',
      );
    });

    test('RPC validates admin role', () {
      expect(
        sql,
        contains("'admin'"),
        reason: 'missing admin role check',
      );
      expect(
        sql,
        contains('42501'),
        reason: 'missing forbidden ERRCODE 42501',
      );
    });

    test('RPC validates score range', () {
      expect(
        sql,
        contains('22023'),
        reason: 'missing validation ERRCODE 22023',
      );
    });

    test('RPC grants EXECUTE to authenticated and revokes from PUBLIC', () {
      expect(
        sql,
        contains('GRANT EXECUTE ON FUNCTION public.apply_grooming_qc_override'),
        reason: 'missing GRANT',
      );
      expect(
        sql,
        contains('REVOKE ALL ON FUNCTION public.apply_grooming_qc_override'),
        reason: 'missing REVOKE',
      );
    });

    test('defines index on qc_overridden_at with partial WHERE', () {
      expect(
        sql,
        contains('attendance_photo_analysis_overrides_idx'),
        reason: 'missing overrides index',
      );
      expect(
        sql,
        contains('WHERE qc_overridden_at IS NOT NULL'),
        reason: 'missing partial WHERE on overrides index',
      );
    });

    test('has COMMENT ON COLUMN for all semantic columns', () {
      const semanticCols = [
        'face_clean_shave',
        'uniform_compliant',
        'hair_neat',
        'head_covering',
        'reasoning',
        'model_name',
      ];
      for (final col in semanticCols) {
        expect(
          sql,
          contains('COMMENT ON COLUMN public.attendance_photo_analysis.$col'),
          reason: 'missing COMMENT ON COLUMN for $col',
        );
      }
    });

    test('is wrapped in BEGIN/COMMIT transactions', () {
      expect(
        RegExp(r'BEGIN;').allMatches(sql).length,
        greaterThanOrEqualTo(1),
        reason: 'missing BEGIN',
      );
      expect(
        RegExp(r'COMMIT;').allMatches(sql).length,
        greaterThanOrEqualTo(1),
        reason: 'missing COMMIT',
      );
    });
  });
}
