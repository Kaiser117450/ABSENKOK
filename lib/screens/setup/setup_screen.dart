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

  String _extractActivationMessage(Object? error) {
    if (error == null) return '';

    final raw = error.toString().trim();
    final match = RegExp(r'message:\s*([^,]+)').firstMatch(raw);
    final message = match?.group(1) ?? raw;
    return message.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  String _formatActivationError(Object? error) {
    final message = _extractActivationMessage(error);
    if (message.isEmpty) {
      return 'Aktivasi perangkat gagal. Coba lagi atau hubungi admin.';
    }

    final normalized = message.toLowerCase();

    if (normalized.contains('timeout')) {
      return 'Aktivasi perangkat timeout. Periksa internet lalu coba lagi.';
    }

    // Device identity cannot be read (null/empty UUID from SharedPreferences)
    if (normalized.contains('identitas perangkat tidak dapat dibaca') ||
        normalized.contains('tidak dapat dibaca')) {
      return 'Identitas perangkat tidak dapat dibaca. Coba restart aplikasi.';
    }

    // Password wrong
    if (normalized.contains('password salah')) {
      return 'Aktivasi gagal. Password gerai salah.';
    }

    // Outlet not found
    if (normalized.contains('tidak ditemukan') ||
        normalized.contains('not found')) {
      return 'Aktivasi gagal. Nama gerai tidak ditemukan.';
    }

    // Generic password/outlet errors
    if (normalized.contains('password') ||
        normalized.contains('tidak valid')) {
      return 'Aktivasi gagal. Nama gerai atau password tidak valid.';
    }

    return 'Aktivasi gagal. $message';
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
          _error =
              'Tidak dapat terhubung ke server. Periksa koneksi internet lalu coba lagi.';
          _isLoading = false;
        });
        return;
      }

      final outletName = _outletNameCtrl.text.trim();
      final password = _passwordCtrl.text;
      final deviceId = await DeviceIdentityService.getOrCreateDeviceUuid();

      // Activate the persistent device UUID via Supabase RPC.
      // Hard timeout of 15 s so the UI never blocks indefinitely (ANR fix).
      dynamic result;
      try {
        result = await Supabase.instance.client.rpc(
          'activate_kiosk_device',
          params: {
            'p_outlet_name': outletName,
            'p_password': password,
            'p_device_uuid': deviceId,
          },
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('timeout'),
        );
      } on Exception catch (e) {
        if (mounted) {
          setState(() {
            _error = _formatActivationError(e);
            _isLoading = false;
          });
        }
        return;
      }

      // RPC returned null — function belum ada atau server tidak merespons
      if (result == null) {
        if (mounted) {
          setState(() {
            _error =
                'Server tidak merespons. Pastikan RPC activate_kiosk_device sudah dibuat di Supabase.';
            _isLoading = false;
          });
        }
        return;
      }

      // Pastikan result adalah Map
      if (result is! Map) {
        debugPrint(
            '[Setup] Invalid activation response type: ${result.runtimeType}');
        if (mounted) {
          setState(() {
            _error = 'Respons aktivasi perangkat tidak valid dari server.';
            _isLoading = false;
          });
        }
        return;
      }

      final map = Map<String, dynamic>.from(result);

      if (map.containsKey('error')) {
        if (mounted) {
          setState(() {
            _error = _formatActivationError(map['error']);
            _isLoading = false;
          });
        }
        return;
      }

      final outletId = map['outlet_id']?.toString();
      final confirmedName = map['outlet_name']?.toString();
      final activatedDeviceId = map['device_uuid']?.toString();

      if (outletId == null ||
          confirmedName == null ||
          activatedDeviceId == null) {
        debugPrint('[Setup] Incomplete activation response: $map');
        if (mounted) {
          setState(() {
            _error = 'Respons aktivasi perangkat tidak lengkap.';
            _isLoading = false;
          });
        }
        return;
      }

      if (activatedDeviceId != deviceId) {
        debugPrint(
          '[Setup] Activation device mismatch: local=$deviceId response=$activatedDeviceId',
        );
        if (mounted) {
          setState(() {
            _error = 'Aktivasi gagal. Identitas perangkat tidak cocok.';
            _isLoading = false;
          });
        }
        return;
      }

      final session = KioskSession(
        outletId: outletId,
        outletName: confirmedName,
        deviceId: deviceId,
      );

      await ref.read(appProvider.notifier).setKioskSession(session);
      // Router auto-redirects to /kiosk
    } catch (e, stack) {
      debugPrint('[Setup] Activation failed: $e\n$stack');
      if (mounted) {
        setState(() {
          _error = _formatActivationError(e);
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
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child:
                          const Icon(Icons.nfc, color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Absensi Enakko',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                        color: Colors.black.withValues(alpha: 0.05),
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
                              color: AppColors.primary.withValues(alpha: 0.1),
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
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.3)),
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
                          label: Text(_isLoading
                              ? 'Mengaktifkan...'
                              : 'Aktifkan Perangkat'),
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
