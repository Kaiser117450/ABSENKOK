import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/biometric_service.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  /// Index berlaku untuk kedua mode (admin/kepala_gerai):
  /// 0=Dashboard, 1=Karyawan, 2=Laporan, (3=Gerai — hanya admin)
  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    if (loc.startsWith('/admin/employees')) return 1;
    if (loc.startsWith('/admin/reports')) return 2;
    if (loc.startsWith('/admin/outlets')) return 3;
    // /admin/dashboard and /admin/outlet-dashboard both keep Dashboard selected
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appProvider);
    final isKepalaGerai = appState.isKepalaGerai;
    final idx = _selectedIndex(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: _EnakkoAppBar(
          subtitle: isKepalaGerai ? 'KEPALA GERAI' : 'ADMIN DASHBOARD',
          onLogout: () => _confirmLogout(context, ref),
          onSettings: () => _showSettingsDialog(context, ref),
        ),
      ),
      body: child,
      bottomNavigationBar: _EnakkoBottomNav(
        currentIndex: idx,
        showOutlets: !isKepalaGerai, // kepala_gerai tidak bisa kelola gerai
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/admin/dashboard');
              break;
            case 1:
              context.go('/admin/employees');
              break;
            case 2:
              context.go('/admin/reports');
              break;
            case 3:
              context.go('/admin/outlets');
              break;
          }
        },
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const _SettingsDialog(),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.danger, size: 22),
            SizedBox(width: 10),
            Text('Keluar',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Yakin ingin keluar dari mode admin?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              // Just clear admin mode — keep Supabase session alive
              // so biometric login can re-authenticate next time.
              ref.read(appProvider.notifier).setAdminMode(false);
              ref.read(appProvider.notifier).setKepalaGeraiMode(null);
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings Dialog — biometric toggle
// ---------------------------------------------------------------------------

class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog();

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  bool _toggling = false;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appProvider);
    final bioEnabled = appState.biometricEnabled;
    final hasBio = appState.hasBiometricHardware;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: const Row(
        children: [
          Icon(Icons.settings_outlined, color: AppColors.textPrimary, size: 22),
          SizedBox(width: 10),
          Text('Pengaturan',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Full sign-out (destroys Supabase session + clears biometric)
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Logout Penuh'),
            subtitle: Text(
              'Hapus sesi — harus login ulang dengan email & password',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
            onTap: () async {
              Navigator.pop(context);
              await Supabase.instance.client.auth.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(AppConstants.rememberedUserRoleKey);
              await prefs.remove(AppConstants.rememberedManagedOutletKey);
              await prefs.setBool(AppConstants.biometricEnabledKey, false);
              ref.read(appProvider.notifier).setAdminMode(false);
              ref.read(appProvider.notifier).setKepalaGeraiMode(null);
              ref.read(appProvider.notifier).setBiometricEnabled(false);
            },
          ),
          const Divider(),
          if (hasBio)
            SwitchListTile(
              title: const Text('Login Biometrik'),
              subtitle: Text(
                'Gunakan sidik jari atau wajah untuk masuk',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              value: bioEnabled,
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              onChanged: _toggling
                  ? null
                  : (value) async {
                      if (value) {
                        // Toggle ON: require biometric confirmation
                        setState(() => _toggling = true);
                        final success = await BiometricService.authenticate(
                          reason:
                              'Verifikasi untuk mengaktifkan login biometrik',
                        );
                        if (!mounted) return;
                        setState(() => _toggling = false);
                        if (success) {
                          await ref
                              .read(appProvider.notifier)
                              .setBiometricEnabled(true);
                          // Save current role for biometric re-login
                          final user =
                              Supabase.instance.client.auth.currentUser;
                          final role =
                              (user?.appMetadata['app_role'] as String?) ??
                                  (user?.userMetadata?['app_role'] as String?);
                          final outletId =
                              (user?.appMetadata['managed_outlet_id']
                                      as String?) ??
                                  (user?.userMetadata?['managed_outlet_id']
                                      as String?);
                          if (role != null) {
                            await ref
                                .read(appProvider.notifier)
                                .saveRememberedRole(role, outletId);
                          }
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Login biometrik diaktifkan')),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Verifikasi gagal')),
                            );
                          }
                        }
                      } else {
                        // Toggle OFF: no confirmation needed
                        await ref
                            .read(appProvider.notifier)
                            .setBiometricEnabled(false);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Login biometrik dinonaktifkan')),
                          );
                        }
                      }
                    },
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Perangkat ini tidak mendukung login biometrik',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Custom AppBar — merah + 2 garis kuning bawah
// ---------------------------------------------------------------------------

class _EnakkoAppBar extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onSettings;
  final String subtitle;

  const _EnakkoAppBar({
    required this.onLogout,
    required this.onSettings,
    this.subtitle = 'ADMIN DASHBOARD',
  });

  @override
  Widget build(BuildContext context) {
    // Container tanpa fixed height — biarkan expand ke statusBarHeight + 60.
    // SafeArea di luar SizedBox agar tidak "memakan" space dari 60px content area.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFDC2626),
            Color(0xFFB91C1C),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFDC4040), // garis merah tipis bawah
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Logo & brand
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0x2EFFFFFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.asset(
                      'src/assets/images/logogoenakko.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ENAKKO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                        height: 1,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: const Color(0xB3FFFFFF),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Settings button
                GestureDetector(
                  onTap: onSettings,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0x26FFFFFF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0x40FFFFFF),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 18,
                      semanticLabel: 'Pengaturan',
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Logout button
                GestureDetector(
                  onTap: onLogout,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0x26FFFFFF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0x40FFFFFF),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.logout, color: Colors.white, size: 15),
                        SizedBox(width: 5),
                        Text(
                          'Keluar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom Bottom Nav
// ---------------------------------------------------------------------------

class _EnakkoBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showOutlets;

  const _EnakkoBottomNav({
    required this.currentIndex,
    required this.onTap,
    this.showOutlets = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Subtle top divider
        Container(height: 1, color: const Color(0xFFE5E7EB)),

        Container(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    selected: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    icon: Icons.people_outlined,
                    activeIcon: Icons.people_rounded,
                    label: 'Karyawan',
                    selected: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _NavItem(
                    icon: Icons.bar_chart_outlined,
                    activeIcon: Icons.bar_chart_rounded,
                    label: 'Laporan',
                    selected: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  if (showOutlets)
                    _NavItem(
                      icon: Icons.store_outlined,
                      activeIcon: Icons.store_rounded,
                      label: 'Gerai',
                      selected: currentIndex == 3,
                      onTap: () => onTap(3),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
