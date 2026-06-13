import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/delivery_order_model.dart';
import '../../services/order_realtime_notification_service.dart';
import 'order_notification_player.dart';

/// يكتشف الطلبات المعلقة الجديدة ويشغّل التنبيه مرة واحدة لكل طلب.
class PendingOrdersNotificationCoordinator {
  PendingOrdersNotificationCoordinator({
    this.recentOrderWindow = const Duration(minutes: 10),
  });

  /// يُعتبر الطلب «جديداً» إذا كان `created_at` ضمن هذه النافذة.
  final Duration recentOrderWindow;

  final Set<String> _knownPendingIds = {};
  final Set<String> _notifiedOrderIds = {};
  bool _baselineReady = false;

  /// يُستدعى عند كل حدث من بث Supabase (ليس من `build` مباشرة).
  void onPendingOrdersUpdated(List<DeliveryOrder> orders) {
    final currentIds = orders.map((o) => o.id).toSet();

    if (!_baselineReady) {
      _knownPendingIds
        ..clear()
        ..addAll(currentIds);
      _notifiedOrderIds.addAll(currentIds);
      _baselineReady = true;
      debugPrint(
        '[QA][OrderSound] initial baseline pending=${currentIds.length}',
      );
      return;
    }

    for (final order in orders) {
      final isNew = !_knownPendingIds.contains(order.id);
      final notYetNotified = !_notifiedOrderIds.contains(order.id);
      final isRecent = _isRecentlyCreated(order);

      if (isNew && notYetNotified && isRecent) {
        debugPrint(
          '[QA][OrderSound] new pending order detected id=${order.id}',
        );
        _notifiedOrderIds.add(order.id);
        // على الجوال: التنبيه يأتي من OrderRealtimeNotificationService فقط.
        if (!OrderRealtimeNotificationService.instance.handlesAlerts) {
          unawaited(
            OrderNotificationPlayer.playNewPendingOrder().then((_) {
              debugPrint(
                '[QA][OrderSound] sound played id=${order.id}',
              );
            }),
          );
        }
      }
    }

    _knownPendingIds
      ..clear()
      ..addAll(currentIds);

    _notifiedOrderIds.removeWhere((id) => !currentIds.contains(id));
  }

  bool _isRecentlyCreated(DeliveryOrder order) {
    final age = DateTime.now().difference(order.createdAt.toLocal());
    return !age.isNegative && age <= recentOrderWindow;
  }

  void reset() {
    _knownPendingIds.clear();
    _notifiedOrderIds.clear();
    _baselineReady = false;
  }
}
