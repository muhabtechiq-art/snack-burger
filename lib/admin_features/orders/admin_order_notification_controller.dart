import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/delivery_order_model.dart';
import '../../services/supabase_order_service.dart';
import '../data/admin_repositories.dart';
import 'order_notification_player.dart';
import 'pending_orders_notification_coordinator.dart';

/// استماع عالمي لتنبيه صوت الطلبات المعلقة داخل لوحة الإدارة.
///
/// Singleton — Realtime + Polling احتياطي، بدون تكرار اشتراك.
final class AdminOrderNotificationController {
  AdminOrderNotificationController._();

  static final AdminOrderNotificationController instance =
      AdminOrderNotificationController._();

  static const Duration _pollingInterval = Duration(seconds: 15);
  static const Duration _reconnectDelay = Duration(seconds: 2);
  static const Duration _streamWatchdogInterval = Duration(seconds: 30);
  static const Duration _streamStaleAfter = Duration(seconds: 90);

  final AdminOrderRepository _repository = AdminOrderRepository();
  final PendingOrdersNotificationCoordinator _coordinator =
      PendingOrdersNotificationCoordinator();

  StreamSubscription<List<DeliveryOrder>>? _subscription;
  Timer? _pollingTimer;
  Timer? _watchdogTimer;
  Timer? _reconnectTimer;

  String? _activeStreamKey;
  String? _restaurantId;
  String? _slug;
  bool _starting = false;
  bool _reconnectScheduled = false;
  StreamHealth _lastHealth = StreamHealth.connecting;
  DateTime? _lastStreamEventAt;

  bool get isListening => _subscription != null;

  /// يبدأ الاستماع مرة واحدة لكل مطعم — آمن عند استدعائه من كل [AdminWrapper].
  Future<void> ensureListening({
    required String restaurantId,
    required String slug,
  }) async {
    final key = '${restaurantId.trim()}|${slug.trim()}';
    if (_activeStreamKey == key && _subscription != null) {
      _logSubscriptionStatus('active');
      return;
    }
    if (_starting) return;

    _starting = true;
    try {
      await stop(logDisposed: false);

      _restaurantId = restaurantId;
      _slug = slug;
      _activeStreamKey = key;
      _coordinator.reset();

      debugPrint('[QA][OrderSound] listener started key=$key');
      await _subscribeRealtime();
      _startPolling();
      _startWatchdog();
    } finally {
      _starting = false;
    }
  }

  Future<void> _subscribeRealtime() async {
    final restaurantId = _restaurantId;
    final slug = _slug;
    if (restaurantId == null || slug == null) return;

    await _subscription?.cancel();
    _subscription = null;
    _logSubscriptionStatus('connecting');

    _subscription = _repository
        .watchPendingOrders(
          restaurantId: restaurantId,
          slug: slug,
          onHealthChanged: _onStreamHealth,
        )
        .listen(
          _onPendingOrdersRealtime,
          onError: _onStreamError,
          cancelOnError: false,
        );

    _lastStreamEventAt = DateTime.now();
    _logSubscriptionStatus('subscribed');
  }

  void _onPendingOrdersRealtime(List<DeliveryOrder> orders) {
    _lastStreamEventAt = DateTime.now();
    _coordinator.onOrdersBatch(orders, source: 'realtime');
  }

  void _onStreamHealth(StreamHealth health) {
    _lastHealth = health;
    debugPrint('[QA][OrderSound] stream health=$health');
    _logSubscriptionStatus(health.name);

    if (health == StreamHealth.error || health == StreamHealth.stale) {
      _scheduleReconnect(reason: health.name);
    }
  }

  void _onStreamError(Object error, StackTrace stack) {
    debugPrint('[QA][OrderSound] stream error: $error\n$stack');
    _logSubscriptionStatus('error');
    _scheduleReconnect(reason: 'stream_error');
  }

  void _scheduleReconnect({required String reason}) {
    if (_reconnectScheduled || _activeStreamKey == null || _restaurantId == null) {
      return;
    }

    _reconnectScheduled = true;
    debugPrint('[QA][OrderSound] reconnect requested reason=$reason');
    _logSubscriptionStatus('reconnect_scheduled');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      _reconnectScheduled = false;
      if (_restaurantId == null || _slug == null || _activeStreamKey == null) {
        return;
      }
      try {
        await _subscribeRealtime();
        debugPrint('[QA][OrderSound] reconnect completed');
      } catch (error, stack) {
        debugPrint('[QA][OrderSound] reconnect failed error=$error\n$stack');
        _scheduleReconnect(reason: 'reconnect_failed');
      }
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      unawaited(_pollPendingOrders());
    });
    unawaited(_pollPendingOrders());
  }

  Future<void> _pollPendingOrders() async {
    final restaurantId = _restaurantId;
    final slug = _slug;
    final startedAt = _coordinator.listeningStartedAt;
    if (restaurantId == null || slug == null || startedAt == null) return;

    try {
      final orders = await _repository.fetchPendingOrdersCreatedAfter(
        restaurantId: restaurantId,
        slug: slug,
        after: startedAt,
      );
      _coordinator.onOrdersBatch(orders, source: 'polling');
    } catch (error, stack) {
      debugPrint('[QA][OrderSound] polling failed error=$error\n$stack');
    }
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(_streamWatchdogInterval, (_) {
      final lastEvent = _lastStreamEventAt;
      if (lastEvent == null) return;
      final idleFor = DateTime.now().difference(lastEvent);
      if (idleFor > _streamStaleAfter &&
          _lastHealth != StreamHealth.reconnecting) {
        debugPrint(
          '[QA][OrderSound] stream watchdog stale idle=${idleFor.inSeconds}s',
        );
        _scheduleReconnect(reason: 'watchdog_stale');
      }
    });
  }

  void _logSubscriptionStatus(String status) {
    debugPrint('[QA][OrderSound] subscription status=$status');
  }

  /// يُستدعى عند تسجيل الخروج أو مغادرة وضع الإدارة.
  Future<void> stop({bool logDisposed = true}) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectScheduled = false;

    _pollingTimer?.cancel();
    _pollingTimer = null;

    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    await _subscription?.cancel();
    _subscription = null;

    _activeStreamKey = null;
    _restaurantId = null;
    _slug = null;
    _lastStreamEventAt = null;
    _lastHealth = StreamHealth.disposed;
    _coordinator.clear();

    await OrderNotificationPlayer.dispose();

    _logSubscriptionStatus('stopped');
    if (logDisposed) {
      debugPrint('[QA][OrderSound] listener disposed');
    }
  }
}
