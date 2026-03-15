import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
// overlay_task.dart diimport agar overlayMain() dikompilasi ke APK dan
// tidak di-tree-shake meski pakai --obfuscate. @pragma("vm:entry-point")
// saja tidak cukup jika file tidak termasuk dalam compilation graph.
// ignore: unused_import
import 'overlay_task.dart';
import 'services/nfc_service.dart';
import 'services/sqlite_service.dart';

/// Global flag — true once Supabase.initialize() completes successfully.
bool supabaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting locale for Indonesia
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';

  // Log uncaught errors (no on-screen display in production)
  FlutterError.onError = (details) {
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[UncaughtError] $error');
    return true; // handled
  };

  // Lock to portrait orientation (kiosk mode)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase — no timeout here so it always completes properly.
  // The HTTP layer already has its own internal timeout.
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    supabaseReady = true;
  } catch (e) {
    // Supabase.initialize() itself never actually makes a network call —
    // it just sets up the client. If it throws, something is wrong with
    // the URL/key values. Log and continue; screens will show error.
    debugPrint('[main] Supabase.initialize error: $e');
  }

  // Initialize local SQLite database (creates tables if needed)
  await SqliteService.getDatabase();

  // Warm NFC hardware — with 3s timeout so a disabled/missing NFC
  // never blocks the splash screen. Result is cached in NfcService.isAvailable.
  await NfcService.init().timeout(
    const Duration(seconds: 3),
    onTimeout: () {
      debugPrint('[main] NfcService.init() timed out — NFC may be off');
      return false;
    },
  );

  // Production: always launch the app. Errors are logged via debugPrint.
  runApp(
    const ProviderScope(
      child: AbsensiEnakkoApp(),
    ),
  );
}
