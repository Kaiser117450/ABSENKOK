import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../services/admin_user_service.dart';

/// Admin-only screen: reset another privileged user's password. The server
/// generates a temporary password and flags the account so the user must
/// change it on next login. The new password is shown once for the admin to
/// relay (copy / WhatsApp).
class AdminResetPasswordScreen extends StatefulWidget {
  const AdminResetPasswordScreen({super.key});

  @override
  State<AdminResetPasswordScreen> createState() =>
      _AdminResetPasswordScreenState();
}

class _AdminResetPasswordScreenState extends State<AdminResetPasswordScreen> {
  final _service = AdminUserService();

  bool _loading = true;
  String? _error;
  List<AppUser> _users = const [];
  Map<String, String> _outletNameById = const {};
  String _query = '';
  String? _resettingUserId;

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

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
      final users = await _service.listAppUsers();
      final outletRows = await Supabase.instance.client
          .from('outlets')
          .select('id, name');
      final names = <String, String>{
        for (final o in (outletRows as List))
          (o['id'] ?? '').toString(): (o['name'] ?? '-').toString(),
      };
      if (!mounted) return;
      setState(() {
        _users = users;
        _outletNameById = names;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat daftar akun: '
            '${e.toString().replaceFirst('Exception: ', '')}';
        _loading = false;
      });
    }
  }

  String _outletsLabel(AppUser u) {
    final ids = u.effectiveOutletIds;
    if (ids.isEmpty) return u.isAdmin ? 'Semua gerai' : 'Belum ada gerai';
    return ids.map((id) => _outletNameById[id] ?? '(gerai)').join(', ');
  }

  List<AppUser> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users
        .where((u) =>
            u.email.toLowerCase().contains(q) ||
            u.name.toLowerCase().contains(q) ||
            u.roleLabel.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _confirmReset(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reset Password?'),
        content: Text(
          'Password untuk ${user.name} (${user.email}) akan diganti dengan '
          'password sementara. User WAJIB membuat password baru saat login '
          'berikutnya. Lanjutkan?',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _reset(user);
  }

  Future<void> _reset(AppUser user) async {
    setState(() => _resettingUserId = user.userId);
    try {
      final result = await _service.resetPassword(user.userId);
      if (!mounted) return;
      setState(() => _resettingUserId = null);
      await _showResultDialog(user, result);
      // Refresh so the "harus ganti password" badge updates.
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _resettingUserId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showResultDialog(
      AppUser user, ResetPasswordResult result) async {
    final shareText = 'Reset Password ABSENKOK\n\n'
        'Akun: ${user.roleLabel}\n'
        'Email: ${result.email}\n'
        'Password sementara: ${result.temporaryPassword}\n\n'
        'Silakan login dan segera buat password baru.';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 22),
          SizedBox(width: 8),
          Text('Password Direset'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user.name} (${result.email})',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            const Text('Password sementara:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                result.temporaryPassword,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'User wajib mengganti password ini saat login berikutnya.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                  ClipboardData(text: result.temporaryPassword));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Password disalin')),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Salin'),
          ),
          TextButton.icon(
            onPressed: () async {
              final encoded = Uri.encodeComponent(shareText);
              final wa = Uri.parse('whatsapp://send?text=$encoded');
              if (await canLaunchUrl(wa)) {
                await launchUrl(wa);
              } else {
                await Share.share(shareText, subject: 'Reset Password ABSENKOK');
              }
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Bagikan'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Reset Password Akun'),
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
                          hintText: 'Cari nama, email, atau peran…',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? const Center(child: Text('Tidak ada akun.'))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => _userCard(_filtered[i]),
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
        child: const Row(children: [
          Icon(Icons.lock_reset, color: AppColors.accentDark),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reset password user lain saat mereka lupa password. Sistem '
              'membuat password sementara — user wajib menggantinya saat login.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
            ),
          ),
        ]),
      );

  Widget _userCard(AppUser user) {
    final isSelf = _currentUserId != null && user.userId == _currentUserId;
    final busy = _resettingUserId == user.userId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Row(children: [
          Expanded(
            child: Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              user.roleLabel,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary),
            ),
          ),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                _outletsLabel(user),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              if (user.mustChangePassword)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    '• Menunggu ganti password',
                    style: TextStyle(fontSize: 11, color: AppColors.accentDark),
                  ),
                ),
            ],
          ),
        ),
        trailing: isSelf
            ? const Tooltip(
                message: 'Gunakan menu ganti password sendiri',
                child: Icon(Icons.person_rounded, color: AppColors.textMuted),
              )
            : busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primary),
                  )
                : IconButton(
                    tooltip: 'Reset password',
                    onPressed: () => _confirmReset(user),
                    icon: const Icon(Icons.lock_reset_rounded,
                        color: AppColors.primary),
                  ),
        onTap: isSelf || busy ? null : () => _confirmReset(user),
      ),
    );
  }
}
