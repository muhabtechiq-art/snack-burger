import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme/dynamic_theme.dart';
import 'state/active_restaurant_notifier.dart';

class AlMahabMenuApp extends StatelessWidget {
  const AlMahabMenuApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveRestaurantNotifier>(
      builder: (context, tenant, _) {
        return MaterialApp.router(
          title: 'Al-Mahab Menu',
          debugShowCheckedModeBanner: false,
          theme: buildDynamicTheme(tenant.restaurant),
          routerConfig: router,
        );
      },
    );
  }
}
