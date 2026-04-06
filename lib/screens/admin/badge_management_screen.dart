import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../core/theme.dart';
import '../../models/employee.dart';
import '../../models/employee_badge.dart';
import '../../services/badge_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/badge_avatar.dart';
import '../../widgets/shimmer_skeleton.dart';

// ---------------------------------------------------------------------------
// Badge Management Screen -- full CRUD for badge definitions
// ---------------------------------------------------------------------------

class BadgeManagementScreen extends StatefulWidget {
  const BadgeManagementScreen({super.key});

  // ── Static badge picker for assigning/removing badge from employee ──────
  static Future<bool> showBadgePicker(
    BuildContext context, {
    required Employee employee,
  }) async {
    bool changed = false;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _BadgePickerSheet(
          employee: employee,
          onChanged: () {
            changed = true;
          },
        );
      },
    );
    return changed;
  }

  @override
  State<BadgeManagementScreen> createState() => _BadgeManagementScreenState();
}

class _BadgeManagementScreenState extends State<BadgeManagementScreen> {
  List<EmployeeBadge> _badges = [];
  bool _loading = true;

  String _colorToHex(Color color) {
    final rgbHex =
        color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    return '#${rgbHex.toUpperCase()}';
  }

  Color _safeParseHex(
    String hex, {
    Color fallback = const Color(0xFF9CA3AF),
  }) {
    final cleaned = hex.replaceAll('#', '').trim().toUpperCase();
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    final value =
        normalized.length == 8 ? int.tryParse(normalized, radix: 16) : null;
    return value != null ? Color(value) : fallback;
  }

  Widget _buildColorPickerField({
    required BuildContext dialogContext,
    required String label,
    required Color currentColor,
    required ValueChanged<Color> onColorSelected,
    required StateSetter setDialogState,
  }) {
    return BadgeColorPickerField(
      label: label,
      currentColor: currentColor,
      onColorSelected: (color) {
        onColorSelected(color);
        setDialogState(() {});
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() => _loading = true);
    try {
      _badges = await BadgeService.instance.fetchAll(forceRefresh: true);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.error(context, 'Gagal memuat badges: $e');
      }
    }
  }

