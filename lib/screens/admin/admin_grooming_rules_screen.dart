import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/grooming_rules_config_service.dart';

/// Admin "Aturan AI" editor — edits the JSONB rule config the
/// analyze-attendance-photo edge function reads at runtime. This is the
/// improvement surface: admins curate the label vocabulary, thresholds,
/// weights, and custom flagged-label rules so AI scoring adapts over time.
class AdminGroomingRulesScreen extends StatefulWidget {
  const AdminGroomingRulesScreen({super.key});

  @override
  State<AdminGroomingRulesScreen> createState() =>
      _AdminGroomingRulesScreenState();
}

class _LabelCategory {
  final String key;
  final String title;
  final String hint;
  const _LabelCategory(this.key, this.title, this.hint);
}

const _labelCategories = <_LabelCategory>[
  _LabelCategory('uniform', 'Seragam (label dianggap sah)',
      'Label Cloud Vision yang berarti karyawan pakai seragam/atasan.'),
  _LabelCategory('wrong_attire', 'Pakaian terlarang',
      'Tank top, singlet, dll → dinilai pakaian salah.'),
  _LabelCategory('long_hair', 'Rambut panjang (dilarang)',
      'Sinyal rambut panjang. Ditandai pelanggaran, admin bisa override.'),
  _LabelCategory('short_hair_ok', 'Rambut pendek (OK)',
      'Sinyal rambut pendek — membatalkan tuduhan rambut panjang.'),
  _LabelCategory('messy_hair', 'Rambut acak', ''),
  _LabelCategory('beard', 'Jenggot', ''),
  _LabelCategory('mustache', 'Kumis', ''),
  _LabelCategory('stubble', 'Bulu wajah', ''),
  _LabelCategory('hijab', 'Hijab / kerudung', ''),
  _LabelCategory('cap', 'Topi', ''),
  _LabelCategory('other_head_covering', 'Penutup kepala lain', ''),
  _LabelCategory('blurry', 'Foto buram', ''),
  _LabelCategory('dark', 'Foto gelap', ''),
  _LabelCategory('overexposed', 'Foto silau', ''),
];

const _weightKeys = <String, String>{
  'face': 'Wajah bersih',
  'uniform': 'Seragam',
  'hair': 'Rambut',
  'photo': 'Kualitas foto',
};

const _thresholdKeys = <String, String>{
  'min_label_score': 'Ambang label umum',
  'min_uniform_label_score': 'Ambang label seragam',
  'min_face_confidence': 'Ambang deteksi wajah',
};

const _criterionVerdicts = <String, List<String>>{
  'face_clean_shave': ['ok', 'stubble', 'mustache', 'beard', 'unclear'],
  'uniform_compliant': ['ok', 'no_uniform', 'wrong_attire', 'unclear'],
  'hair_neat': ['ok', 'messy', 'not_visible'],
  'hair_length': ['ok', 'long', 'not_visible', 'unclear'],
  'head_covering': ['none', 'hijab', 'cap', 'other'],
};

