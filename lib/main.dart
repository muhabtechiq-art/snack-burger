import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/auth/admin_profile_session.dart';
import 'core/auth/auth_notifier.dart';
import 'core/observability/app_telemetry.dart';
import 'core/router/app_router.dart';
import 'dev/snack_burger_product_seeder.dart';
import 'services/windows_printer_bridge.dart';
import 'state/active_restaurant_notifier.dart';

Future<void> main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppTelemetry.logError(
      'flutter_error',
      error: details.exception,
      stackTrace: details.stack,
      fields: <String, Object?>{'library': details.library},
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    AppTelemetry.logError(
      'platform_dispatcher_error',
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jifnpjhtkwxpegzwamrs.supabase.co',
    anonKey: 'sb_publishable_pp5dLOfJKxznF0YVqOGTdw_6vDn8xow',
  );

  await AdminProfileSession.loadFromStorage();

  final seedResult = await SnackBurgerProductSeeder.runIfRequested();
  if (seedResult != SeedRunResult.notRequested) {
    SnackBurgerProductSeeder.exitAfterSeedRun(seedResult);
  }

  if (kDebugMode && !kIsWeb && Platform.isWindows) {
    await WindowsPrinterBridge.logInstalledPrintersToConsole();
    try {
      await WindowsPrinterBridge.instance.detectGenericTextOnlyPrinter();
    } catch (e) {
      debugPrint('Printer detect at startup: $e');
    }
  }

  final tenantNotifier = ActiveRestaurantNotifier();
  final authNotifier = AuthNotifier();
  final router = createAppRouter(authNotifier);

  runZonedGuarded(
    () {
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ActiveRestaurantNotifier>.value(
              value: tenantNotifier,
            ),
            ChangeNotifierProvider<AuthNotifier>.value(
              value: authNotifier,
            ),
          ],
          child: AlMahabMenuApp(router: router),
        ),
      );
    },
    (Object error, StackTrace stackTrace) {
      AppTelemetry.logError(
        'zone_uncaught_error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}
