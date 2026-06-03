import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/outlet_manager_service.dart';

/// Admin screen to reassign a kepala gerai / area supervisor to a different
/// outlet (their "wilayah") when they relocate. Updates the manager login's
/// scope in auth metadata via admin_reassign_outlet_manager.
class AdminOutletManagersScreen extends StatefulWidget {
  const AdminOutletManagersScreen({super.key});

  @override
  State<AdminOutletManagersScreen> createState() =>
      _AdminOutletManagersScreenState();
}

class _AdminOutletManagersScreenState
    extends State<AdminOutletManagersScreen> {
  bool _loading = true;
  String? _error;
  List<OutletManager> _managers = const [];
  Map<String, OutletOption> _outletsById = const {};
  List<OutletOption> _outlets = const [];
  String _query = '';

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
      final managers = await OutletManagerService.instance.listManagers();
      final outlets = await OutletManagerService.instance.listOutlets();
      if (!mounted) return;
      setState(() {
        _managers = managers;
        _outlets = outlets;
        _outletsById = {for (final o in outlets) o.id: o};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data: $e';
        _loading = false;
      });
    }
  }

  String _outletName(String id) => _outletsById[id]?.name ?? '(outlet tak dikenal)';

  String _currentOutletsLabel(OutletManager m) {
    final ids = m.effectiveOutletIds;
    if (ids.isEmpty) return 'Belum ada gerai';
    return ids.map(_outletName).join(', ');
  }

  List<OutletManager> get _filtered {
    if (_query.trim().isEmpty) return _managers;
    final q = _query.toLowerCase();
    return _managers
        .where((m) =>
            m.email.toLowerCase().contains(q) ||
            _currentOutletsLabel(m).toLowerCase().contains(q))
        .toList();
  }

  Future<void> _openReassign(OutletManager m) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReassignSheet(
        manager: m,
        outlets: _outlets,
        outletName: _outletName,
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      await OutletManagerService.instance
          .reassign(userId: m.userId, outletIds: result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${m.email} dipindahkan. Berlaku setelah login ulang.'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Kepala Gerai & Wilayah'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  children: [
                    _infoBanner(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Cari email atau gerai…',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) =>
                            _managerCard(_filtered[i]),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _infoBanner() => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.accentDark),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Pindahkan kepala gerai ke gerai lain saat ia pindah tugas. '
              'Perubahan berlaku setelah ia login ulang di aplikasi.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
            ),
          ),
        ]),
      );

  Widget _managerCard(OutletManager m) {
    final isAS = m.isAreaSupervisor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Row(children: [
          Expanded(
            child: Text(m.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isAS ? const Color(0xFFDBEAFE) : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isAS ? 'Area Supervisor' : 'Kepala Gerai',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isAS
                      ? const Color(0xFF1E40AF)
                      : AppColors.primary),
            ),
          ),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            const Icon(Icons.store_outlined,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _currentOutletsLabel(m),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ]),
        ),
        trailing: const Icon(Icons.drive_file_move_outline,
            color: AppColors.primary),
        onTap: () => _openReassign(m),
      ),
    );
  }
}

class _ReassignSheet extends StatefulWidget {
  final OutletManager manager;
  final List<OutletOption> outlets;
  final String Function(String id) outletName;
  const _ReassignSheet({
    required this.manager,
    required this.outlets,
    required this.outletName,
  });

  @override
  State<_ReassignSheet> createState() => _ReassignSheetState();
}

class _ReassignSheetState extends State<_ReassignSheet> {
  late Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.manager.effectiveOutletIds.toSet();
  }

  bool get _multi => widget.manager.isAreaSupervisor;

  List<OutletOption> get _filtered {
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.outlets
        : widget.outlets
            .where((o) => o.name.toLowerCase().contains(q))
            .toList();
    return list;
  }

  void _toggle(String id) {
    setState(() {
      if (_multi) {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      } else {
        _selected = {id};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _multi
                          ? 'Pilih gerai yang dikelola'
                          : 'Pindahkan ke gerai',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(widget.manager.email,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Cari gerai…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final o = _filtered[i];
                    final selected = _selected.contains(o.id);
                    return ListTile(
                      onTap: () => _toggle(o.id),
                      leading: _multi
                          ? Checkbox(
                              value: selected,
                              onChanged: (_) => _toggle(o.id),
                            )
                          : Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                      title: Text(o.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: o.isActive
                          ? null
                          : const Text('Non-aktif',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.danger)),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.of(context)
                              .pop(_selected.toList(growable: false)),
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_multi
                          ? 'Simpan ${_selected.length} gerai'
                          : 'Pindahkan'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
