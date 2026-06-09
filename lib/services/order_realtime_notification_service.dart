import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/restaurant_ids.dart';
import '../models/delivery_order_model.dart';
import '../models/delivery_order_status.dart';
import 'supabase_order_service.dart';

/// استماع دائم لطلبات Supabase Realtime + تنبيهات محلية عالية الأولوية.
///
/// Singleton يُشغَّل من [main] ولا يتوقف عند تغيير الصفحات.
final class OrderRealtimeNotificationService {
  OrderRealtimeNotificationService._();

  static final OrderRealtimeNotificationService instance =
      OrderRealtimeNotificationService._();

  static const String _channelId = 'snack_burger_new_orders';
  static const String _channelName = 'طلبات جديدة';
  static const String _realtimeChannelName = 'orders-insert-listener';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  RealtimeChannel? _channel;
  String? _activeSlug;
  bool _initialized = false;
  bool _listening = false;

  final Set<String> _notifiedOrderIds = <String>{};

  bool get isListening => _listening;

  /// يُفعَّل على Android/iOS فقط — التنبيهات المحلية لا تُستخدم على سطح المكتب.
  bool get handlesAlerts =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool wasOrderNotified(String orderId) =>
      _notifiedOrderIds.contains(orderId.trim());

  Future<void> initialize() async {
    if (!handlesAlerts || _initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _notifications.initialize(settings: initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'تنبيه فوري عند وصول طلب توصيل جديد',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alert'),
      enableVibration: true,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[OrderRealtimeNotificationService] initialized');
  }

  /// يبدأ الاستماع لـ INSERT على جدول `orders` للمطعم المحدد.
  Future<void> start({String slug = RestaurantIds.snackBurgerSlug}) async {
    if (!handlesAlerts) return;
    if (!_initialized) await initialize();

    final normalizedSlug = slug.trim().toLowerCase();
    if (_listening && _activeSlug == normalizedSlug) return;

    await stop();

    _activeSlug = normalizedSlug;
    _channel = Supabase.instance.client
        .channel('$_realtimeChannelName:$normalizedSlug')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseOrderService.tableName,
          callback: _onOrderInserted,
        )
        .subscribe((status, [error]) {
      debugPrint(
        '[OrderRealtimeNotificationService] channel status=$status '
        'slug=$normalizedSlug error=$error',
      );
    });

    _listening = true;
    debugPrint(
      '[OrderRealtimeNotificationService] listening INSERT slug=$normalizedSlug',
    );
  }

  Future<void> stop() async {
    final channel = _channel;
    _channel = null;
    _activeSlug = null;
    _listening = false;

    if (channel != null) {
      await Supabase.instance.client.removeChannel(channel);
      debugPrint('[OrderRealtimeNotificationService] stopped');
    }
  }

  void _onOrderInserted(PostgresChangePayload payload) {
    final record = payload.newRecord;
    if (record.isEmpty) return;

    DeliveryOrder? order;
    try {
      order = DeliveryOrder.fromSupabase(Map<String, dynamic>.from(record));
    } catch (e, stack) {
      debugPrint(
        '[OrderRealtimeNotificationService] parse INSERT failed: $e\n$stack',
      );
      return;
    }

    if (order.id.trim().isEmpty) return;
    if (_notifiedOrderIds.contains(order.id)) return;

    if (order.status.trim().toLowerCase() != DeliveryOrderStatus.pending) {
      return;
    }

    final slug = _activeSlug ?? RestaurantIds.snackBurgerSlug;
    if (!SupabaseOrderService.orderMatchesSlug(order, slug)) return;

    _notifiedOrderIds.add(order.id);
    unawaited(_showNewOrderNotification(order));
  }

  Future<void> _showNewOrderNotification(DeliveryOrder order) async {
    if (!_initialized) return;

    final notificationId = order.id.hashCode & 0x7fffffff;
    final body =
        '${order.customerName.trim()} — '
        '${order.totalPrice.toStringAsFixed(0)} د.ع';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'تنبيه فوري عند وصول طلب توصيل جديد',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alert'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      ticker: 'طلب جديد',
    );

    await _notifications.show(
      id: notificationId,
      title: 'طلب جديد!',
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );

    debugPrint(
      '[OrderRealtimeNotificationService] notified order=${order.id}',
    );
  }
}