  Future<void> _showBadgeForm({EmployeeBadge? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '');
    final color1Ctrl =
        TextEditingController(text: existing?.borderColor ?? '#FFD700');
    final color2Ctrl =
        TextEditingController(text: existing?.borderColor2 ?? '');
    String selectedStyle = existing?.borderStyle ?? 'gradient';

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(existing != null ? 'Edit Badge' : 'Buat Badge Baru'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Preview
                  BadgeAvatar(
                    name: nameCtrl.text.isNotEmpty ? nameCtrl.text : 'A',
                    size: 56,
                    badge: EmployeeBadge(
                      id: '',
                      name: nameCtrl.text,
                      emoji: emojiCtrl.text,
                      borderColor: color1Ctrl.text.isNotEmpty
                          ? color1Ctrl.text
                          : '#9CA3AF',
                      borderColor2:
                          color2Ctrl.text.isNotEmpty ? color2Ctrl.text : null,
                      borderStyle: selectedStyle,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name field
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Badge',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  // Emoji field
                  TextField(
                    controller: emojiCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Emoji',
                      hintText: 'e.g. \u{1F3C6}',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _buildColorPickerField(
                    dialogContext: ctx,
                    label: 'Warna Utama',
                    currentColor: _safeParseHex(
                      color1Ctrl.text,
                      fallback: const Color(0xFFFFD700),
                    ),
                    onColorSelected: (color) {
                      color1Ctrl.text = _colorToHex(color);
                    },
                    setDialogState: setDialogState,
                  ),
                  if (selectedStyle == 'gradient') ...[
                    const SizedBox(height: 12),
                    _buildColorPickerField(
                      dialogContext: ctx,
                      label: 'Warna Gradient',
                      currentColor: _safeParseHex(
                        color2Ctrl.text,
                        fallback: const Color(0xFFFFA500),
                      ),
                      onColorSelected: (color) {
                        color2Ctrl.text = _colorToHex(color);
                      },
                      setDialogState: setDialogState,
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Style selector
                  DropdownButtonFormField<String>(
                    initialValue: selectedStyle,
                    decoration: const InputDecoration(
                      labelText: 'Style',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'solid', child: Text('Solid')),
                      DropdownMenuItem(
                          value: 'gradient', child: Text('Gradient')),
                      DropdownMenuItem(value: 'glow', child: Text('Glow')),
                    ],
                    onChanged: (v) => setDialogState(() {
                      if (v != null) selectedStyle = v;
                    }),
                  ),
                  const SizedBox(height: 12),
                  // Description field (optional)
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi (opsional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  try {
                    if (existing != null) {
                      await BadgeService.instance.updateBadge(
                        id: existing.id,
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim().isNotEmpty
                            ? descCtrl.text.trim()
                            : null,
                        emoji: emojiCtrl.text.trim(),
                        borderColor: color1Ctrl.text.trim(),
                        borderColor2: selectedStyle == 'gradient' &&
                                color2Ctrl.text.trim().isNotEmpty
                            ? color2Ctrl.text.trim()
                            : null,
                        borderStyle: selectedStyle,
                      );
                    } else {
                      await BadgeService.instance.createBadge(
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim().isNotEmpty
                            ? descCtrl.text.trim()
                            : null,
                        emoji: emojiCtrl.text.trim(),
                        borderColor: color1Ctrl.text.trim(),
                        borderColor2: selectedStyle == 'gradient' &&
                                color2Ctrl.text.trim().isNotEmpty
                            ? color2Ctrl.text.trim()
                            : null,
                        borderStyle: selectedStyle,
                      );
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx, true);
                  } catch (e) {
                    if (ctx.mounted) {
                      AppToast.error(ctx, 'Gagal menyimpan: $e');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(existing != null ? 'Perbarui' : 'Buat'),
              ),
            ],
          ),
        ),
      );

      if (result == true) {
        _loadBadges();
        if (mounted) {
          AppToast.success(
              context, existing != null ? 'Badge diperbarui' : 'Badge dibuat');
        }
      }
    } finally {
      nameCtrl.dispose();
      descCtrl.dispose();
      emojiCtrl.dispose();
      color1Ctrl.dispose();
      color2Ctrl.dispose();
    }
  }

  Future<void> _deleteBadge(EmployeeBadge badge) async {
    final assignedCount =
        await BadgeService.instance.getAssignedCount(badge.id);
    final warning = assignedCount > 0
        ? '\n\nBadge ini sedang dipakai oleh $assignedCount karyawan. Badge akan dihapus dari mereka.'
        : '';
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Badge?'),
        content: Text('Hapus badge "${badge.name}"?$warning'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await BadgeService.instance.deleteBadge(badge.id);
      _loadBadges();
      if (mounted) AppToast.success(context, 'Badge "${badge.name}" dihapus');
    } catch (e) {
      if (mounted) AppToast.error(context, 'Gagal menghapus: $e');
    }
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: const [
                  ShimmerSkeleton(width: 52, height: 52, borderRadius: 26),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerSkeleton(
                            width: 120, height: 14, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerSkeleton(width: 80, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  ShimmerSkeleton(width: 30, height: 30, borderRadius: 15),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _styleLabel(String style) {
    switch (style) {
      case 'gradient':
        return 'Gradient';
      case 'glow':
        return 'Glow';
      default:
        return 'Solid';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        title: const Text('Kelola Badge'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBadgeForm(),
        backgroundColor: AppColors.accent,
        foregroundColor: const Color(0xFF1A0A00),
        icon: const Icon(Icons.add),
        label: const Text(
          'Tambah Badge',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? _buildShimmer()
          : _badges.isEmpty
              ? const Center(
                  child: AppEmptyState(
                    icon: Icons.workspace_premium_outlined,
                    heading: 'Belum ada badge',
                    subtext: 'Buat badge pertama untuk karyawan',
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadBadges,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: _badges.length,
                    itemBuilder: (context, i) {
                      final badge = _badges[i];
                      return _BadgeDefinitionCard(
                        badge: badge,
                        styleLabel: _styleLabel(badge.borderStyle),
                        onEdit: () => _showBadgeForm(existing: badge),
                        onDelete: () => _deleteBadge(badge),
                      );
                    },
                  ),
                ),
    );
  }
}

class BadgeColorPickerField extends StatelessWidget {
  final String label;
  final Color currentColor;
  final ValueChanged<Color> onColorSelected;

  const BadgeColorPickerField({
    super.key,
    required this.label,
    required this.currentColor,
    required this.onColorSelected,
  });

  static String colorToHex(Color color) {
    final rgbHex =
        color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    return '#${rgbHex.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('badge-color-picker-field-$label'),
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Color tempColor = currentColor;
        showDialog<void>(
          context: context,
          builder: (pickerCtx) => StatefulBuilder(
            builder: (pickerCtx, setPickerState) => AlertDialog(
              title: Text(label),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: tempColor,
                  onColorChanged: (color) {
                    tempColor = color;
                    setPickerState(() {});
                    onColorSelected(color);
                  },
                  enableAlpha: false,
                  hexInputBar: true,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(pickerCtx),
                  child: const Text('Pilih'),
                ),
              ],
            ),
          ),
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Container(
              key: ValueKey('badge-color-picker-swatch-$label'),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                colorToHex(currentColor),
                key: ValueKey('badge-color-picker-hex-$label'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.color_lens_outlined,
              size: 18,
              color: Colors.grey.shade700,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge Definition Card -- used in the management list
// ---------------------------------------------------------------------------

class _BadgeDefinitionCard extends StatelessWidget {
  final EmployeeBadge badge;
  final String styleLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BadgeDefinitionCard({
    required this.badge,
    required this.styleLabel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Ring preview
          BadgeAvatar(
            name: badge.name.isNotEmpty ? badge.name : 'A',
            size: 44,
            badge: badge,
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (badge.emoji.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(badge.emoji,
                            style: const TextStyle(fontSize: 16)),
                      ),
                    Expanded(
                      child: Text(
                        badge.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        styleLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (badge.description != null &&
                        badge.description!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          badge.description!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Menu
          PopupMenuButton<String>(
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text('Edit Badge'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: AppColors.danger),
                    const SizedBox(width: 12),
                    const Text('Hapus Badge'),
                  ],
                ),
              ),
            ],
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(
                Icons.more_vert,
                size: 18,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge Picker Bottom Sheet -- for assigning/removing badge from employee
// ---------------------------------------------------------------------------

class _BadgePickerSheet extends StatefulWidget {
  final Employee employee;
  final VoidCallback onChanged;

  const _BadgePickerSheet({
    required this.employee,
    required this.onChanged,
  });

  @override
  State<_BadgePickerSheet> createState() => _BadgePickerSheetState();
}

class _BadgePickerSheetState extends State<_BadgePickerSheet> {
  List<EmployeeBadge> _badges = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    try {
      _badges = await BadgeService.instance.fetchAll();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assignBadge(String badgeId) async {
    setState(() => _saving = true);
    try {
      await BadgeService.instance.assignBadge(widget.employee.id, badgeId);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.error(context, 'Gagal assign badge: $e');
      }
    }
  }

  Future<void> _removeBadge() async {
    setState(() => _saving = true);
    try {
      await BadgeService.instance.unassignBadge(widget.employee.id);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.error(context, 'Gagal menghapus badge: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBadgeId = widget.employee.activeBadgeId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium,
                  size: 22, color: Color(0xFFF59E0B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Assign Badge - ${widget.employee.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),

        // Loading or content
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_saving)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('Menyimpan...',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          )
        else
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Badge list
                ..._badges.map((badge) {
                  final isActive = activeBadgeId == badge.id;
                  return ListTile(
                    leading: BadgeAvatar(
                      name: badge.name.isNotEmpty ? badge.name : 'A',
                      size: 40,
                      badge: badge,
                    ),
                    title: Row(
                      children: [
                        if (badge.emoji.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(badge.emoji,
                                style: const TextStyle(fontSize: 16)),
                          ),
                        Expanded(
                          child: Text(
                            badge.name,
                            style: TextStyle(
                              fontWeight:
                                  isActive ? FontWeight.w800 : FontWeight.w600,
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: isActive
                        ? const Icon(Icons.check_circle,
                            color: AppColors.success, size: 24)
                        : null,
                    onTap: isActive ? null : () => _assignBadge(badge.id),
                  );
                }),

                // Divider before remove option
                if (activeBadgeId != null && activeBadgeId.isNotEmpty) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.dangerLight,
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.remove_circle_outline,
                          color: AppColors.danger, size: 20),
                    ),
                    title: const Text(
                      'Hapus Badge',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                    onTap: _removeBadge,
                  ),
                ],

                // Empty state
                if (_badges.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: AppEmptyState(
                      icon: Icons.workspace_premium_outlined,
                      heading: 'Belum ada badge',
                      subtext:
                          'Buat badge terlebih dahulu dari menu Kelola Badge',
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
