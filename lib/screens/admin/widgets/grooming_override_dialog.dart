import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/grooming_qc_service.dart';

/// Override dialog where admin checks the AI's mistakes per criterion.
/// The score is auto-calculated from the corrected per-criterion values
/// using the same weights as the Cloud Vision rubric.
class GroomingOverrideDialog extends StatefulWidget {
  final GroomingRow row;
  const GroomingOverrideDialog({super.key, required this.row});

  @override
  State<GroomingOverrideDialog> createState() =>
      _GroomingOverrideDialogState();
}

class _GroomingOverrideDialogState extends State<GroomingOverrideDialog> {
  late final Map<String, bool> _corrections;
  final TextEditingController _note = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _corrections = {
      'face_clean_shave': widget.row.qcCorrections['face_clean_shave'] ?? false,
      'uniform_compliant':
          widget.row.qcCorrections['uniform_compliant'] ?? false,
      'hair_neat': widget.row.qcCorrections['hair_neat'] ?? false,
      'hair_length': widget.row.qcCorrections['hair_length'] ?? false,
    };
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _canSubmit => _note.text.trim().length >= 10 && !_submitting;

  double get _previewScore {
    double score = 0;
    final faceOk = _corrections['face_clean_shave'] == true ||
        widget.row.faceCleanShave == 'ok';
    final uniformOk = _corrections['uniform_compliant'] == true ||
        widget.row.uniformCompliant == 'ok';
    final hairNeatOk = _corrections['hair_neat'] == true ||
        widget.row.hairNeat == 'ok' ||
        widget.row.hairNeat == 'not_visible' ||
        widget.row.hairNeat == null;
    final hairLengthOk =
        _corrections['hair_length'] == true || widget.row.hairLength != 'long';
    if (faceOk) score += 3;
    if (uniformOk) score += 3;
    if (hairNeatOk && hairLengthOk) score += 3; // hair: neat AND not long
    if (widget.row.photoQuality == 'clear') score += 1;
    return score.clamp(0, 10).toDouble();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await GroomingQcService.instance.applyOverride(
        attendanceLogId: widget.row.attendanceLogId,
        score: _previewScore,
        note: _note.text.trim(),
        corrections: _corrections,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Gagal menyimpan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text('Koreksi penilaian — ${row.employeeName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Centang penilaian yang salah dari AI — skor dihitung ulang '
              'otomatis. Koreksi Anda disimpan sebagai masukan untuk '
              'memperbaiki AI.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            _CriterionRow(
              label: 'Wajah bersih',
              aiValue: row.faceCleanShave,
              aiBadValues: const {'beard', 'mustache', 'stubble'},
              aiBadLabels: const {
                'beard': 'AI menilai: Jenggot',
                'mustache': 'AI menilai: Kumis',
                'stubble': 'AI menilai: Bulu wajah',
              },
              correctionKey: 'face_clean_shave',
              corrections: _corrections,
              onChanged: (v) => setState(() {
                _corrections['face_clean_shave'] = v;
              }),
            ),
            _CriterionRow(
              label: 'Seragam',
              aiValue: row.uniformCompliant,
              aiBadValues: const {'no_uniform', 'wrong_attire'},
              aiBadLabels: const {
                'no_uniform': 'AI menilai: Tanpa seragam',
                'wrong_attire': 'AI menilai: Pakaian salah',
              },
              correctionKey: 'uniform_compliant',
              corrections: _corrections,
              onChanged: (v) => setState(() {
                _corrections['uniform_compliant'] = v;
              }),
            ),
            _CriterionRow(
              label: 'Rambut rapi',
              aiValue: row.hairNeat,
              aiBadValues: const {'messy'},
              aiBadLabels: const {'messy': 'AI menilai: Rambut acak'},
              correctionKey: 'hair_neat',
              corrections: _corrections,
              onChanged: (v) => setState(() {
                _corrections['hair_neat'] = v;
              }),
            ),
            if (row.hairLength == 'long' ||
                _corrections['hair_length'] == true)
              _CriterionRow(
                label: 'Panjang rambut',
                aiValue: row.hairLength,
                aiBadValues: const {'long'},
                aiBadLabels: const {'long': 'AI menilai: Rambut panjang'},
                correctionKey: 'hair_length',
                corrections: _corrections,
                onChanged: (v) => setState(() {
                  _corrections['hair_length'] = v;
                }),
              ),
            const SizedBox(height: 12),
            _ScorePreview(
              aiScore: row.groomingScore,
              correctedScore: _previewScore,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Alasan koreksi (minimal 10 karakter)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _CriterionRow extends StatelessWidget {
  final String label;
  final String? aiValue;
  final Set<String> aiBadValues;
  final Map<String, String> aiBadLabels;
  final String correctionKey;
  final Map<String, bool> corrections;
  final ValueChanged<bool> onChanged;

  const _CriterionRow({
    required this.label,
    required this.aiValue,
    required this.aiBadValues,
    required this.aiBadLabels,
    required this.correctionKey,
    required this.corrections,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final aiSaidBad = aiValue != null && aiBadValues.contains(aiValue);
    final correctedToOk = corrections[correctionKey] == true;

    // If AI judged this criterion as OK, just show it as approved (no toggle).
    if (!aiSaidBad) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text(
            '(AI menilai OK)',
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
        ]),
      );
    }

    final aiLabel = aiBadLabels[aiValue] ?? 'AI menandai bermasalah';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => onChanged(!correctedToOk),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
              value: correctedToOk,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        aiLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                          decoration: correctedToOk
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ]),
                  if (correctedToOk) ...[
                    const SizedBox(height: 4),
                    Text('→ Admin tandai OK (+3 poin)',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ScorePreview extends StatelessWidget {
  final double? aiScore;
  final double correctedScore;
  const _ScorePreview({required this.aiScore, required this.correctedScore});

  @override
  Widget build(BuildContext context) {
    final changed = aiScore != null && (aiScore! - correctedScore).abs() > 0.01;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: changed ? AppColors.successLight : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: changed
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(children: [
        const Icon(Icons.calculate_rounded,
            size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          'Skor:',
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(width: 6),
        if (aiScore != null) ...[
          Text(
            aiScore!.toStringAsFixed(1),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              decoration:
                  changed ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
          const SizedBox(width: 6),
          if (changed)
            const Icon(Icons.arrow_forward_rounded,
                size: 14, color: AppColors.textSecondary),
          if (changed) const SizedBox(width: 6),
        ],
        Text(
          correctedScore.toStringAsFixed(1),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: changed ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ]),
    );
  }
}
