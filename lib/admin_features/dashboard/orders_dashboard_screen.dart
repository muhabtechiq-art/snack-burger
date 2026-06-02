import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../models/delivery_order_model.dart';
import '../../models/delivery_order_status.dart';
import '../../services/order_invoice_printer.dart';
import '../../services/supabase_order_service.dart';
import '../../state/active_restaurant_notifier.dart';
import '../data/admin_repositories.dart';
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
  final PendingOrdersNotificationCoordinator _notifications =
      PendingOrdersNotificationCoordinator();

  final Set<String> _locallyRemovedIds = {};
  final Set<String> _updatingOrderIds = {};
  String? _streamKey;
  Stream<List<DeliveryOrder>>? _ordersStream;
  StreamHealth _streamHealth = StreamHealth.connecting;

  bool get _isLive => _streamHealth == StreamHealth.live;

  void _onOrderRemovedFromPending(String orderId) {
    setState(() => _locallyRemovedIds.add(orderId));
  }

  void _onOrderAcceptFailed(String orderId) {
    setState(() => _locallyRemovedIds.remove(orderId));
  }

  Future<void> _updateOrderStatus({
    required DeliveryOrder order,
    required String status,
  }) async {
    if (_updatingOrderIds.contains(order.id) || order.status == status) return;
    setState(() => _updatingOrderIds.add(order.id));
    try {
      await _orderRepository.updateOrderStatus(orderId: order.id, status: status);
      if (status == DeliveryOrderStatus.accepted) {
        // Keep invoice printing behavior on "Accept Order".
        await _printInvoiceSafely(order);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث حالة الطلب إلى ${_statusActionLabel(status)}'),
          duration: const Duration(milliseconds: 1200),
        ),
      );
      if (status == DeliveryOrderStatus.delivered) {
        _onOrderRemovedFromPending(order.id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحديث الحالة: $e')),
      );
      _onOrderAcceptFailed(order.id);
    } finally {
      if (mounted) {
        setState(() => _updatingOrderIds.remove(order.id));
      }
    }
  }

  Future<void> _printInvoiceSafely(DeliveryOrder order) async {
    try {
      await printOrderInvoice(order);
    } catch (e, st) {
      debugPrint('OrdersDashboardScreen print invoice failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم القبول لكن فشلت الطباعة: $e')),
      );
    }
  }

  String _statusActionLabel(String status) => switch (status) {
        DeliveryOrderStatus.accepted => 'قبول الطلب',
        DeliveryOrderStatus.preparing => 'جاري التحضير',
        DeliveryOrderStatus.delivering => 'خرج للتوصيل',
        DeliveryOrderStatus.delivered => 'تم التوصيل',
        _ => status,
      };

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

  void _handleStreamHealth(StreamHealth health) {
    if (!mounted || _streamHealth == health) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() => _streamHealth = health);
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _streamHealth == health) return;
      setState(() => _streamHealth = health);
    });
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
      title: 'الطلبات النشطة',
      body: Consumer<ActiveRestaurantNotifier>(
        builder: (context, tenant, _) {
          final restaurant = tenant.restaurant;
          if (restaurant == null) {
            return const Center(
              child: CircularProgressIndicator(color: AdminPanelColors.gold),
            );
          }

          final streamKey = '${restaurant.id}|${widget.slug}';
          if (_streamKey != streamKey || _ordersStream == null) {
            _streamKey = streamKey;
            _notifications.reset();
            _streamHealth = StreamHealth.connecting;
            _ordersStream = _orderRepository.watchActiveOrders(
              restaurantId: restaurant.id,
              slug: widget.slug,
              onHealthChanged: _handleStreamHealth,
            );
          }

          return StreamBuilder<List<DeliveryOrder>>(
            stream: _ordersStream,
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
                    _ordersStream = null;
                    _streamHealth = StreamHealth.connecting;
                  }),
                );
              }

              final rawOrders = snapshot.data ?? const <DeliveryOrder>[];
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _handleStreamData(
                  rawOrders
                      .where((order) => order.status == DeliveryOrderStatus.pending)
                      .toList(),
                );
              });

              final orders = _visibleOrders(rawOrders);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DashboardHeader(count: orders.length, health: _streamHealth),
                  if (!_isLive)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _ConnectivityHint(
                        health: _streamHealth,
                        onRetry: () => setState(() {
                          _streamKey = null;
                          _ordersStream = null;
                          _streamHealth = StreamHealth.connecting;
                        }),
                      ),
                    ),
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
                                  isUpdating: _updatingOrderIds.contains(order.id),
                                  onStatusSelected: (status) => _updateOrderStatus(
                                    order: order,
                                    status: status,
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
    required this.health,
  });

  final int count;
  final StreamHealth health;

  @override
  Widget build(BuildContext context) {
    final isLive = health == StreamHealth.live;
    final title = switch (health) {
      StreamHealth.connecting => 'جاري الاتصال ببث الطلبات...',
      StreamHealth.live => 'متصل — التحديثات الفورية للطلبات نشطة',
      StreamHealth.reconnecting => 'انقطع الاتصال — جارٍ إعادة الربط...',
      StreamHealth.stale => 'آخر تحديث قديم — جارٍ الإنعاش...',
      StreamHealth.error => 'خطأ اتصال — حاول إعادة الاتصال',
      StreamHealth.disposed => 'تم إيقاف البث',
    };

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
              title,
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

class _ConnectivityHint extends StatelessWidget {
  const _ConnectivityHint({required this.health, required this.onRetry});

  final StreamHealth health;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = switch (health) {
      StreamHealth.reconnecting => 'نعيد الاتصال تلقائياً الآن. يمكنك الانتظار أو إعادة الاتصال يدوياً.',
      StreamHealth.stale => 'الاتصال بطيء حالياً، آخر بيانات قد تكون قديمة.',
      StreamHealth.error => 'تعذر استلام بيانات جديدة من السيرفر.',
      StreamHealth.connecting => 'جارٍ تهيئة القناة المباشرة...',
      StreamHealth.live => '',
      StreamHealth.disposed => 'تم إيقاف البث الحالي.',
    };

    if (message.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering_error_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AdminPanelColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('إعادة الاتصال'),
          ),
        ],
      ),
    );
  }
}

