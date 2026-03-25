import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';

import 'services/kiosk_background_service.dart';

import 'core/admin_session_claims.dart';
import 'core/theme.dart';
import 'main.dart' show supabaseReady;
import 'providers/app_provider.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/central_dashboard_screen.dart';
import 'screens/admin/chart_dashboard_screen.dart';
import 'screens/admin/admin_employees_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_outlets_screen.dart';
import 'screens/admin/admin_reports_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/admin/archived_employees_screen.dart';
import 'screens/admin/create_admin_screen.dart';
import 'screens/admin/csv_import_screen.dart';
import 'screens/kiosk/kiosk_diagnostics_screen.dart';
import 'screens/kiosk/kiosk_idle_screen.dart';
import 'screens/kiosk/kiosk_scan_screen.dart';
import 'screens/setup/setup_screen.dart';

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

/// A ChangeNotifier that GoRouter uses to reactively re-evaluate redirects
/// whenever the Riverpod AppState changes.
class _AppStateListenable extends ChangeNotifier {
  _AppStateListenable(this._ref) {
    _ref.listen<AppState>(appProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AppStateListenable(ref);

  return GoRouter(
    initialLocation: '/setup',
    refreshListenable: listenable,
    redirect: (context, state) {
      final appState = ref.read(appProvider);

      final loc = state.uri.path;

      // STRICT GUARD: Don't allow access to protected routes while session is loading.
      // This prevents redirect loops and async gap errors where a protected route
      // tries to access unloaded session data.
      if (appState.isLoading) {
        if (loc == '/setup' || loc == '/admin/login') return null;
        return '/setup'; // Force wait at setup screen
      }
      final isAdmin = appState.isAdmin;
      final isKepalaGerai = appState.isKepalaGerai;
      final hasKiosk = appState.kioskSession != null;

      // /admin/login: allow unauthenticated users (kiosk operators can tap
      // "Admin" button anytime), but redirect already-authenticated users
      // to dashboard (e.g. after biometric login sets admin mode).
      if (loc == '/admin/login') {
        if (isAdmin || isKepalaGerai) return '/admin/dashboard';
        return null;
      }

      if (isAdmin) {
        // Admin penuh → akses semua halaman admin
        if (!loc.startsWith('/admin')) return '/admin/dashboard';
      } else if (isKepalaGerai) {
        // Kepala gerai → akses dashboard/karyawan/laporan saja,
        // TIDAK bisa ke halaman admin khusus (outlet, CSV import)
        if (!loc.startsWith('/admin')) return '/admin/dashboard';
        if (loc.startsWith('/admin/network-summary')) return '/admin/dashboard';
        if (loc.startsWith('/admin/outlets')) return '/admin/dashboard';
        if (loc.startsWith('/admin/csv-import')) return '/admin/dashboard';
        if (loc.startsWith('/admin/archived-employees'))
          return '/admin/dashboard';
        if (loc.startsWith('/admin/create-account')) return '/admin/dashboard';
      } else if (hasKiosk) {
        // Kiosk session exists → stay on kiosk screens
        if (!loc.startsWith('/kiosk')) return '/kiosk';
      } else {
        // No session at all → only /setup is allowed, redirect everything else
        if (loc != '/setup') return '/setup';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/setup',
        builder: (_, __) => const SetupScreen(),
      ),
      GoRoute(
        path: '/kiosk',
        builder: (_, __) => const KioskIdleScreen(),
        routes: [
          GoRoute(
            path: 'scan',
            builder: (_, __) => const KioskScanScreen(),
          ),
          GoRoute(
            path: 'diagnostics',
            builder: (_, __) => const KioskDiagnosticsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/admin/login',
        builder: (_, __) => const AdminLoginScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (_, __) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/network-summary',
            builder: (_, __) => const CentralDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/outlet-dashboard',
            builder: (context, state) {
              final outletId = state.uri.queryParameters['outletId'];
              return AdminDashboardScreen(initialOutletId: outletId);
            },
          ),
          GoRoute(
            path: '/admin/employees',
            builder: (_, __) => const AdminEmployeesScreen(),
          ),
          GoRoute(
            path: '/admin/reports',
            builder: (_, __) => const AdminReportsScreen(),
          ),
          GoRoute(
            path: '/admin/outlets',
            builder: (_, __) => const AdminOutletsScreen(),
          ),
          GoRoute(
            path: '/admin/archived-employees',
            builder: (_, __) => const ArchivedEmployeesScreen(),
          ),
          GoRoute(
            path: '/admin/csv-import',
            builder: (_, __) => const CsvImportScreen(),
          ),
          GoRoute(
            path: '/admin/create-account',
            builder: (_, __) => const CreateAdminScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/admin/chart-dashboard',
        builder: (context, state) => ChartDashboardScreen(
          outletId: state.uri.queryParameters['outletId'] ?? '',
        ),
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Root App Widget
// ---------------------------------------------------------------------------

class AbsensiEnakkoApp extends ConsumerStatefulWidget {
  const AbsensiEnakkoApp({super.key});

  @override
  ConsumerState<AbsensiEnakkoApp> createState() => _AbsensiEnakkoAppState();
}

class _AbsensiEnakkoAppState extends ConsumerState<AbsensiEnakkoApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Load kiosk session from SharedPreferences
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appProvider.notifier).loadSession();

      // Safety net: if loadSession hangs for any reason, unblock after 5s
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        final s = ref.read(appProvider);
        if (s.isLoading) {
          ref.read(appProvider.notifier).forceUnblockLoading();
        }
      });

      // Request overlay permission proaktif saat pertama launch (Android only)
      if (Platform.isAndroid) {
        KioskBackgroundService.requestOverlayPermission();
      }
    });

    // Subscribe to Supabase admin auth state changes.
    // Only set admin mode on EXPLICIT sign-in (signedIn event), not on
        final notifier = ref.read(appProvider.notifier);
    // session restore (initialSession / tokenRefreshed). This ensures
    // biometric gate isn't bypassed when the app restarts with a saved session.
    if (supabaseReady) {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final event = data.event;

        if (event == AuthChangeEvent.signedOut) {
          // Full logout — clear all roles
          notifier.clearAdminSessionMode();
          return;
        }

        // Only auto-set admin on explicit sign-in (email/password login).
        // Biometric login sets admin mode itself in _triggerBiometricLogin().
        if (event != AuthChangeEvent.signedIn) return;

        final claims = AdminSessionClaims.fromUser(data.session?.user);
        notifier.applyAdminSessionClaims(claims);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _isBackgroundLifecycleState(AppLifecycleState state) {
    return state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused;
  }

  Future<void> _applyLifecyclePolicy(AppLifecycleState state) async {
    if (!Platform.isAndroid) return;

    final appState = ref.read(appProvider);
    final session = appState.kioskSession;
    if (session == null) return;

    if (_isBackgroundLifecycleState(state)) {
      await KioskBackgroundService.showLiveNotification(
        outletName: session.outletName,
      );
      await KioskBackgroundService.showOverlayPill(
        outletName: session.outletName,
      );
      return;
    }

    if (state == AppLifecycleState.resumed &&
        !appState.keepOverlayInForeground) {
      await KioskBackgroundService.hideOverlayPill();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    unawaited(_applyLifecyclePolicy(state));
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return ToastificationWrapper(
      child: MaterialApp.router(
        title: 'Absensi Enakko',
        theme: buildAppTheme(),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
