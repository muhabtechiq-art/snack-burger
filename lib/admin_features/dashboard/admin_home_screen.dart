import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../state/active_restaurant_notifier.dart';
import '../data/admin_repositories.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';

/// الصفحة الرئيسية للإدارة — المدخل عبر القائمة الجانبية فقط.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, required this.slug});

  final String slug;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final AdminOrderRepository _orderRepository = AdminOrderRepository();

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      slug: widget.slug,
      title: 'لوحة التحكم',
      body: Consumer<ActiveRestaurantNotifier>(
        builder: (context, tenant, _) {
          final restaurant = tenant.restaurant;
          if (restaurant == null) {
            return const Center(
              child: CircularProgressIndicator(color: AdminPanelColors.gold),
            );
          }

          final pendingStream = _orderRepository.watchPendingOrders(
            restaurantId: restaurant.id,
            slug: widget.slug,
          );

          return StreamBuilder(
            stream: pendingStream,
            builder: (context, snapshot) {
              final pendingCount = snapshot.data?.length ?? 0;

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_open_rounded,
                        size: 72,
                        color: AdminPanelColors.gold.withValues(alpha: 0.85),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        restaurant.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AdminPanelColors.gold,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'افتح القائمة الجانبية ☰ لإدارة الطلبات، المنتجات، '
                        'تقارير الإغلاق، والطابعة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AdminPanelColors.textMuted.withValues(alpha: 0.95),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () =>
                            context.push('/${widget.slug}/admin/orders'),
                        icon: const Icon(Icons.notifications_active_rounded),
                        label: Text(
                          pendingCount > 0
                              ? 'عرض $pendingCount طلب معلق (مباشر)'
                              : 'لوحة الطلبات المعلقة (مباشر)',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: pendingCount > 0
                              ? Colors.red.shade700
                              : AdminPanelColors.gold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
