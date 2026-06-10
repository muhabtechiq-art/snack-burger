import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tenant_palette.dart';
import '../../models/delivery_order_model.dart';
import '../../services/supabase_order_service.dart';
import '../../state/active_restaurant_notifier.dart';
import '../data/admin_repositories.dart';
import '../orders/pending_order_actions.dart';
import '../orders/pending_orders_notification_coordinator.dart';
import '../orders/widgets/rejected_order_reason_sheet.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';

/// لوحة إدارة الطلبات — تبويب جديد / مرفوض مع بث Supabase.
class OrdersDashboardScreen extends StatefulWidget {
  const OrdersDashboardScreen({super.key, required this.slug});

  final String slug;

  @override
  State<OrdersDashboardScreen> createState() => _OrdersDashboardScreenState();
}

class _OrdersDashboardScreenState extends State<OrdersDashboardScreen>
    with SingleTickerProviderStateMixin {
  final AdminOrderRepository _orderRepository = AdminOrderRepository();
  final PendingOrderActions _orderActions = PendingOrderActions();
  final PendingOrdersNotificationCoordinator _notifications =
      PendingOrdersNotificationCoordinator();

  final Set<String> _locallyRemovedIds = {};
  final Set<String> _rejectingOrderIds = {};

  late final TabController _tabController;

  String? _streamKey;
  Stream<List<DeliveryOrder>>? _ordersStream;
  StreamHealth _streamHealth = StreamHealth.connecting;

  bool get _isLive => _streamHealth == StreamHealth.live;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    unawaited(SupabaseOrderService.purgeOldRejectedOrders());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notifications.reset();
    super.dispose();
  }

  void _onOrderRemovedFromPending(String orderId) {
    setState(() => _locallyRemovedIds.add(orderId));
  }

  void _onOrderAcceptFailed(String orderId) {
    setState(() => _locallyRemovedIds.remove(orderId));
  }

  Future<void> _openOrderDialog({
    required DeliveryOrder order,
    required TenantPalette palette,
  }) {
    return _orderActions.showOrderDialog(
      context: context,
      order: order,
      palette: palette,
      onOrderRemovedFromPending: () => _onOrderRemovedFromPending(order.id),
      onOrderAcceptFailed: () => _onOrderAcceptFailed(order.id),
    );
  }

  Future<void> _quickRejectOrder(DeliveryOrder order) async {
    if (_rejectingOrderIds.contains(order.id) || !order.isPending) return;

    setState(() {
      _rejectingOrderIds.add(order.id);
      _locallyRemovedIds.add(order.id);
    });

    try {
      await _orderActions.rejectOrder(
        order: order,
        showSnackBar: false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rejectingOrderIds.remove(order.id);
        _locallyRemovedIds.remove(order.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر رفض الطلب: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _rejectingOrderIds.remove(order.id));
      }
    }
  }

  void _openRejectedOrderDetails({
    required DeliveryOrder order,
    required TenantPalette palette,
  }) {
    RejectedOrderReasonSheet.show(
      context: context,
      order: order,
      palette: palette,
      orderRepository: _orderRepository,
    );
  }

  ({List<DeliveryOrder> pending, List<DeliveryOrder> rejected}) _lists(
    List<DeliveryOrder> fromStream,
  ) {
    _locallyRemovedIds.removeWhere(
      (id) => !fromStream.any((order) => order.id == id),
    );

    final pending = <DeliveryOrder>[];
    final rejected = <DeliveryOrder>[];

    for (final order in fromStream) {
      if (order.isPending && !_locallyRemovedIds.contains(order.id)) {
        pending.add(order);
      } else if (order.isRejected) {
        rejected.add(order);
      }
    }

    pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    rejected.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (pending: pending, rejected: rejected);
  }

  void _handleStreamData(List<DeliveryOrder> orders) {
    _notifications.onPendingOrdersUpdated(
      orders.where((o) => o.isPending).toList(),
    );
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
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      slug: widget.slug,
      title: 'إدارة الطلبات',
      body: Consumer<ActiveRestaurantNotifier>(
        builder: (context, tenant, _) {
          final restaurant = tenant.restaurant;
          if (restaurant == null) {
            return const Center(
              child: CircularProgressIndicator(color: AdminPanelColors.gold),
            );
          }

          final streamKey = '${restaurant.id}|${widget.slug}';
          final palette = TenantPalette.fromRestaurant(restaurant);
          if (_streamKey != streamKey || _ordersStream == null) {
            _streamKey = streamKey;
            _notifications.reset();
            _streamHealth = StreamHealth.connecting;
            _ordersStream = _orderRepository.watchKitchenDashboardOrders(
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
                _handleStreamData(rawOrders);
              });

              final lists = _lists(rawOrders);
              final pendingCount = lists.pending.length;
              final rejectedCount = lists.rejected.length;
              final awaitingReasonCount = lists.rejected
                  .where((order) => order.needsRejectionReason)
                  .length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DashboardHeader(health: _streamHealth),
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
                  Material(
                    color: AdminPanelColors.charcoalLight,
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AdminPanelColors.gold,
                      labelColor: AdminPanelColors.gold,
                      unselectedLabelColor: AdminPanelColors.textMuted,
                      tabs: [
                        Tab(
                          child: _TabLabel(
                            title: 'الطلبات الجديدة',
                            count: pendingCount,
                            highlight: pendingCount > 0,
                          ),
                        ),
                        Tab(
                          child: _TabLabel(
                            title: 'الطلبات المرفوضة',
                            count: rejectedCount,
                            highlight: awaitingReasonCount > 0,
                            badgeColor: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _OrdersListPane(
                          orders: lists.pending,
                          emptyMessage: 'لا توجد طلبات جديدة',
                          emptyHint:
                              'ستظهر الطلبات الجديدة هنا فور وصولها',
                          palette: palette,
                          isNewTab: true,
                          rejectingIds: _rejectingOrderIds,
                          onOrderTap: (order) => _openOrderDialog(
                            order: order,
                            palette: palette,
                          ),
                          onQuickReject: _quickRejectOrder,
                        ),
                        _OrdersListPane(
                          orders: lists.rejected,
                          emptyMessage: 'لا توجد طلبات مرفوضة',
                          emptyHint:
                              'الطلبات المرفوضة تنتقل هنا لتسجيل سبب الرفض',
                          palette: palette,
                          isNewTab: false,
                          rejectingIds: const {},
                          onOrderTap: (order) => _openRejectedOrderDetails(
                            order: order,
                            palette: palette,
                          ),
                        ),
                      ],
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

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.title,
    required this.count,
    required this.highlight,
    this.badgeColor,
  });

  final String title;
  final int count;
  final bool highlight;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: highlight
                  ? (badgeColor ?? Colors.red.shade700)
                  : AdminPanelColors.textMuted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrdersListPane extends StatelessWidget {
  const _OrdersListPane({
    required this.orders,
    required this.emptyMessage,
    required this.emptyHint,
    required this.palette,
    required this.isNewTab,
    required this.rejectingIds,
    required this.onOrderTap,
    this.onQuickReject,
  });

  final List<DeliveryOrder> orders;
  final String emptyMessage;
  final String emptyHint;
  final TenantPalette palette;
  final bool isNewTab;
  final Set<String> rejectingIds;
  final ValueChanged<DeliveryOrder> onOrderTap;
  final ValueChanged<DeliveryOrder>? onQuickReject;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _EmptyState(message: emptyMessage, hint: emptyHint);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _OrderCard(
            order: order,
            isNewTab: isNewTab,
            isRejecting: rejectingIds.contains(order.id),
            onTap: () => onOrderTap(order),
            onQuickReject:
                isNewTab && onQuickReject != null
                    ? () => onQuickReject!(order)
                    : null,
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.health});

  final StreamHealth health;

  @override
  Widget build(BuildContext context) {
    final isLive = health == StreamHealth.live;
    final title = switch (health) {
      StreamHealth.connecting => 'جاري الاتصال ببث الطلبات...',
      StreamHealth.live => 'متصل — التحديثات الفورية نشطة',
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
      StreamHealth.reconnecting =>
        'نعيد الاتصال تلقائياً الآن. يمكنك الانتظار أو إعادة الاتصال يدوياً.',
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.isNewTab,
    required this.isRejecting,
    required this.onTap,
    this.onQuickReject,
  });

  final DeliveryOrder order;
  final bool isNewTab;
  final bool isRejecting;
  final VoidCallback onTap;
  final VoidCallback? onQuickReject;

  @override
  Widget build(BuildContext context) {
    final borderColor = isNewTab
        ? AdminPanelColors.gold.withValues(alpha: 0.3)
        : (order.needsRejectionReason
            ? Colors.orange.withValues(alpha: 0.55)
            : Colors.red.withValues(alpha: 0.35));

    return Material(
      color: AdminPanelColors.charcoalLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: isRejecting ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: order.needsRejectionReason ? 1.5 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onQuickReject != null) ...[
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton.filled(
                    onPressed: isRejecting ? null : onQuickReject,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                    tooltip: 'رفض الطلب',
                    icon: isRejecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.close_rounded, size: 22),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                isNewTab
                    ? Icons.receipt_long_rounded
                    : Icons.block_rounded,
                color: isNewTab
                    ? AdminPanelColors.gold.withValues(alpha: 0.9)
                    : Colors.red.shade300,
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
                    const SizedBox(height: 6),
                    if (isNewTab)
                      Text(
                        'بانتظار التأكيد',
                        style: TextStyle(
                          color: AdminPanelColors.gold.withValues(alpha: 0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else if (order.needsRejectionReason)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'بانتظار سبب الرفض',
                          style: TextStyle(
                            color: Colors.orange.shade200,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else
                      Text(
                        order.rejectionReason ?? 'مرفوض',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: AdminPanelColors.textMuted.withValues(alpha: 0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
  const _EmptyState({required this.message, required this.hint});

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: AdminPanelColors.gold.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: AdminPanelColors.textLight,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AdminPanelColors.textMuted.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
          ],
        ),
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
