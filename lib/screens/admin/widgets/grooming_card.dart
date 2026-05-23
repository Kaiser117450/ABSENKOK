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
              Row(children: [
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
                _CleanShaveChip(value: row.faceCleanShave),
                _UniformChip(value: row.uniformCompliant),
                _HairChip(value: row.hairNeat),
                _HeadCoveringChip(value: row.headCovering),
              ]),
              if ((row.reasoning ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  row.reasoning!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              Row(children: [
                TextButton.icon(
                  onPressed: onTapOverride,
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Override skor'),
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
    final overridden = row.qcOverrideScore != null;
    final label = value == null
        ? '-'
        : overridden
            ? '${row.groomingScore?.toStringAsFixed(1) ?? '-'}→${value.toStringAsFixed(1)} ✏'
            : value.toStringAsFixed(1);
    return DecoratedBox(
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900, color: fg)),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  const _Chip(
      {required this.label,
      required this.background,
      required this.foreground});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: foreground)),
        ),
      );
}

class _CleanShaveChip extends StatelessWidget {
  final String? value;
  const _CleanShaveChip({required this.value});
  @override
  Widget build(BuildContext context) {
    String label;
    bool bad = false;
    switch (value) {
      case 'ok':
        label = 'Wajah OK';
        break;
      case 'stubble':
        label = 'Bulu wajah';
        bad = true;
        break;
      case 'mustache':
        label = 'Kumis';
        bad = true;
        break;
      case 'beard':
        label = 'Jenggot';
        bad = true;
        break;
      default:
        label = 'Wajah ?';
    }
    return _Chip(
      label: label,
      background: bad ? AppColors.dangerLight : AppColors.surface,
      foreground: bad ? AppColors.danger : AppColors.textSecondary,
    );
  }
}

class _UniformChip extends StatelessWidget {
  final String? value;
  const _UniformChip({required this.value});
  @override
  Widget build(BuildContext context) {
    String label;
    bool bad = false;
    switch (value) {
      case 'ok':
        label = 'Seragam OK';
        break;
      case 'no_uniform':
        label = 'Tanpa seragam';
        bad = true;
        break;
      case 'wrong_attire':
        label = 'Pakaian salah';
        bad = true;
        break;
      default:
        label = 'Seragam ?';
    }
    return _Chip(
      label: label,
      background: bad ? AppColors.dangerLight : AppColors.surface,
      foreground: bad ? AppColors.danger : AppColors.textSecondary,
    );
  }
}

class _HairChip extends StatelessWidget {
  final String? value;
  const _HairChip({required this.value});
  @override
  Widget build(BuildContext context) {
    String label;
    bool bad = false;
    switch (value) {
      case 'ok':
        label = 'Rambut OK';
        break;
      case 'not_visible':
        label = 'Rambut tertutup';
        break;
      case 'messy':
        label = 'Rambut acak';
        bad = true;
        break;
      default:
        label = 'Rambut ?';
    }
    return _Chip(
      label: label,
      background: bad ? AppColors.dangerLight : AppColors.surface,
      foreground: bad ? AppColors.danger : AppColors.textSecondary,
    );
  }
}

class _HeadCoveringChip extends StatelessWidget {
  final String? value;
  const _HeadCoveringChip({required this.value});
  @override
  Widget build(BuildContext context) {
    String label;
    switch (value) {
      case 'hijab':
        label = 'Hijab';
        break;
      case 'cap':
        label = 'Topi';
        break;
      case 'other':
        label = 'Penutup lain';
        break;
      default:
        label = 'Tanpa penutup';
    }
    final blue = value == 'hijab';
    return _Chip(
      label: label,
      background: blue ? const Color(0xFFDCEEFF) : AppColors.surface,
      foreground: blue ? const Color(0xFF0B6BC2) : AppColors.textSecondary,
    );
  }
}
