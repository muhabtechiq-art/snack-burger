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
  Future<void> onOrdersBatch(
    List<DeliveryOrder> orders, {
    required String source,
  }) async {
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

      // order.id هو مفتاح منع التكرار الوحيد (ليس الهاتف ولا الاسم).
      final alreadyNotified = _notifiedOrderIds.contains(order.id);
      debugPrint(
        '[QA][OrderSound] pending insert detected orderId=${order.id}',
      );
      debugPrint(
        '[QA][OrderSound] already notified? $alreadyNotified',
      );

      if (alreadyNotified) continue;

      // على Android/iOS يملك التنبيهَ OrderRealtimeNotificationService؛
      // نعلّمه هنا لتجنّب الازدواج، بلا تشغيل صوت داخل الـ coordinator.
      if (OrderRealtimeNotificationService.instance.handlesAlerts) {
        _rememberNotified(order.id);
        continue;
      }

      // لا نعلّم الطلب notified إلا بعد نجاح تشغيل الصوت، حتى تُعاد المحاولة
      // في الدفعة التالية إذا فشل التشغيل (جهاز صوت مشغول/استثناء).
      final played = await _playSoundForOrder(order.id);
      if (played) {
        _rememberNotified(order.id);
      }
    }
  }

  bool _isEligibleNewOrder(DeliveryOrder order, DateTime startedAt) {
    // المعيار الأساسي للجدّة هو order.id عبر baseline + _notifiedOrderIds؛
    // grace واسعة (30s) تمنع إسقاط طلب جديد بصمت بسبب فرق ساعة بسيط.
    final grace = startedAt.subtract(const Duration(seconds: 30));
    return !order.createdAt.toUtc().isBefore(grace);
  }

  /// يُرجِع true عند نجاح تشغيل الصوت فقط.
  Future<bool> _playSoundForOrder(String orderId) async {
    try {
      await OrderNotificationPlayer.playNewPendingOrder();
      return true;
    } catch (error, stack) {
      debugPrint(
        '[QA][OrderSound] playing sound failed error=$error\n$stack',
      );
      return false;
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
