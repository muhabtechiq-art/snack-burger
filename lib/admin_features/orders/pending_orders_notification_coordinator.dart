import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../models/delivery_order_model.dart';
import '../../services/order_realtime_notification_service.dart';
import 'order_notification_player.dart';

/// يكتشف الطلبات المعلقة الجديدة ويشغّل التنبيه مرة واحدة لكل [orderId].
class PendingOrdersNotificationCoordinator {
  PendingOrdersNotificationCoordinator({
    this.maxNotifiedIds = 100,
  });

  static const int defaultMaxNotifiedIds = 100;

  final int maxNotifiedIds;

  final LinkedHashSet<String> _notifiedOrderIds = LinkedHashSet<String>();
  DateTime? _listeningStartedAt;
  bool _baselineReady = false;

  DateTime? get listeningStartedAt => _listeningStartedAt;

  /// يُستدعى عند بدء الاستماع لأول مرة (وليس عند إعادة الاشتراك).
  void reset() {
    _notifiedOrderIds.clear();
    _listeningStartedAt = DateTime.now().toUtc();
    _baselineReady = false;
    debugPrint(
      '[QA][OrderSound] coordinator reset listeningStartedAt=$_listeningStartedAt',
    );
  }

  /// يُستدعى عند إيقاف الاستماع — بدون baseline جديد.
  void clear() {
    _notifiedOrderIds.clear();
    _listeningStartedAt = null;
    _baselineReady = false;
  }

  /// يُستدعى عند كل حدث Realtime أو دورة Polling.
  void onOrdersBatch(List<DeliveryOrder> orders, {required String source}) {
    final pending = orders.where((o) => o.isPending).toList(growable: false);

    for (final order in pending) {
      debugPrint(
        '[QA][OrderSound] realtime event received orderId=${order.id} source=$source',
      );
    }

    if (!_baselineReady) {
      for (final order in pending) {
        _rememberNotified(order.id);
      }
      _baselineReady = true;
      debugPrint(
        '[QA][OrderSound] initial baseline pending=${pending.length}',
      );
      return;
    }

    final startedAt = _listeningStartedAt;
    if (startedAt == null) return;

    for (final order in pending) {
      if (!_isEligibleNewOrder(order, startedAt)) continue;

      final alreadyNotified = _notifiedOrderIds.contains(order.id);
      debugPrint(
        '[QA][OrderSound] pending insert detected orderId=${order.id}',
      );
      debugPrint(
        '[QA][OrderSound] already notified? $alreadyNotified',
      );

      if (alreadyNotified) continue;

      _rememberNotified(order.id);

      if (OrderRealtimeNotificationService.instance.handlesAlerts) {
        continue;
      }

      unawaited(_playSoundForOrder(order.id));
    }
  }

  bool _isEligibleNewOrder(DeliveryOrder order, DateTime startedAt) {
    final grace = startedAt.subtract(const Duration(seconds: 2));
    return !order.createdAt.toUtc().isBefore(grace);
  }

  Future<void> _playSoundForOrder(String orderId) async {
    try {
      await OrderNotificationPlayer.playNewPendingOrder();
    } catch (error, stack) {
      debugPrint(
        '[QA][OrderSound] playing sound failed error=$error\n$stack',
      );
    }
  }

  void _rememberNotified(String orderId) {
    _notifiedOrderIds.remove(orderId);
    _notifiedOrderIds.add(orderId);
    while (_notifiedOrderIds.length > maxNotifiedIds) {
      _notifiedOrderIds.remove(_notifiedOrderIds.first);
    }
  }
}
