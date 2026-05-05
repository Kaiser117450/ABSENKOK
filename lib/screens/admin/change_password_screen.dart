import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/admin_session_claims.dart';
import '../../core/theme.dart';
import '../../main.dart' show supabaseReady;
import '../../providers/app_provider.dart';

// ---------------------------------------------------------------------------
// Password strength evaluation
// ---------------------------------------------------------------------------

enum PasswordStrength { weak, fair, strong, veryStrong }

PasswordStrength _evaluateStrength(String password) {
  int score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'[a-z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

  if (score <= 2) return PasswordStrength.weak;
  if (score <= 3) return PasswordStrength.fair;
  if (score <= 4) return PasswordStrength.strong;
  return PasswordStrength.veryStrong;
}

// ---------------------------------------------------------------------------
// ChangePasswordScreen
// ---------------------------------------------------------------------------

class ChangePasswordScreen extends ConsumerStatefulWidget {
  /// When [isFirstLogin] is true the user cannot navigate back and must
  /// create a new password before proceeding.
  const ChangePasswordScreen({super.key, this.isFirstLogin = false});

  final bool isFirstLogin;

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  PasswordStrength? _strength;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // Save logic
  // --------------------------------------------------

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      if (!supabaseReady) {
        throw Exception('Tidak dapat terhubung ke server.');
      }

      // 1. Update password via Supabase Auth
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordCtrl.text),
      );

      // 2. Clear the must_change_password flag via Edge Function
      //    (app_metadata cannot be updated from the client SDK)
      final res = await Supabase.instance.client.functions.invoke(
        'clear-must-change-password',
        body: {},
      );

      if (res.status != 200) {
        final data = res.data;
        final errorMsg = (data is Map && data['error'] != null)
            ? data['error']
            : 'Unknown error';
        throw Exception('Gagal menghapus flag: $errorMsg');
      }

      // 3. Refresh the session so the JWT carries the updated app_metadata
      await Supabase.instance.client.auth.refreshSession();

      // 4. Clear the mustChangePassword flag in AppState — this triggers
      //    GoRouter to redirect from /admin/change-password to /admin/dashboard.
      ref.read(appProvider.notifier).applyAdminSessionClaims(
            AdminSessionClaims.fromUser(
              Supabase.instance.client.auth.currentSession?.user,
            ),
            mustChangePassword: false,
          );

      // 4. Show success & navigate to dashboard
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password berhasil diubah!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // GoRouter redirect will handle navigation to /admin/dashboard
        // since mustChangePassword is now false.
        context.go('/admin/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah password: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --------------------------------------------------
  // UI helpers
  // --------------------------------------------------

  void _onPasswordChanged(String value) {
    setState(() {
      _strength = value.isEmpty ? null : _evaluateStrength(value);
    });
  }

  Color _strengthColor(PasswordStrength s) {
    switch (s) {
      case PasswordStrength.weak:
        return AppColors.danger;
      case PasswordStrength.fair:
        return const Color(0xFFF97316); // orange
      case PasswordStrength.strong:
        return AppColors.accent;
      case PasswordStrength.veryStrong:
        return AppColors.success;
    }
  }

  String _strengthLabel(PasswordStrength s) {
    switch (s) {
      case PasswordStrength.weak:
        return 'Lemah';
      case PasswordStrength.fair:
        return 'Cukup';
      case PasswordStrength.strong:
        return 'Kuat';
      case PasswordStrength.veryStrong:
        return 'Sangat Kuat';
    }
  }

  int _strengthIndex(PasswordStrength s) {
    switch (s) {
      case PasswordStrength.weak:
        return 1;
      case PasswordStrength.fair:
        return 2;
      case PasswordStrength.strong:
        return 3;
      case PasswordStrength.veryStrong:
        return 4;
    }
  }

  Widget _buildStrengthIndicator() {
    final active = _strength == null ? 0 : _strengthIndex(_strength!);
    final color =
        _strength == null ? AppColors.border : _strengthColor(_strength!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (i) {
            final filled = i < active;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: filled ? color : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        if (_strength != null) ...[
          const SizedBox(height: 6),
          Text(
            _strengthLabel(_strength!),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ],
    );
  }

  // --------------------------------------------------
  // Build
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Block back navigation for first-login flow
      canPop: !widget.isFirstLogin,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Buat Password Baru'),
          automaticallyImplyLeading: !widget.isFirstLogin,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.lock_reset,
                              size: 36,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Selamat Datang!',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Untuk keamanan akun Anda, silakan buat password baru sebelum melanjutkan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // New password
                  TextFormField(
                    controller: _newPasswordCtrl,
                    obscureText: _obscureNew,
                    onChanged: _onPasswordChanged,
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password baru wajib diisi';
                      }
                      if (v.length < 8) {
                        return 'Password minimal 8 karakter';
                      }
                      return null;
                    },
                  ),

                  // Strength indicator
                  _buildStrengthIndicator(),

                  const SizedBox(height: 16),

                  // Confirm password
                  TextFormField(
                    controller: _confirmPasswordCtrl,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Password Baru',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Konfirmasi password wajib diisi';
                      }
                      if (v != _newPasswordCtrl.text) {
                        return 'Password tidak cocok';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // Submit button
                  ElevatedButton(
                    onPressed: _saving ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Simpan Password Baru'),
                  ),

                  const SizedBox(height: 16),

                  // Hint text
                  const Text(
                    'Tips: Gunakan kombinasi huruf besar, huruf kecil, angka, dan simbol untuk password yang kuat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
