import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import 'core/errors/app_error_handler.dart';
import 'core/theme/dynamic_theme.dart';
import 'state/active_restaurant_notifier.dart';

class AlMahabMenuApp extends StatefulWidget {
  const AlMahabMenuApp({super.key, required this.router});

  final GoRouter router;

  @override
  State<AlMahabMenuApp> createState() => _AlMahabMenuAppState();
}

class _AlMahabMenuAppState extends State<AlMahabMenuApp>
    with WidgetsBindingObserver {
  StreamSubscription<html.Event>? _webVisibilitySubscription;
  bool _appWasInBackground = false;
  bool _webTabWasHidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      _webTabWasHidden = html.document.visibilityState == 'hidden';
      _webVisibilitySubscription =
          html.document.onVisibilityChange.listen((_) => _onWebTabVisible());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_webVisibilitySubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _appWasInBackground = true;
      case AppLifecycleState.resumed:
        if (_appWasInBackground) {
          _appWasInBackground = false;
          _refreshRestaurantFromForeground();
        }
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onWebTabVisible() {
    final visibility = html.document.visibilityState;
    if (visibility == 'hidden') {
      _webTabWasHidden = true;
      return;
    }
    if (visibility == 'visible' && _webTabWasHidden) {
      _webTabWasHidden = false;
      _refreshRestaurantFromForeground();
    }
  }

  void _refreshRestaurantFromForeground() {
    if (!mounted) return;
    final tenant = context.read<ActiveRestaurantNotifier>();
    unawaited(tenant.refreshRestaurant());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveRestaurantNotifier>(
      builder: (context, tenant, _) {
        return MaterialApp.router(
          title: 'Al-Mahab Menu',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: AppErrorHandler.scaffoldMessengerKey,
          theme: buildDynamicTheme(tenant.restaurant),
          routerConfig: widget.router,
        );
      },
    );
  }
}
