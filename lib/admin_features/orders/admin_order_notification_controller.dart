import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/delivery_order_model.dart';
import '../../services/supabase_order_service.dart';
import '../data/admin_repositories.dart';
import 'pending_orders_notification_coordinator.dart';

/// استماع عالمي لتنبيه صوت الطلبات المعلقة داخل لوحة الإدارة.
///
/// Singleton — لا يُعاد إنشاؤه عند التنقل بين صفحات الإدارة.
final class AdminOrderNotificationController {
  AdminOrderNotificationController._();

  static final AdminOrderNotificationController instance =
      AdminOrderNotificationController._();

  final AdminOrderRepository _repository = AdminOrderRepository();
  final PendingOrdersNotificationCoordinator _coordinator =
      PendingOrdersNotificationCoordinator();

  StreamSubscription<List<DeliveryOrder>>? _subscription;
  String? _activeStreamKey;
  bool _starting = false;

  bool get isListening => _subscription != null;

  /// يبدأ الاستماع مرة واحدة لكل مطعم — آمن عند استدعائه من كل [AdminWrapper].
  Future<void> ensureListening({
    required String restaurantId,
    required String slug,
  }) async {
    final key = '${restaurantId.trim()}|${slug.trim()}';
    if (_activeStreamKey == key && _subscription != null) return;
    if (_starting) return;

    _starting = true;
    try {
      await stop(logDisposed: false);

      debugPrint('[QA][OrderSound] listener started key=$key');
      _activeStreamKey = key;
      _coordinator.reset();

      _subscription = _repository
          .watchPendingOrders(
            restaurantId: restaurantId,
            slug: slug,
            onHealthChanged: _onStreamHealth,
          )
          .listen(
            _onPendingOrders,
            onError: _onStreamError,
            cancelOnError: false,
          );
    } finally {
      _starting = false;
    }
  }

  void _onPendingOrders(List<DeliveryOrder> orders) {
    final pending = orders.where((o) => o.isPending).toList();
    _coordinator.onPendingOrdersUpdated(pending);
  }

  void _onStreamHealth(StreamHealth health) {
    if (health == StreamHealth.live ||
        health == StreamHealth.reconnecting ||
        health == StreamHealth.error ||
        health == StreamHealth.stale) {
      debugPrint('[QA][OrderSound] stream health=$health');
    }
  }

  void _onStreamError(Object error, StackTrace stack) {
    debugPrint('[QA][OrderSound] stream error: $error\n$stack');
  }

  /// يُستدعى عند تسجيل الخروج أو مغادرة وضع الإدارة.
  Future<void> stop({bool logDisposed = true}) async {
    await _subscription?.cancel();
    _subscription = null;
    _activeStreamKey = null;
    _coordinator.reset();
    if (logDisposed) {
      debugPrint('[QA][OrderSound] listener disposed');
    }
  }
}
