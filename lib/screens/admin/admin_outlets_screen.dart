
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:absensi_enakko_flutter/core/supabase_client.dart';
import 'package:absensi_enakko_flutter/core/theme.dart';
import 'package:absensi_enakko_flutter/models/outlet.dart';
import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';
import 'package:absensi_enakko_flutter/widgets/app_card.dart';
import 'package:absensi_enakko_flutter/widgets/app_empty_state.dart';
import 'package:absensi_enakko_flutter/widgets/app_toast.dart';
import 'package:absensi_enakko_flutter/widgets/outlet_mode_badge.dart';
import 'package:absensi_enakko_flutter/widgets/shimmer_skeleton.dart';

class AdminOutletsScreen extends ConsumerStatefulWidget {
  const AdminOutletsScreen({super.key});

  @override
  ConsumerState<AdminOutletsScreen> createState() => _AdminOutletsScreenState();
}

class _AdminOutletsScreenState extends ConsumerState<AdminOutletsScreen> {
  List<Outlet> _outlets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await SupabaseClientFactory.admin
          .from('outlets')
          .select('*')
          .order('name');
      if (mounted) {
        setState(() {
          _outlets = (data as List)
              .map((e) => Outlet.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _showOutletSheet(Outlet? existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OutletSheet(
        outlet: existing,
        onSaved: _loadOutlets,
      ),
    );
  }

  Future<void> _toggleActive(Outlet outlet) async {
    final newStatus = !outlet.isActive;
    final label = newStatus ? 'aktifkan' : 'nonaktifkan';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        title: Text(
          '${newStatus ? "Aktifkan" : "Nonaktifkan"} Gerai?',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          'Yakin ingin $label gerai "${outlet.name}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppColors.success : AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newStatus ? 'Aktifkan' : 'Nonaktifkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseClientFactory.admin
          .from('outlets')
          .update({'is_active': newStatus})
          .eq('id', outlet.id);
      await _loadOutlets();
      if (mounted) {
        AppToast.success(context, 'Gerai "${outlet.name}" berhasil di-$label');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Gagal: $e');
      }
    }
  }

  
  Widget _buildOutletShimmer() {
    return Column(
      children: List.generate(
        3,
        (index) => AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerSkeleton(width: 150, height: 18, borderRadius: 4),
                  ShimmerSkeleton(width: 40, height: 24, borderRadius: 12),
                ],
              ),
              SizedBox(height: 12),
              ShimmerSkeleton(width: double.infinity, height: 14, borderRadius: 4),
              SizedBox(height: 4),
              ShimmerSkeleton(width: 200, height: 14, borderRadius: 4),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _outlets.where((o) => o.isActive).length;
    final inactiveCount = _outlets.length - activeCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: Column(
        children: [
          // ── SUMMARY + ADD BUTTON ─────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                _MiniStat(label: 'Total', value: '${_outlets.length}', color: AppColors.primary),
                const SizedBox(width: 10),
                _MiniStat(label: 'Aktif', value: '$activeCount', color: AppColors.success),
                const SizedBox(width: 10),
                _MiniStat(label: 'Non-aktif', value: '$inactiveCount', color: AppColors.textMuted),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showOutletSheet(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 16, color: Color(0xFF1A0A00)),
                        SizedBox(width: 4),
                        Text(
                          'Tambah',
                          style: TextStyle(
                            color: Color(0xFF1A0A00),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

          // ── LIST ─────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? _buildOutletShimmer()
                : _error != null
                    ? _buildError()
                    : _outlets.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _loadOutlets,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                              itemCount: _outlets.length,
                              itemBuilder: (_, i) => _OutletCard(
                                outlet: _outlets[i],
                                onEdit: () => _showOutletSheet(_outlets[i]),
                                onToggle: () => _toggleActive(_outlets[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOutlets,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppEmptyState(
            icon: Icons.store_outlined,
            heading: 'Belum Ada Gerai',
            subtext: 'Tambahkan gerai untuk memulai',
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showOutletSheet(null),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tambah Gerai Pertama'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: const Color(0xFF1A0A00),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini stat pill
// ---------------------------------------------------------------------------
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Outlet Card
// ---------------------------------------------------------------------------
class _OutletCard extends StatelessWidget {
  final Outlet outlet;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _OutletCard({required this.outlet, required this.onEdit, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isActive = outlet.isActive;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left bar
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.textMuted,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),

            // Icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primaryLight
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.store_mall_directory_outlined,
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                  size: 22,
                ),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            outlet.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isActive
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutletModeBadge(mode: outlet.operatingMode),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.successLight
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isActive ? 'Aktif' : 'Non-aktif',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isActive
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (outlet.address != null &&
                        outlet.address!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 11, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              outlet.address!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (outlet.deviceId != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.smartphone_outlined,
                              size: 11, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            'Device terdaftar',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionBtn(
                    icon: Icons.edit_outlined,
                    color: AppColors.primary,
                    onTap: onEdit,
                  ),
                  const SizedBox(height: 6),
                  _ActionBtn(
                    icon: isActive
                        ? Icons.toggle_on_outlined
                        : Icons.toggle_off_outlined,
                    color: isActive ? AppColors.success : AppColors.textMuted,
                    onTap: onToggle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Outlet add / edit bottom sheet
// ---------------------------------------------------------------------------
class _OutletSheet extends StatefulWidget {
  final Outlet? outlet;
  final VoidCallback onSaved;

  const _OutletSheet({required this.outlet, required this.onSaved});

  @override
  State<_OutletSheet> createState() => _OutletSheetState();
}

class _OutletSheetState extends State<_OutletSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _newPasswordCtrl; // untuk reset password saat edit
  bool _isActive = true;
  late OutletOperatingMode _selectedMode;
  bool _saving = false;
  bool _obscure = true;
  bool _obscureNew = true;
  bool _showPasswordReset = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final o = widget.outlet;
    _nameCtrl = TextEditingController(text: o?.name ?? '');
    _addressCtrl = TextEditingController(text: o?.address ?? '');
    _passwordCtrl = TextEditingController();
    _newPasswordCtrl = TextEditingController();
    _isActive = o?.isActive ?? true;
    _selectedMode = o?.operatingMode ?? OutletOperatingMode.normal;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    try {
      final isEdit = widget.outlet != null;

      if (isEdit) {
        // Edit: update nama, alamat, status
        final payload = {
          'name': _nameCtrl.text.trim(),
          'address': _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          'is_active': _isActive,
          'operating_mode': _selectedMode.dbValue,
        };
        await SupabaseClientFactory.admin
            .from('outlets')
            .update(payload)
            .eq('id', widget.outlet!.id);

        // Jika user mengisi password baru → panggil RPC update_outlet_password
        final newPw = _newPasswordCtrl.text.trim();
        if (_showPasswordReset && newPw.isNotEmpty) {
          final result = await SupabaseClientFactory.admin.rpc(
            'update_outlet_password',
            params: {
              'outlet_id': widget.outlet!.id,
              'new_password': newPw,
            },
          );
          // Cek apakah RPC berhasil (defensive parse)
          if (result != null && result is Map) {
            final success = result['success'] as bool? ?? false;
            if (!success) {
              final errMsg = result['error'] as String? ?? 'Gagal update password';
              throw Exception(errMsg);
            }
          }
        }
      } else {
        // Create baru: nama, alamat, password (di-hash via RPC)
        final outletName = _nameCtrl.text.trim();
        final outletAddress = _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim();
        final password = _passwordCtrl.text;
        final createResult = await SupabaseClientFactory.admin.rpc(
          'create_outlet_with_password',
          params: {
            'outlet_name': outletName,
            'outlet_address': outletAddress,
            'password': password,
          },
        );
        await _persistCreatedOutletMode(
          createResult: createResult,
          outletName: outletName,
          selectedMode: _selectedMode,
        );
      }

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal menyimpan: ${e.toString()}';
          _saving = false;
        });
      }
    }
  }

  Future<void> _persistCreatedOutletMode({
    required dynamic createResult,
    required String outletName,
    required OutletOperatingMode selectedMode,
  }) async {
    if (selectedMode == OutletOperatingMode.normal) {
      return;
    }

    final outletId =
        _extractCreatedOutletId(createResult) ?? await _lookupCreatedOutletId(outletName);
    if (outletId == null) {
      throw Exception(
        'Gerai berhasil dibuat, tetapi mode operasi belum bisa dipastikan tersimpan.',
      );
    }

    await SupabaseClientFactory.admin.from('outlets').update({
      'operating_mode': selectedMode.dbValue,
    }).eq('id', outletId);
  }

  String? _extractCreatedOutletId(dynamic createResult) {
    if (createResult is String && createResult.isNotEmpty) {
      return createResult;
    }

    if (createResult is Map) {
      final id = createResult['id'] ??
          createResult['outlet_id'] ??
          createResult['outletId'];
      return id is String && id.isNotEmpty ? id : null;
    }

    if (createResult is List && createResult.isNotEmpty) {
      return _extractCreatedOutletId(createResult.first);
    }

    return null;
  }

  Future<String?> _lookupCreatedOutletId(String outletName) async {
    final data = await SupabaseClientFactory.admin
        .from('outlets')
        .select('id')
        .eq('name', outletName)
        .order('created_at', ascending: false)
        .limit(1);

    if (data.isEmpty) return null;

    final first = data.first;
    final id = first['id'];
    if (id is String && id.isNotEmpty) return id;

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.outlet != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit_outlined : Icons.store_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEdit ? 'Edit Gerai' : 'Tambah Gerai Baru',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Nama gerai
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nama Gerai',
                            hintText: 'Contoh: Outlet Pusat - Sudirman',
                            prefixIcon: Icon(Icons.store_outlined, size: 20),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Nama gerai wajib diisi' : null,
                        ),
                        const SizedBox(height: 14),

                        // Alamat
                        TextFormField(
                          controller: _addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Alamat (opsional)',
                            prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                          ),
                          maxLines: 2,
                          minLines: 1,
                        ),
                        const SizedBox(height: 14),

                        // Operating mode segmented control
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mode Operasi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                for (final m in OutletOperatingMode.values) ...[
                                  if (m.index > 0) const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _selectedMode = m),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _selectedMode == m
                                              ? AppColors.primary
                                              : AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: _selectedMode == m
                                                ? AppColors.primary
                                                : AppColors.border,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          m.label,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _selectedMode == m
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Mode 24 Jam akan digunakan untuk pengelompokan absensi shift malam.',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Password — hanya saat buat baru
                        if (!isEdit) ...[
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password Gerai',
                              hintText: 'Min. 6 karakter',
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Password wajib diisi';
                              if (v.length < 6) return 'Password minimal 6 karakter';
                              if (!RegExp(r'[0-9]').hasMatch(v)) return 'Password harus mengandung angka';
                              if (!RegExp(r'[a-zA-Z]').hasMatch(v)) return 'Password harus mengandung huruf';
                              return null;
                            },
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 14, color: Color(0xFFD97706)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Password ini digunakan karyawan untuk mengaktifkan kiosk di gerai tersebut.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Status toggle — saat edit
                        if (isEdit) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              title: const Text(
                                'Gerai Aktif',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: const Text(
                                'Gerai dapat digunakan kiosk',
                                style: TextStyle(fontSize: 12),
                              ),
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v),
                              activeThumbColor: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ── RESET PASSWORD SECTION ─────────────────────
                          GestureDetector(
                            onTap: () => setState(
                                () => _showPasswordReset = !_showPasswordReset),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _showPasswordReset
                                    ? AppColors.dangerLight
                                    : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _showPasswordReset
                                      ? AppColors.danger.withValues(alpha: 0.3)
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lock_reset_outlined,
                                    size: 18,
                                    color: _showPasswordReset
                                        ? AppColors.danger
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Atur Ulang Password Kiosk',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _showPasswordReset
                                            ? AppColors.danger
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _showPasswordReset
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 20,
                                    color: _showPasswordReset
                                        ? AppColors.danger
                                        : AppColors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Password baru — muncul saat _showPasswordReset == true
                          if (_showPasswordReset) ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _newPasswordCtrl,
                              obscureText: _obscureNew,
                              decoration: InputDecoration(
                                labelText: 'Password Baru',
                                hintText: 'Min. 6 karakter',
                                prefixIcon:
                                    const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureNew
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscureNew = !_obscureNew),
                                ),
                              ),
                              validator: (v) {
                                if (!_showPasswordReset) return null;
                                if (v == null || v.trim().isEmpty) {
                                  return 'Isi password baru atau tutup seksi ini';
                                }
                                if (v.trim().length < 6) {
                                  return 'Password minimal 6 karakter';
                                }
                                if (!RegExp(r'[0-9]').hasMatch(v)) return 'Password harus mengandung angka';
                                if (!RegExp(r'[a-zA-Z]').hasMatch(v)) return 'Password harus mengandung huruf';
                                return null;
                              },
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 14, color: Color(0xFFD97706)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Password baru akan menggantikan password lama. '
                                      'Perangkat kiosk yang sudah terdaftar TIDAK perlu setup ulang.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.danger, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.danger, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Note untuk create baru — SQL RPC
                  if (!isEdit)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.code_outlined,
                                  size: 14, color: AppColors.textSecondary),
                              SizedBox(width: 6),
                              Text(
                                'Catatan SQL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tombol "Simpan" memanggil RPC create_outlet_with_password. '
                            'Pastikan fungsi ini sudah dibuat di Supabase SQL Editor.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEdit ? AppColors.primary : AppColors.accent,
                        foregroundColor: isEdit ? Colors.white : const Color(0xFF1A0A00),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: isEdit ? Colors.white : const Color(0xFF1A0A00),
                              ),
                            )
                          : Text(
                              isEdit ? 'Simpan Perubahan' : '+ Tambah Gerai',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
