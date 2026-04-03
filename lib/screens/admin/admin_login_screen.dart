import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/admin_session_claims.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../main.dart' show supabaseReady;
import '../../providers/app_provider.dart';
import '../../services/biometric_service.dart';

bool canUseBiometricLogin({
  required bool hasBiometricHardware,
  required bool biometricEnabled,
  required bool hasTrustedAdminSession,
}) {
  return hasBiometricHardware && biometricEnabled && hasTrustedAdminSession;
}

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  // Biometric state
  bool _rememberMe = false;
  bool _hasBiometric = false;
  bool _biometricAutoTriggered = false;
  bool _showBiometricLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAndAutoTrigger();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAndAutoTrigger() async {
    final hasBio = await BiometricService.isAvailable();
    if (mounted) setState(() => _hasBiometric = hasBio);

    final prefs = await SharedPreferences.getInstance();
    final bioEnabled = prefs.getBool(AppConstants.biometricEnabledKey) ?? false;

    // Biometric auto-login only applies when the current session still carries
    // a trusted privileged claim from app_metadata.
    var hasTrustedAdminSession = false;
    try {
      if (!supabaseReady) return;
      final session = Supabase.instance.client.auth.currentSession;
      hasTrustedAdminSession =
          AdminSessionClaims.fromUser(session?.user) != null;
    } catch (_) {
      return;
    }

    if (!canUseBiometricLogin(
      hasBiometricHardware: hasBio,
      biometricEnabled: bioEnabled,
      hasTrustedAdminSession: hasTrustedAdminSession,
    )) {
      return;
    }

    if (!mounted || _biometricAutoTriggered) return;
    _biometricAutoTriggered = true;
    await _triggerBiometricLogin();
  }

  Future<void> _triggerBiometricLogin() async {
    setState(() => _showBiometricLoading = true);
    final success = await BiometricService.authenticate();
    if (!mounted) return;

    if (success) {
      if (!supabaseReady) {
        setState(() => _showBiometricLoading = false);
        return;
      }

      final claims = AdminSessionClaims.fromUser(
        Supabase.instance.client.auth.currentSession?.user,
      );
      if (claims == null) {
        ref.read(appProvider.notifier).clearAdminSessionMode();
        setState(() => _showBiometricLoading = false);
        return;
      }

      ref.read(appProvider.notifier).applyAdminSessionClaims(claims);
      // Router redirect will handle navigation to dashboard
    } else {
      setState(() => _showBiometricLoading = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!supabaseReady) {
        setState(() {
          _error = 'Tidak dapat terhubung ke server. Periksa koneksi internet.';
          _loading = false;
        });
        return;
      }

      final res = await Supabase.instance.client.auth
          .signInWithPassword(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('timeout'),
          );

      final user = res.session?.user;
      final claims = AdminSessionClaims.fromUser(user);

      // Hanya admin dan kepala_gerai yang boleh masuk dashboard
      if (claims == null) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          setState(() {
            _error = 'Akun ini tidak memiliki akses dashboard';
            _loading = false;
          });
        }
        return;
      }

      if (mounted) setState(() => _loading = false);

      // First-login: force password change for accounts flagged with
      // must_change_password in app_metadata (set by create-admin-user).
      final mustChange =
          user?.appMetadata['must_change_password'] == true;

      // Apply claims WITH the mustChangePassword flag so GoRouter handles
      // the redirect declaratively (no race with onAuthStateChange listener).
      ref.read(appProvider.notifier).applyAdminSessionClaims(
            claims,
            mustChangePassword: mustChange,
          );

      // GoRouter will redirect to /admin/change-password if mustChange,
      // or /admin/dashboard otherwise. No imperative Navigator.push needed.

      // Save biometric preference if "Ingat saya" is checked
      if (_rememberMe && _hasBiometric) {
        await ref.read(appProvider.notifier).setBiometricEnabled(true);
      }

      // Router akan redirect ke /admin/dashboard otomatis
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e, stack) {
      if (mounted) {
        final msg = e.toString();
        setState(() {
          // Tampilkan error detail untuk memudahkan debugging
          _error = msg.contains('timeout')
              ? 'Koneksi timeout. Periksa internet lalu coba lagi.'
              : 'ERROR: $msg\n\n${stack.toString().split('\n').take(6).join('\n')}';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // Logo / brand
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Halo, Akmal \u{1F44B}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Masuk untuk mengelola Ayam Guling Enakko',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 40),

                // Biometric loading state OR form
                if (_showBiometricLoading)
                  Column(
                    children: [
                      const SizedBox(height: 40),
                      const Icon(Icons.fingerprint,
                          size: 48, color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Memverifikasi...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () =>
                            setState(() => _showBiometricLoading = false),
                        child: const Text(
                          'Gunakan email & password',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                  )
                else ...[
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email wajib diisi';
                            }
                            final emailRegExp =
                                RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegExp.hasMatch(v.trim())) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password wajib diisi';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _login(),
                        ),
                      ],
                    ),
                  ),

                  // "Ingat saya" checkbox (only if device has biometric hardware)
                  if (_hasBiometric) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (v) =>
                                  setState(() => _rememberMe = v ?? false),
                              activeColor: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ingat saya di perangkat ini',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.danger.withOpacity(0.3)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],

                  // Biometric button (only if device has biometric + biometric is enabled)
                  if (_hasBiometric &&
                      ref.watch(appProvider).biometricEnabled) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _triggerBiometricLogin,
                        icon: const Icon(Icons.fingerprint,
                            size: 24, color: AppColors.primary),
                        label: const Text('Masuk dengan Sidik Jari'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Masuk'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