class _AdminGroomingRulesScreenState extends State<AdminGroomingRulesScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _version = 0;
  Map<String, dynamic> _config = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final active = await GroomingRulesConfigService.instance.fetchActive();
      final raw = active?.config ?? const {};
      // Deep, mutable copy so we can edit nested lists/maps freely.
      final copy = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      copy.putIfAbsent('thresholds', () => <String, dynamic>{});
      copy.putIfAbsent('weights', () => <String, dynamic>{});
      copy.putIfAbsent('label_sets', () => <String, dynamic>{});
      copy.putIfAbsent('flagged_labels', () => <dynamic>[]);
      setState(() {
        _config = copy;
        _version = active?.version ?? 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat aturan: $e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final newVersion = await GroomingRulesConfigService.instance
          .save(_config, note: 'Diubah dari aplikasi admin');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _version = newVersion;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aturan AI disimpan (versi $newVersion)')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: AppColors.danger),
      );
    }
  }

  Map<String, dynamic> get _labelSets =>
      (_config['label_sets'] as Map).cast<String, dynamic>();
  Map<String, dynamic> get _weights =>
      (_config['weights'] as Map).cast<String, dynamic>();
  Map<String, dynamic> get _thresholds =>
      (_config['thresholds'] as Map).cast<String, dynamic>();
  List<dynamic> get _flagged => _config['flagged_labels'] as List<dynamic>;

  List<String> _terms(String cat) =>
      ((_labelSets[cat] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();

  void _addTerm(String cat, String term) {
    final t = term.trim().toLowerCase();
    if (t.isEmpty) return;
    final current = _terms(cat);
    if (current.contains(t)) return;
    setState(() => _labelSets[cat] = [...current, t]);
  }

  void _removeTerm(String cat, String term) {
    setState(() =>
        _labelSets[cat] = _terms(cat).where((e) => e != term).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Aturan AI'),
        actions: [
          if (_version > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('v$_version',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ),
          IconButton(
            tooltip: 'Simpan',
            onPressed: (_loading || _saving) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  children: [
                    _intro(),
                    const SizedBox(height: 16),
                    _section('Bobot skor (total maks 10)'),
                    _weightsCard(),
                    const SizedBox(height: 16),
                    _section('Ambang kepercayaan deteksi'),
                    _thresholdsCard(),
                    const SizedBox(height: 16),
                    _section('Kosakata label AI'),
                    ..._labelCategories.map(_labelCategoryTile),
                    const SizedBox(height: 16),
                    _section('Aturan kustom (label → pelanggaran)'),
                    _flaggedCard(),
                  ],
                ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Simpan aturan'),
            ),
    );
  }

  Widget _intro() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.auto_fix_high_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Atur bagaimana AI menilai foto. Perubahan langsung dipakai '
              'untuk foto berikutnya (tanpa update aplikasi).',
              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
            ),
          ),
        ]),
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary,
                letterSpacing: 0.5)),
      );

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(12),
        child: child,
      );

  Widget _weightsCard() {
    return _card(
      child: Column(
        children: _weightKeys.entries.map((e) {
          final value = (_weights[e.key] as num?)?.toInt() ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(
                  child: Text(e.value,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
              IconButton(
                onPressed: value <= 0
                    ? null
                    : () => setState(() => _weights[e.key] = value - 1),
                icon: const Icon(Icons.remove_circle_outline),
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(
                width: 24,
                child: Text('$value',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              IconButton(
                onPressed: value >= 5
                    ? null
                    : () => setState(() => _weights[e.key] = value + 1),
                icon: const Icon(Icons.add_circle_outline),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _thresholdsCard() {
    return _card(
      child: Column(
        children: _thresholdKeys.entries.map((e) {
          final value = ((_thresholds[e.key] as num?)?.toDouble() ?? 0.5)
              .clamp(0.0, 1.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(e.value,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(value.toStringAsFixed(2),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary)),
              ]),
              Slider(
                value: value,
                min: 0,
                max: 1,
                divisions: 20,
                activeColor: AppColors.primary,
                label: value.toStringAsFixed(2),
                onChanged: (v) =>
                    setState(() => _thresholds[e.key] = double.parse(
                        v.toStringAsFixed(2))),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _labelCategoryTile(_LabelCategory cat) {
    final terms = _terms(cat.key);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(cat.title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13.5)),
          subtitle: Text('${terms.length} label',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          children: [
            if (cat.hint.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(cat.hint,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary)),
                ),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in terms)
                  Chip(
                    label: Text(t, style: const TextStyle(fontSize: 11.5)),
                    onDeleted: () => _removeTerm(cat.key, t),
                    deleteIconColor: AppColors.danger,
                    backgroundColor: AppColors.surface,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _AddTermField(onAdd: (t) => _addTerm(cat.key, t)),
          ],
        ),
      ),
    );
  }

  Widget _flaggedCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tambah aturan: jika label tertentu muncul, paksa sebuah '
            'kriteria jadi pelanggaran (mis. label "sunglasses" → seragam salah).',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          if (_flagged.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Belum ada aturan kustom.',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic)),
            ),
          for (int i = 0; i < _flagged.length; i++)
            _flaggedRow(i, Map<String, dynamic>.from(_flagged[i] as Map)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addFlagged,
            icon: const Icon(Icons.add),
            label: const Text('Tambah aturan'),
          ),
        ],
      ),
    );
  }

  Widget _flaggedRow(int index, Map<String, dynamic> rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('"${rule['label']}"',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                '${rule['criterion']} → ${rule['verdict']}'
                '${(rule['message'] ?? '').toString().isNotEmpty ? '  ·  ${rule['message']}' : ''}',
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _flagged.removeAt(index)),
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }

  Future<void> _addFlagged() async {
    final rule = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _FlaggedLabelDialog(),
    );
    if (rule != null) setState(() => _flagged.add(rule));
  }
}

class _AddTermField extends StatefulWidget {
  final ValueChanged<String> onAdd;
  const _AddTermField({required this.onAdd});
  @override
  State<_AddTermField> createState() => _AddTermFieldState();
}

class _AddTermFieldState extends State<_AddTermField> {
  final _controller = TextEditingController();

  void _submit() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    widget.onAdd(t);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Tambah label (mis. "ponytail")',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      const SizedBox(width: 8),
      IconButton.filled(
        onPressed: _submit,
        icon: const Icon(Icons.add),
      ),
    ]);
  }
}

class _FlaggedLabelDialog extends StatefulWidget {
  const _FlaggedLabelDialog();
  @override
  State<_FlaggedLabelDialog> createState() => _FlaggedLabelDialogState();
}

class _FlaggedLabelDialogState extends State<_FlaggedLabelDialog> {
  final _label = TextEditingController();
  final _message = TextEditingController();
  String _criterion = 'uniform_compliant';
  String _verdict = 'wrong_attire';

  @override
  void dispose() {
    _label.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verdicts = _criterionVerdicts[_criterion]!;
    return AlertDialog(
      title: const Text('Aturan kustom'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Label Cloud Vision',
              hintText: 'mis. sunglasses',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _criterion,
            decoration: const InputDecoration(
              labelText: 'Kriteria',
              border: OutlineInputBorder(),
            ),
            items: _criterionVerdicts.keys
                .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                .toList(),
            onChanged: (v) => setState(() {
              _criterion = v!;
              _verdict = _criterionVerdicts[_criterion]!.first;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: verdicts.contains(_verdict) ? _verdict : verdicts.first,
            decoration: const InputDecoration(
              labelText: 'Jadikan verdict',
              border: OutlineInputBorder(),
            ),
            items: verdicts
                .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                .toList(),
            onChanged: (v) => setState(() => _verdict = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            decoration: const InputDecoration(
              labelText: 'Pesan (opsional)',
              hintText: 'mis. Kacamata hitam tidak diizinkan',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final label = _label.text.trim().toLowerCase();
            if (label.isEmpty) return;
            Navigator.pop(context, <String, dynamic>{
              'label': label,
              'criterion': _criterion,
              'verdict': _verdict,
              if (_message.text.trim().isNotEmpty) 'message': _message.text.trim(),
            });
          },
          child: const Text('Tambah'),
        ),
      ],
    );
  }
}
