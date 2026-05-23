import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../providers/grooming_filter_provider.dart';
import '../../../services/grooming_qc_service.dart';

class GroomingFilterSheet extends ConsumerStatefulWidget {
  final List<({String id, String name})> outlets;
  const GroomingFilterSheet({super.key, required this.outlets});

  @override
  ConsumerState<GroomingFilterSheet> createState() =>
      _GroomingFilterSheetState();
}

class _GroomingFilterSheetState extends ConsumerState<GroomingFilterSheet> {
  late _Range _range;
  late TextEditingController _query;
  late Set<String> _outletIds;
  late bool _needsReviewOnly;
  late bool _overriddenOnly;

  @override
  void initState() {
    super.initState();
    final f = ref.read(groomingFilterProvider);
    _range = _resolveRange(f);
    _query = TextEditingController(text: f.employeeQuery ?? '');
    _outletIds = Set.from(f.outletIds);
    _needsReviewOnly = f.needsReviewOnly;
    _overriddenOnly = f.overriddenOnly;
  }

  _Range _resolveRange(GroomingFilter f) {
    final days = f.until.difference(f.since).inDays;
    if (days <= 1) return _Range.today;
    if (days <= 7) return _Range.last7;
    return _Range.last30;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                  child: Text('Filter',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900))),
              IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 8),
            const Text('Rentang waktu',
                style: TextStyle(fontWeight: FontWeight.w800)),
            Wrap(
              spacing: 8,
              children: [
                for (final r in _Range.values)
                  ChoiceChip(
                    label: Text(_rangeLabel(r)),
                    selected: _range == r,
                    onSelected: (_) => setState(() => _range = r),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Outlet',
                style: TextStyle(fontWeight: FontWeight.w800)),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in widget.outlets)
                  FilterChip(
                    label: Text(o.name),
                    selected: _outletIds.contains(o.id),
                    onSelected: (_) {
                      setState(() {
                        if (!_outletIds.add(o.id)) _outletIds.remove(o.id);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Karyawan',
                style: TextStyle(fontWeight: FontWeight.w800)),
            TextField(
              controller: _query,
              decoration: const InputDecoration(
                  hintText: 'Cari nama…',
                  prefixIcon: Icon(Icons.search)),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _needsReviewOnly,
              onChanged: (v) => setState(() => _needsReviewOnly = v),
              title: const Text('Hanya butuh review'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile.adaptive(
              value: _overriddenOnly,
              onChanged: (v) => setState(() => _overriddenOnly = v),
              title: const Text('Hanya sudah di-override'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            Row(children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _range = _Range.last30;
                    _outletIds = {};
                    _query.clear();
                    _needsReviewOnly = false;
                    _overriddenOnly = false;
                  });
                },
                child: const Text('Reset'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  final now = DateTime.now();
                  final since = switch (_range) {
                    _Range.today =>
                      DateTime(now.year, now.month, now.day),
                    _Range.last7 =>
                      now.subtract(const Duration(days: 7)),
                    _Range.last30 =>
                      now.subtract(const Duration(days: 30)),
                  };
                  final notifier =
                      ref.read(groomingFilterProvider.notifier);
                  notifier.setRange(since: since, until: now);
                  notifier.setEmployeeQuery(_query.text.trim().isEmpty
                      ? null
                      : _query.text.trim());
                  notifier.setNeedsReviewOnly(_needsReviewOnly);
                  notifier.setOverriddenOnly(_overriddenOnly);
                  final current = ref.read(groomingFilterProvider);
                  final added = _outletIds.difference(current.outletIds);
                  final removed =
                      current.outletIds.difference(_outletIds);
                  for (final id in added.union(removed)) {
                    notifier.toggleOutlet(id);
                  }
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check),
                label: const Text('Terapkan'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

enum _Range { today, last7, last30 }

String _rangeLabel(_Range r) => switch (r) {
      _Range.today => 'Hari ini',
      _Range.last7 => '7 hari',
      _Range.last30 => '30 hari',
    };
