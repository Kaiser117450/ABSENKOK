import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/grooming_qc_service.dart';

class GroomingCard extends StatelessWidget {
  final GroomingRow row;
  final VoidCallback onTapPhoto;
  final VoidCallback onTapOverride;

  const GroomingCard({
    super.key,
    required this.row,
    required this.onTapPhoto,
    required this.onTapOverride,
  });

  @override
  Widget build(BuildContext context) {
    final breakdown = row.scoreBreakdown;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: row.needsReview
              ? AppColors.danger.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Thumbnail(url: row.photoUrl, onTap: onTapPhoto),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(
                    row.employeeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
                _ScorePill(row: row),
              ]),
              const SizedBox(height: 4),
              Text(
                '${row.outletName} · ${row.attendanceType.toUpperCase()} · ${_fmtTime(row.scannedAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _CriterionChip(spec: _faceSpec(row)),
                _CriterionChip(spec: _uniformSpec(row)),
                _CriterionChip(spec: _hairSpec(row)),
                if (_hairLengthSpec(row) != null)
                  _CriterionChip(spec: _hairLengthSpec(row)!),
                _CriterionChip(spec: _headCoveringSpec(row)),
              ]),
              if (breakdown != null) ...[
                const SizedBox(height: 8),
                _ScoreBreakdownRow(breakdown: breakdown),
              ],
              if ((row.reasoning ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                _ExpandableReasoning(text: row.reasoning!),
              ],
              if (row.isOverridden) ...[
                const SizedBox(height: 8),
                _OverriddenBanner(row: row),
              ],
              const SizedBox(height: 6),
              Row(children: [
                TextButton.icon(
                  onPressed: onTapOverride,
                  icon: Icon(
                    row.isOverridden
                        ? Icons.fact_check_rounded
                        : Icons.edit_note_rounded,
                    size: 18,
                  ),
                  label: Text(row.isOverridden ? 'Ubah koreksi' : 'Koreksi AI'),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  static String _fmtTime(DateTime dt) {
    final d = dt.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$mi';
  }
}

// ---------------------------------------------------------------------------
// Per-criterion chip spec (folds AI verdict with admin correction)
// ---------------------------------------------------------------------------

enum _ChipKind { ok, bad, neutral, corrected, info }

class _ChipSpec {
  final String label;
  final _ChipKind kind;
  const _ChipSpec(this.label, this.kind);
}

_ChipSpec _faceSpec(GroomingRow row) {
  final corrected = row.qcCorrections['face_clean_shave'] == true;
  switch (row.faceCleanShave) {
    case 'ok':
      return const _ChipSpec('Wajah OK', _ChipKind.ok);
    case 'beard':
      return corrected
          ? const _ChipSpec('Wajah OK', _ChipKind.corrected)
          : const _ChipSpec('Jenggot', _ChipKind.bad);
    case 'mustache':
      return corrected
          ? const _ChipSpec('Wajah OK', _ChipKind.corrected)
          : const _ChipSpec('Kumis', _ChipKind.bad);
    case 'stubble':
      return corrected
          ? const _ChipSpec('Wajah OK', _ChipKind.corrected)
          : const _ChipSpec('Bulu wajah', _ChipKind.bad);
    default:
      return const _ChipSpec('Wajah ?', _ChipKind.neutral);
  }
}

_ChipSpec _uniformSpec(GroomingRow row) {
  final corrected = row.qcCorrections['uniform_compliant'] == true;
  switch (row.uniformCompliant) {
    case 'ok':
      return const _ChipSpec('Seragam OK', _ChipKind.ok);
    case 'no_uniform':
      return corrected
          ? const _ChipSpec('Seragam OK', _ChipKind.corrected)
          : const _ChipSpec('Tanpa seragam', _ChipKind.bad);
    case 'wrong_attire':
      return corrected
          ? const _ChipSpec('Seragam OK', _ChipKind.corrected)
          : const _ChipSpec('Pakaian salah', _ChipKind.bad);
    default:
      return const _ChipSpec('Seragam ?', _ChipKind.neutral);
  }
}

_ChipSpec _hairSpec(GroomingRow row) {
  final corrected = row.qcCorrections['hair_neat'] == true;
  switch (row.hairNeat) {
    case 'not_visible':
      return const _ChipSpec('Rambut tertutup', _ChipKind.info);
    case 'messy':
      return corrected
          ? const _ChipSpec('Rambut OK', _ChipKind.corrected)
          : const _ChipSpec('Rambut acak', _ChipKind.bad);
    case 'ok':
      return const _ChipSpec('Rambut OK', _ChipKind.ok);
    default:
      return const _ChipSpec('Rambut OK', _ChipKind.ok);
  }
}

/// Only shown when the AI flagged long hair (the actionable case).
_ChipSpec? _hairLengthSpec(GroomingRow row) {
  if (row.hairLength != 'long') return null;
  final corrected = row.qcCorrections['hair_length'] == true;
  return corrected
      ? const _ChipSpec('Panjang → OK', _ChipKind.corrected)
      : const _ChipSpec('Rambut panjang', _ChipKind.bad);
}

_ChipSpec _headCoveringSpec(GroomingRow row) {
  switch (row.headCovering) {
    case 'hijab':
      return const _ChipSpec('Hijab', _ChipKind.info);
    case 'cap':
      return const _ChipSpec('Topi', _ChipKind.info);
    case 'other':
      return const _ChipSpec('Penutup lain', _ChipKind.info);
    default:
      return const _ChipSpec('Tanpa penutup', _ChipKind.neutral);
  }
}

class _CriterionChip extends StatelessWidget {
  final _ChipSpec spec;
  const _CriterionChip({required this.spec});

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    IconData? icon;
    switch (spec.kind) {
      case _ChipKind.ok:
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case _ChipKind.bad:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        break;
      case _ChipKind.corrected:
        bg = AppColors.successLight;
        fg = AppColors.success;
        icon = Icons.edit_rounded;
        break;
      case _ChipKind.info:
        bg = const Color(0xFFDCEEFF);
        fg = const Color(0xFF0B6BC2);
        break;
      case _ChipKind.neutral:
        bg = AppColors.surface;
        fg = AppColors.textSecondary;
        break;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            spec.label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: fg),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score breakdown — transparent rubric math (AI's view)
// ---------------------------------------------------------------------------

class _ScoreBreakdownRow extends StatelessWidget {
  final Map<String, dynamic> breakdown;
  const _ScoreBreakdownRow({required this.breakdown});

  int _v(String k) => (breakdown[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final parts =
        'Wajah +${_v('face')} · Seragam +${_v('uniform')} · '
        'Rambut +${_v('hair')} · Foto +${_v('photo')}';
    final max = (breakdown['max'] as num?)?.toInt() ?? 10;
    final total = (breakdown['total'] as num?)?.toInt() ?? _v('face') + _v('uniform') + _v('hair') + _v('photo');
    return Row(children: [
      const Icon(Icons.calculate_outlined,
          size: 13, color: AppColors.textMuted),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          '$parts = $total/$max',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600),
        ),
      ),
    ]);
  }
}

class _ExpandableReasoning extends StatefulWidget {
  final String text;
  const _ExpandableReasoning({required this.text});
  @override
  State<_ExpandableReasoning> createState() => _ExpandableReasoningState();
}

class _ExpandableReasoningState extends State<_ExpandableReasoning> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.psychology_outlined,
            size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            widget.text,
            maxLines: _expanded ? null : 2,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary),
          ),
        ),
        Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            size: 16, color: AppColors.textMuted),
      ]),
    );
  }
}

