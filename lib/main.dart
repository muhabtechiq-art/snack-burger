import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/auth/admin_profile_session.dart';
import 'core/auth/auth_notifier.dart';
import 'core/config/app_env_loader.dart';
import 'core/config/supabase_env.dart';
import 'core/observability/app_telemetry.dart';
import 'core/router/app_router.dart';
import 'dev/snack_burger_product_seeder.dart';
import 'core/config/restaurant_ids.dart';
import 'services/order_realtime_notification_service.dart';
import 'services/windows_printer_bridge.dart';
import 'state/active_restaurant_notifier.dart';
import 'state/app_settings_notifier.dart';
import 'state/business_day_notifier.dart';

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

  await AppEnvLoader.load();
  SupabaseEnv.ensureConfigured();

  await Supabase.initialize(
    url: SupabaseEnv.url,
    anonKey: SupabaseEnv.anonKey,
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
  final appSettingsNotifier = AppSettingsNotifier();
  await appSettingsNotifier.initialize();
  final businessDayNotifier = BusinessDayNotifier();
  final authNotifier = AuthNotifier();
  await authNotifier.waitUntilReady();
  await _startOrderRealtimeNotificationsIfAdmin(
    authNotifier,
    tenantNotifier,
  );

  final router = createAppRouter(authNotifier);

  runZonedGuarded(
    () {
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ActiveRestaurantNotifier>.value(
              value: tenantNotifier,
            ),
            ChangeNotifierProvider<AppSettingsNotifier>.value(
              value: appSettingsNotifier,
            ),
            ChangeNotifierProvider<BusinessDayNotifier>.value(
              value: businessDayNotifier,
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

Future<void> _startOrderRealtimeNotificationsIfAdmin(
  AuthNotifier authNotifier,
  ActiveRestaurantNotifier tenantNotifier,
) async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

  final service = OrderRealtimeNotificationService.instance;
  await service.initialize();

  Future<void> sync() async {
    if (authNotifier.isAdminAuthorized) {
      final slug = tenantNotifier.tenantSlug ?? RestaurantIds.snackBurgerSlug;
      if (!tenantNotifier.hasResolvedTenant ||
          tenantNotifier.tenantSlug != slug) {
        await tenantNotifier.resolveSlug(slug);
      }
      await service.start(
        slug: tenantNotifier.tenantSlug ?? slug,
        restaurantUuid: tenantNotifier.tenantRestaurantUuid,
      );
    } else {
      await service.stop();
    }
  }

  authNotifier.addListener(() {
    unawaited(sync());
  });
  tenantNotifier.addListener(() {
    unawaited(sync());
  });
  await sync();
}
