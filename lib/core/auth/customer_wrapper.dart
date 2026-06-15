import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../customer_features/maintenance/maintenance_screen.dart';
import '../../state/app_settings_notifier.dart';
import 'auth_notifier.dart';

/// يغلّف شاشات الزبون — يحجب المنيو أثناء الصيانة أو الخطأ الحرج.
class CustomerWrapper extends StatelessWidget {
  const CustomerWrapper({
    super.key,
    required this.slug,
    required this.child,
  });

  final String slug;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final appSettings = context.watch<AppSettingsNotifier>();

    if (auth.isAuthResolving) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.isAdminAuthorized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (appSettings.isLoading && !appSettings.shouldBlockCustomerApp) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (appSettings.shouldBlockCustomerApp) {
      return MaintenanceScreen(
        settings: appSettings.settings,
        isEmergencyFallback: appSettings.emergencyFallback &&
            !appSettings.maintenanceMode,
      );
    }

    return child;
  }
}
