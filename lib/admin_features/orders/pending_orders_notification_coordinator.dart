import '../../models/delivery_order_model.dart';
import 'order_notification_player.dart';

/// يكتشف الطلبات المعلقة الجديدة ويشغّل التنبيه مرة واحدة لكل طلب.
class PendingOrdersNotificationCoordinator {
  PendingOrdersNotificationCoordinator({
    this.recentOrderWindow = const Duration(minutes: 10),
  });

  /// يُعتبر الطلب «جديداً» إذا كان `created_at` ضمن هذه النافذة.
  final Duration recentOrderWindow;

  final Set<String> _knownPendingIds = {};
  final Set<String> _alertedOrderIds = {};
  bool _baselineReady = false;

  /// يُستدعى عند كل حدث من بث Supabase (ليس من `build` مباشرة).
  void onPendingOrdersUpdated(List<DeliveryOrder> orders) {
    final currentIds = orders.map((o) => o.id).toSet();

    if (!_baselineReady) {
      _knownPendingIds
        ..clear()
        ..addAll(currentIds);
      _baselineReady = true;
      return;
    }

    for (final order in orders) {
      final isNew = !_knownPendingIds.contains(order.id);
      final notYetAlerted = !_alertedOrderIds.contains(order.id);
      final isRecent = _isRecentlyCreated(order);

      if (isNew && notYetAlerted && isRecent) {
        _alertedOrderIds.add(order.id);
        OrderNotificationPlayer.playNewPendingOrder();
      }
    }

    _knownPendingIds
      ..clear()
      ..addAll(currentIds);
  }

  bool _isRecentlyCreated(DeliveryOrder order) {
    final age = DateTime.now().difference(order.createdAt.toLocal());
    return !age.isNegative && age <= recentOrderWindow;
  }

  void reset() {
    _knownPendingIds.clear();
    _alertedOrderIds.clear();
    _baselineReady = false;
  }
}