class _OverriddenBanner extends StatelessWidget {
  final GroomingRow row;
  const _OverriddenBanner({required this.row});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.verified_user_outlined,
            size: 14, color: AppColors.accentDark),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Dikoreksi admin${row.qcOverriddenAt != null ? ' · ${GroomingCard._fmtTime(row.qcOverriddenAt!)}' : ''}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentDark),
            ),
            if ((row.qcOverrideNote ?? '').isNotEmpty)
              Text(
                row.qcOverrideNote!,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.accentDark),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  const _Thumbnail({required this.url, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: url.isEmpty ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: url.isEmpty
            ? Container(
                width: 96,
                height: 128,
                color: AppColors.surface,
                child: const Icon(Icons.no_photography_outlined,
                    color: AppColors.textSecondary))
            : CachedNetworkImage(
                imageUrl: url,
                width: 96,
                height: 128,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                    width: 96,
                    height: 128,
                    color: AppColors.surface,
                    child: const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.primary))),
                errorWidget: (_, __, ___) => Container(
                    width: 96,
                    height: 128,
                    color: AppColors.surface,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.textSecondary)),
              ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final GroomingRow row;
  const _ScorePill({required this.row});
  @override
  Widget build(BuildContext context) {
    final value = row.effectiveScore;
    Color bg;
    Color fg;
    if (value == null) {
      bg = AppColors.surface;
      fg = AppColors.textSecondary;
    } else if (value >= 7) {
      bg = AppColors.successLight;
      fg = AppColors.success;
    } else if (value >= 5) {
      bg = const Color(0xFFFFF4D6);
      fg = const Color(0xFFB75D00);
    } else {
      bg = AppColors.dangerLight;
      fg = AppColors.danger;
    }
    final overridden = row.isOverridden;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      DecoratedBox(
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (overridden) ...[
              const Icon(Icons.edit_rounded, size: 12),
              const SizedBox(width: 3),
            ],
            Text(
              value == null ? '-' : value.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900, color: fg),
            ),
          ]),
        ),
      ),
      if (overridden && row.groomingScore != null) ...[
        const SizedBox(height: 2),
        Text(
          'AI: ${row.groomingScore!.toStringAsFixed(1)}',
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted),
        ),
      ],
    ]);
  }
}
