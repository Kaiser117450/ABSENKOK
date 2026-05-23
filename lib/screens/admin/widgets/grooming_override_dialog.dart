import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/grooming_qc_service.dart';

class GroomingOverrideDialog extends StatefulWidget {
  final GroomingRow row;
  const GroomingOverrideDialog({super.key, required this.row});

  @override
  State<GroomingOverrideDialog> createState() =>
      _GroomingOverrideDialogState();
}

class _GroomingOverrideDialogState extends State<GroomingOverrideDialog> {
  late double _score;
  final TextEditingController _note = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _score = widget.row.qcOverrideScore ?? widget.row.groomingScore ?? 5.0;
  }

  bool get _canSubmit => _note.text.trim().length >= 10 && !_submitting;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await GroomingQcService.instance.applyOverride(
        attendanceLogId: widget.row.attendanceLogId,
        score: _score,
        note: _note.text.trim(),
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
    return AlertDialog(
      title: Text('Override skor — ${widget.row.employeeName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Skor AI: ${widget.row.groomingScore?.toStringAsFixed(1) ?? '-'}'),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Skor admin:'),
            const SizedBox(width: 12),
            Expanded(
              child: Slider(
                value: _score,
                min: 0,
                max: 10,
                divisions: 20,
                label: _score.toStringAsFixed(1),
                onChanged: (v) => setState(() => _score = v),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                _score.toStringAsFixed(1),
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Alasan override (minimal 10 karakter)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
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
