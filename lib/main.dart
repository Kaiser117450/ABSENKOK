import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
// overlay_task.dart diimport agar overlayMain() dikompilasi ke APK dan
// tidak di-tree-shake meski pakai --obfuscate. @pragma("vm:entry-point")
// saja tidak cukup jika file tidak termasuk dalam compilation graph.
// ignore: unused_import
import 'overlay_task.dart';
import 'services/nfc_service.dart';
import 'services/sentry_service.dart';
import 'services/sqlite_service.dart';

/// Global flag — true once Supabase.initialize() completes successfully.
bool supabaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting locale for Indonesia
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';

  // Load environment variables BEFORE SentryFlutter.init so DSN is available.
  await dotenv.load(fileName: '.env');

  await SentryFlutter.init(
    (options) {
      // Only report crashes in release builds; development uses empty DSN (no-op).
      options.dsn = kReleaseMode ? (dotenv.env['SENTRY_DSN'] ?? '') : '';
      options.environment = kReleaseMode ? 'production' : 'development';
      // Disable performance tracing — we only want crash/error reporting.
      options.tracesSampleRate = 0;
      options.debug = false;
      // Filter benign NFC tag-lost exceptions before they reach Sentry.
      options.beforeSend = SentryService.beforeSend;
    },
    appRunner: () async {
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

      // Production: always launch the app. Sentry manages uncaught error hooks.
      runApp(
        const ProviderScope(
          child: AbsensiEnakkoApp(),
        ),
      );
    },
  );
}
