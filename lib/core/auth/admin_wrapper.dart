import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../admin_features/orders/admin_order_notification_controller.dart';
import '../../admin_features/shell/admin_panel_colors.dart';
import '../../state/active_restaurant_notifier.dart';
import 'auth_notifier.dart';

/// يغلّف شاشات الإدارة — Loading أثناء التحميل، خطأ إن فشل profile.
class AdminWrapper extends StatefulWidget {
  const AdminWrapper({
    super.key,
    required this.slug,
    required this.child,
  });

  final String slug;
  final Widget child;

  @override
  State<AdminWrapper> createState() => _AdminWrapperState();
}

class _AdminWrapperState extends State<AdminWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncOrderSoundListener());
    });
  }

  @override
  void didUpdateWidget(AdminWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncOrderSoundListener());
    });
  }

  Future<void> _syncOrderSoundListener() async {
    if (!mounted) return;

    final auth = context.read<AuthNotifier>();
    if (!auth.isAdminAuthorized) {
      await AdminOrderNotificationController.instance.stop();
      return;
    }

    final tenant = context.read<ActiveRestaurantNotifier>();
    var restaurant = tenant.restaurant;
    if (restaurant == null) {
      await tenant.resolveSlug(widget.slug);
      if (!mounted) return;
      restaurant = context.read<ActiveRestaurantNotifier>().restaurant;
    }
    if (restaurant == null) return;

    await AdminOrderNotificationController.instance.ensureListening(
      restaurantId: restaurant.id,
      slug: widget.slug,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();

    if (auth.isAuthResolving) {
      return const _AdminGateScaffold(
        message: 'جاري التحقق من الصلاحيات...',
      );
    }

    if (!auth.isAuthenticated) {
      return const _AdminGateScaffold(
        message: 'جاري التوجيه...',
      );
    }

    if (!auth.hasAdminProfile) {
      return _AdminGateScaffold(
        message: auth.profileLoadFailed
            ? 'تعذّر جلب بيانات المطعم — تحقق من جدول profiles و RLS'
            : 'جاري تحميل بيانات المطعم...',
        showRetry: auth.profileLoadFailed,
        onRetry: () async {
          final notifier = context.read<AuthNotifier>();
          await notifier.ensureReadyForRouting(needsAdminProfile: true);
          if (!mounted) return;
          unawaited(_syncOrderSoundListener());
        },
        showSignOut: true,
        onSignOut: () async {
          await context.read<AuthNotifier>().signOut();
          if (context.mounted) {
            context.go('/${widget.slug}/admin/login');
          }
        },
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncOrderSoundListener());
    });

    return widget.child;
  }
}

class _AdminGateScaffold extends StatelessWidget {
  const _AdminGateScaffold({
    required this.message,
    this.showRetry = false,
    this.onRetry,
    this.showSignOut = false,
    this.onSignOut,
  });

  final String message;
  final bool showRetry;
  final VoidCallback? onRetry;
  final bool showSignOut;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AdminPanelColors.charcoal,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!showRetry)
                  const CircularProgressIndicator(color: AdminPanelColors.gold),
                if (!showRetry) const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AdminPanelColors.textMuted,
                    fontSize: 15,
                  ),
                ),
                if (showRetry && onRetry != null) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminPanelColors.gold,
                      foregroundColor: AdminPanelColors.charcoal,
                    ),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
                if (showSignOut && onSignOut != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(color: AdminPanelColors.textMuted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
