import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../main.dart' show supabaseReady;
import '../../models/kiosk_session.dart';
import '../../providers/app_provider.dart';
import '../../services/device_identity_service.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _outletNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _outletNameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Guard: Supabase must be initialized before making any RPC call
      if (!supabaseReady) {
        setState(() {
          _error = 'Tidak dapat terhubung ke server. Periksa koneksi internet lalu coba lagi.';
          _isLoading = false;
        });
        return;
      }

      final outletName = _outletNameCtrl.text.trim();
      final password = _passwordCtrl.text;

      // Verify password via Supabase RPC — server checks bcrypt hash.
      // Hard timeout of 15 s so the UI never blocks indefinitely (ANR fix).
      dynamic result;
      try {
        result = await Supabase.instance.client
            .rpc(
              'verify_kiosk_password',
              params: {
                'p_outlet_name': outletName,
                'p_password': password,
              },
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw Exception('timeout'),
            );
      } on Exception catch (e) {
        if (mounted) {
          setState(() {
            _error = e.toString().contains('timeout')
                ? 'Koneksi timeout. Periksa internet lalu coba lagi.'
                : 'RPC Error: ${e.toString()}';
            _isLoading = false;
          });
        }
        return;
      }

      // RPC returned null — function belum ada atau outlet tidak ditemukan
      if (result == null) {
        if (mounted) {
          setState(() {
            _error = 'Server tidak merespons. Pastikan RPC verify_kiosk_password sudah dibuat di Supabase.';
            _isLoading = false;
          });
        }
        return;
      }

      // Pastikan result adalah Map
      if (result is! Map) {
        if (mounted) {
          setState(() {
            _error = 'Format respons tidak valid: ${result.runtimeType} = $result';
            _isLoading = false;
          });
        }
        return;
      }

      final map = Map<String, dynamic>.from(result as Map);

      if (map.containsKey('error')) {
        if (mounted) {
          setState(() {
            _error = map['error']?.toString() ?? 'Error tidak diketahui';
            _isLoading = false;
          });
        }
        return;
      }

      final outletId = map['outlet_id']?.toString();
      final confirmedName = map['outlet_name']?.toString();

      if (outletId == null || confirmedName == null) {
        if (mounted) {
          setState(() {
            _error = 'Respons tidak lengkap dari server: $map';
            _isLoading = false;
          });
        }
        return;
      }

      final deviceId = await DeviceIdentityService.getOrCreateDeviceUuid();

      final session = KioskSession(
        outletId: outletId,
        outletName: confirmedName,
        deviceId: deviceId,
      );

      await ref.read(appProvider.notifier).setKioskSession(session);
      // Router auto-redirects to /kiosk

    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _error = 'Error: ${e.toString()}\n${stack.toString().split('\n').take(4).join('\n')}';
          _isLoading = false;
        });
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),

                // Logo / Brand header
                Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.nfc, color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Absensi Enakko',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ayam Guling Enakko',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 44),

                // Setup card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.settings_outlined,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Aktivasi Perangkat',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Masukkan nama gerai dan password untuk mengaktifkan perangkat ini.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 24),

                      // Outlet name field
                      TextFormField(
                        controller: _outletNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nama Gerai',
                          hintText: 'Contoh: Outlet Pusat - Sudirman',
                          prefixIcon: Icon(Icons.store_outlined),
                        ),
                        autocorrect: false,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Nama gerai wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password Gerai',
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
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
                        onFieldSubmitted: (_) => _activate(),
                      ),

                      // Error message
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.danger.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: AppColors.danger, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                      color: AppColors.danger, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Activate button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _activate,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                              _isLoading ? 'Memverifikasi...' : 'Aktifkan Perangkat'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'Hubungi Akmal untuk mendapatkan password gerai.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