class _PendingOrderCard extends StatelessWidget {
  const _PendingOrderCard({
    required this.order,
    required this.onStatusSelected,
    required this.isUpdating,
  });

  final DeliveryOrder order;
  final bool isUpdating;
  final ValueChanged<String> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminPanelColors.charcoalLight,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AdminPanelColors.gold.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'لوحة التحكم بالحالة',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AdminPanelColors.goldMuted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminPanelColors.charcoal.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AdminPanelColors.gold.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatusActionButton(
                          label: 'قبول الطلب',
                          icon: Icons.done_rounded,
                          selected: order.status == DeliveryOrderStatus.accepted,
                          onPressed: isUpdating
                              ? null
                              : () => onStatusSelected(DeliveryOrderStatus.accepted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatusActionButton(
                          label: 'جاري التحضير',
                          icon: Icons.soup_kitchen_rounded,
                          selected: order.status == DeliveryOrderStatus.preparing,
                          onPressed: isUpdating
                              ? null
                              : () => onStatusSelected(DeliveryOrderStatus.preparing),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatusActionButton(
                          label: 'خرج للتوصيل',
                          icon: Icons.delivery_dining_rounded,
                          selected: order.status == DeliveryOrderStatus.delivering,
                          onPressed: isUpdating
                              ? null
                              : () => onStatusSelected(DeliveryOrderStatus.delivering),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatusActionButton(
                          label: 'تم التوصيل',
                          icon: Icons.check_circle_rounded,
                          selected: order.status == DeliveryOrderStatus.delivered,
                          onPressed: isUpdating
                              ? null
                              : () => onStatusSelected(DeliveryOrderStatus.delivered),
                        ),
                      ),
                    ],
                  ),
                  if (isUpdating) ...[
                    const SizedBox(height: 10),
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusActionButton extends StatelessWidget {
  const _StatusActionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final button = selected
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 15),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            style: FilledButton.styleFrom(
              backgroundColor: AdminPanelColors.gold,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(
              icon,
              size: 15,
              color: AdminPanelColors.textMuted.withValues(alpha: 0.95),
            ),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminPanelColors.textLight,
              side: BorderSide(
                color: AdminPanelColors.gold.withValues(alpha: 0.35),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              textStyle: const TextStyle(fontSize: 11.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

    return SizedBox(height: 40, child: button);
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
            'لا توجد طلبات نشطة',
            style: TextStyle(
              color: AdminPanelColors.textLight,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر الطلبات النشطة هنا فوراً دون تحديث الصفحة',
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
