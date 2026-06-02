import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tenant_palette.dart';
import '../../models/delivery_order_model.dart';
import '../../state/active_restaurant_notifier.dart';
import '../data/admin_repositories.dart';
import '../orders/pending_order_actions.dart';
import '../orders/pending_orders_notification_coordinator.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';

/// لوحة الطلبات المعلقة — بث Supabase مباشر من جدول `orders`.
class OrdersDashboardScreen extends StatefulWidget {
  const OrdersDashboardScreen({super.key, required this.slug});

  final String slug;

  @override
  State<OrdersDashboardScreen> createState() => _OrdersDashboardScreenState();
}

class _OrdersDashboardScreenState extends State<OrdersDashboardScreen> {
  final AdminOrderRepository _orderRepository = AdminOrderRepository();
  final PendingOrderActions _orderActions = PendingOrderActions();
  final PendingOrdersNotificationCoordinator _notifications =
      PendingOrdersNotificationCoordinator();

  final Set<String> _locallyRemovedIds = {};
  String? _streamKey;

  void _onOrderRemovedFromPending(String orderId) {
    setState(() => _locallyRemovedIds.add(orderId));
  }

  void _onOrderAcceptFailed(String orderId) {
    setState(() => _locallyRemovedIds.remove(orderId));
  }

  List<DeliveryOrder> _visibleOrders(List<DeliveryOrder> fromStream) {
    _locallyRemovedIds.removeWhere(
      (id) => !fromStream.any((order) => order.id == id),
    );
    return fromStream
        .where((order) => !_locallyRemovedIds.contains(order.id))
        .toList();
  }

  void _handleStreamData(List<DeliveryOrder> orders) {
    _notifications.onPendingOrdersUpdated(orders);
  }

  @override
  void dispose() {
    _notifications.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      slug: widget.slug,
      title: 'الطلبات المعلقة',
      body: Consumer<ActiveRestaurantNotifier>(
        builder: (context, tenant, _) {
          final restaurant = tenant.restaurant;
          if (restaurant == null) {
            return const Center(
              child: CircularProgressIndicator(color: AdminPanelColors.gold),
            );
          }

          final palette = TenantPalette.fromRestaurant(restaurant);
          final streamKey = '${restaurant.id}|${widget.slug}';
          if (_streamKey != streamKey) {
            _streamKey = streamKey;
            _notifications.reset();
          }

          final ordersStream = _orderRepository.watchPendingOrders(
            restaurantId: restaurant.id,
            slug: widget.slug,
          );

          return StreamBuilder<List<DeliveryOrder>>(
            stream: ordersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AdminPanelColors.gold,
                  ),
                );
              }

              if (snapshot.hasError) {
                return _ErrorState(
                  message: snapshot.error.toString(),
                  onRetry: () => setState(() {
                    _notifications.reset();
                    _streamKey = null;
                  }),
                );
              }

              final rawOrders = snapshot.data ?? const <DeliveryOrder>[];
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _handleStreamData(rawOrders);
              });

              final orders = _visibleOrders(rawOrders);
              final isLive = snapshot.connectionState == ConnectionState.active ||
                  snapshot.hasData;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DashboardHeader(count: orders.length, isLive: isLive),
                  const SizedBox(height: 12),
                  Expanded(
                    child: orders.isEmpty
                        ? const _EmptyState()
                        : ListView.builder(
                            shrinkWrap: false,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: orders.length,
                            itemBuilder: (context, index) {
                              final order = orders[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PendingOrderCard(
                                  order: order,
                                  onTap: () => _orderActions.showOrderDialog(
                                    context: context,
                                    order: order,
                                    palette: palette,
                                    onOrderRemovedFromPending: () =>
                                        _onOrderRemovedFromPending(order.id),
                                    onOrderAcceptFailed: () =>
                                        _onOrderAcceptFailed(order.id),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.count,
    required this.isLive,
  });

  final int count;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Icon(
            isLive ? Icons.sensors_rounded : Icons.sensors_off_rounded,
            color: isLive ? Colors.greenAccent : AdminPanelColors.textMuted,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isLive
                  ? 'متصل — التحديثات فورية من Supabase'
                  : 'جاري الاتصال بالبث المباشر...',
              style: TextStyle(
                color: AdminPanelColors.textMuted.withValues(alpha: 0.95),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingOrderCard extends StatelessWidget {
  const _PendingOrderCard({
    required this.order,
    required this.onTap,
  });

  final DeliveryOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminPanelColors.charcoalLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AdminPanelColors.gold.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                color: AdminPanelColors.gold.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(
                        color: AdminPanelColors.textLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.items.length} وجبة — '
                      '${order.totalPrice.toStringAsFixed(0)} د.ع',
                      style: const TextStyle(
                        color: AdminPanelColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.customerPhone,
                      style: TextStyle(
                        color: AdminPanelColors.goldMuted.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: AdminPanelColors.gold.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 64,
            color: AdminPanelColors.gold.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد طلبات معلقة',
            style: TextStyle(
              color: AdminPanelColors.textLight,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر الطلبات الجديدة هنا فوراً دون تحديث الصفحة',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AdminPanelColors.textMuted.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            const Text(
              'تعذّر تحميل الطلبات',
              style: TextStyle(
                color: AdminPanelColors.textLight,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminPanelColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة الاتصال'),
              style: FilledButton.styleFrom(
                backgroundColor: AdminPanelColors.gold,
                foregroundColor: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
