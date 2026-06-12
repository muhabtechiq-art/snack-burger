import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/customer_my_orders_config.dart';
import '../core/config/location_feature_flags.dart';
import '../core/config/rejected_orders_config.dart';
import '../core/observability/app_telemetry.dart';
import '../core/utils/model_parse_validation.dart';
import '../core/utils/iraqi_phone_validator.dart';
import '../core/config/restaurant_ids.dart';
import '../core/config/stability_phase1_flags.dart';
import '../core/utils/delivery_coordinates.dart';
import '../models/delivery_order_model.dart';
import '../models/delivery_order_status.dart';
import 'supabase_error_reporter.dart';
import '../models/end_of_day_report_model.dart';
import '../models/order_model.dart';

/// إنشاء وقراءة وتحديث طلبات جدول `orders` في Supabase.
abstract final class SupabaseOrderService {
  SupabaseOrderService._();

  static const String tableName = 'orders';

  static SupabaseClient get _client => Supabase.instance.client;
  static const Duration _streamReconnectBaseDelay = Duration(seconds: 1);
  static const Duration _streamReconnectMaxDelay = Duration(seconds: 20);

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// يُرجع UUID صالحاً فقط — يتجاهل slug مثل `snack_burger`.
  static String? _resolveRestaurantUuid(String restaurantId) {
    final trimmed = restaurantId.trim();
    if (trimmed.isEmpty || !_uuidPattern.hasMatch(trimmed)) {
      return null;
    }
    return trimmed.toLowerCase();
  }

  static String? _resolveLocationCoordinates({
    required double? latitude,
    required double? longitude,
  }) {
    if (!LocationFeatureFlags.enabled) return null;
    if (latitude == null || longitude == null) {
      throw ArgumentError(
        'إحداثيات التوصيل مطلوبة — حدّد الموقع بدقة قبل الإرسال.',
      );
    }
    return DeliveryCoordinates.format(latitude, longitude);
  }

  static Map<String, dynamic> _buildSubmitPayload({
    required String? resolvedRestaurantUuid,
    required String rawRestaurantId,
    required String normalizedSlug,
    required String customerName,
    required String customerPhone,
    required String address,
    required List<Map<String, dynamic>> orderItems,
    required double totalPrice,
    String? locationCoordinates,
  }) {
    final payload = <String, dynamic>{
      'customer_name': customerName.trim(),
      'phone_number': customerPhone.trim(),
      'address': address.trim(),
      'total_price': totalPrice,
      'order_items': orderItems,
      'status': DeliveryOrderStatus.pending,
    };

    if (resolvedRestaurantUuid != null) {
      payload['restaurant_id'] = resolvedRestaurantUuid;
    } else if (rawRestaurantId.trim().isNotEmpty) {
      debugPrint(
        '[SupabaseOrderService] تخطي restaurant_id — القيمة ليست UUID: '
        '${rawRestaurantId.trim()}',
      );
    }

    if (normalizedSlug.isNotEmpty) {
      payload['slug'] = normalizedSlug;
    }

    if (locationCoordinates != null) {
      payload['location_coordinates'] = locationCoordinates;
    }

    return payload;
  }

  static ValueChanged<StreamHealth>? _streamHealthCallback(
    ValueChanged<StreamHealth>? onHealthChanged,
  ) {
    return StabilityPhase1Flags.enablePhase1HealthSignals
        ? onHealthChanged
        : null;
  }

  /// يحفظ طلباً جديداً ويعيد معرّف الصف.
  static Future<String> submitOrder({
    required String restaurantId,
    required String slug,
    required String customerName,
    required String customerPhone,
    required String address,
    double? latitude,
    double? longitude,
    required List<CartItem> items,
    required double totalPrice,
  }) async {
    final correlationId = AppTelemetry.newCorrelationId(scope: 'order_submit');
    final orderItems = items.map((item) => item.toMap()).toList();
    final locationCoordinates = _resolveLocationCoordinates(
      latitude: latitude,
      longitude: longitude,
    );
    final resolvedRestaurantUuid =
        _resolveRestaurantUuid(restaurantId) ??
        _resolveRestaurantUuid(RestaurantIds.snackBurgerUuid ?? '');
    final normalizedSlug = slug.trim();

    final payload = _buildSubmitPayload(
      resolvedRestaurantUuid: resolvedRestaurantUuid,
      rawRestaurantId: restaurantId,
      normalizedSlug: normalizedSlug,
      customerName: customerName,
      customerPhone: customerPhone,
      address: address,
      orderItems: orderItems,
      totalPrice: totalPrice,
      locationCoordinates: locationCoordinates,
    );

    debugPrint(
      '[SupabaseOrderService] submitOrder — '
      'restaurantUuid=${resolvedRestaurantUuid ?? 'null'}, '
      'slug=$normalizedSlug, ${orderItems.length} عنصر، total=$totalPrice',
    );
    AppTelemetry.logEvent(
      'order_submit_started',
      correlationId: correlationId,
      fields: <String, Object?>{
        'slug': normalizedSlug,
        'items_count': orderItems.length,
        'total_price': totalPrice,
      },
    );

    try {
      final row = await _client
          .from(tableName)
          .insert(payload)
          .select('id')
          .single();

      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) {
        throw StateError('لم يُرجَع id بعد إدراج الطلب في Supabase.');
      }

      debugPrint('[SupabaseOrderService] تم حفظ الطلب: $id');
      AppTelemetry.logEvent(
        'order_submit_succeeded',
        correlationId: correlationId,
        fields: <String, Object?>{'order_id': id},
      );
      return id;
    } catch (e, stack) {
      debugPrint('[SupabaseOrderService] submitOrder فشل: $e\n$stack');
      AppTelemetry.logError(
        'order_submit_failed',
        correlationId: correlationId,
        error: e,
        stackTrace: stack,
        fields: <String, Object?>{'slug': normalizedSlug},
      );
      reportSupabaseError(e, stack, operation: 'submitOrder');
      rethrow;
    }
  }

  /// بث الطلبات ذات الحالة `pending`.
  static Stream<List<DeliveryOrder>> watchPendingOrders({
    required String slug,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    if (!StabilityPhase1Flags.enablePhase1RealtimeHardening) {
      return _legacyWatchPendingOrders(slug: slug);
    }
    final normalized = _normalizeSlug(slug);

    // بث كل التغييرات ثم فلترة pending محلياً — يزيل الطلب فور تحديث الحالة إلى accepted.
    return _resilientOrdersStream(
      sourceFactory: () =>
          _client.from(tableName).stream(primaryKey: const ['id']),
      transform: (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) =>
            order.status == DeliveryOrderStatus.pending &&
            _orderMatchesSlug(order, normalized),
        compare: (a, b) => a.createdAt.compareTo(b.createdAt),
        logParseErrors: true,
      ),
      streamTag: 'watchPendingOrders(slug=$normalized)',
      onHealthChanged: _streamHealthCallback(onHealthChanged),
    );
  }

  /// بث تفاصيل طلب واحد بالمعرّف لدعم شاشة تتبع الزبون.
  static Stream<DeliveryOrder?> watchOrderById({
    required String orderId,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    if (!StabilityPhase1Flags.enablePhase1RealtimeHardening) {
      return _legacyWatchOrderById(orderId: orderId);
    }
    final normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) {
      return const Stream<DeliveryOrder?>.empty();
    }

    return _resilientOrdersStream(
      sourceFactory: () => _client
          .from(tableName)
          .stream(primaryKey: const ['id']).eq('id', normalizedOrderId),
      transform: (rows) {
        if (rows.isEmpty) return null;
        return _tryParseOrderRow(
          rows.first,
          rowIdForLog: normalizedOrderId,
        );
      },
      streamTag: 'watchOrderById(orderId=$normalizedOrderId)',
      onHealthChanged: _streamHealthCallback(onHealthChanged),
    );
  }

  /// بث طلبات الزبون حسب رقم الهاتف والمطعم (جدول `orders`).
  static Stream<List<DeliveryOrder>> watchOrdersByPhone({
    required String slug,
    required String phoneNumber,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    final normalizedSlug = _normalizeSlug(slug);
    final normalizedPhone = IraqiPhoneValidator.normalize(phoneNumber);
    if (normalizedPhone.isEmpty) {
      return const Stream<List<DeliveryOrder>>.empty();
    }

    if (!StabilityPhase1Flags.enablePhase1RealtimeHardening) {
      return _legacyWatchOrdersByPhone(
        slug: normalizedSlug,
        phoneNumber: normalizedPhone,
      );
    }

    return _resilientOrdersStream(
      sourceFactory: () => _watchRecentOrderRows(),
      transform: (rows) => _filterOrdersByPhoneAndSlug(
        rows: rows,
        normalizedSlug: normalizedSlug,
        normalizedPhone: normalizedPhone,
      ),
      streamTag: 'watchOrdersByPhone(slug=$normalizedSlug)',
      onHealthChanged: _streamHealthCallback(onHealthChanged),
    );
  }

  /// بث كل الطلبات النشطة (غير المُسلّمة/الملغية) مع فلترة المطعم.
  static Stream<List<DeliveryOrder>> watchActiveOrders({
    required String slug,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    if (!StabilityPhase1Flags.enablePhase1RealtimeHardening) {
      return _legacyWatchActiveOrders(slug: slug);
    }
    final normalized = _normalizeSlug(slug);

    return _resilientOrdersStream(
      sourceFactory: () =>
          _client.from(tableName).stream(primaryKey: const ['id']),
      transform: (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) =>
            _activeOrderStatuses.contains(order.status) &&
            _orderMatchesSlug(order, normalized),
        compare: (a, b) => b.createdAt.compareTo(a.createdAt),
      ),
      streamTag: 'watchActiveOrders(slug=$normalized)',
      onHealthChanged: _streamHealthCallback(onHealthChanged),
    );
  }

  static const Set<String> _closingCountableStatuses = {
    DeliveryOrderStatus.accepted,
    DeliveryOrderStatus.preparing,
    DeliveryOrderStatus.delivering,
    DeliveryOrderStatus.delivered,
  };

  static const Set<String> _activeOrderStatuses = {
    DeliveryOrderStatus.pending,
    DeliveryOrderStatus.accepted,
    DeliveryOrderStatus.preparing,
    DeliveryOrderStatus.delivering,
  };

  /// يمسح الطلبات المرفوضة الأقدم من اليوم — RPC في Supabase.
  static Future<void> purgeOldRejectedOrders() async {
    try {
      final deleted = await _client.rpc<int>('purge_old_rejected_orders');
      debugPrint(
        '[SupabaseOrderService] purge_old_rejected_orders → $deleted صف',
      );
    } catch (e, stack) {
      debugPrint(
        '[SupabaseOrderService] purge_old_rejected_orders تخطي: $e\n$stack',
      );
    }
  }

  /// طلبات «طلباتي»: غير المرفوض ضمن نافذة 6 ساعات؛ المرفوض اليوم فقط.
  static bool _includeCustomerPhoneOrder(DeliveryOrder order) {
    if (order.isRejected) {
      return RejectedOrdersConfig.isCreatedOnLocalDay(order.createdAt);
    }
    return CustomerMyOrdersConfig.isOrderVisibleToCustomer(order.createdAt);
  }

  /// لوحة الإدارة: معلّق كما هو؛ مرفوض من اليوم المحلي فقط.
  static bool _includeKitchenDashboardOrder(
    DeliveryOrder order,
    String normalizedSlug,
  ) {
    if (!_orderMatchesSlug(order, normalizedSlug)) return false;
    if (order.isPending) return true;
    if (order.isRejected) {
      return RejectedOrdersConfig.isCreatedOnLocalDay(order.createdAt);
    }
    return false;
  }

  /// بث طلبات المطبخ: معلّقة + مرفوضة (لتبويبي لوحة الإدارة).
  static Stream<List<DeliveryOrder>> watchKitchenDashboardOrders({
    required String slug,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    if (!StabilityPhase1Flags.enablePhase1RealtimeHardening) {
      return _legacyWatchKitchenDashboardOrders(slug: slug);
    }
    final normalized = _normalizeSlug(slug);

    return _resilientOrdersStream(
      sourceFactory: () =>
          _client.from(tableName).stream(primaryKey: const ['id']),
      transform: (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) => _includeKitchenDashboardOrder(order, normalized),
        compare: (a, b) => b.createdAt.compareTo(a.createdAt),
      ),
      streamTag: 'watchKitchenDashboardOrders(slug=$normalized)',
      onHealthChanged: _streamHealthCallback(onHealthChanged),
    );
  }

  /// طلبات اليوم المحلية المقبولة/قيد التوصيل/المُسلّمة — لتقرير الإغلاق.
  static Future<EndOfDayReport> fetchTodayClosingReport({
    required String slug,
    DateTime? day,
  }) async {
    final localDay = day ?? DateTime.now();
    final dayStart = DateTime(localDay.year, localDay.month, localDay.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final normalized = _normalizeSlug(slug);

    try {
      final rows = await _client
          .from(tableName)
          .select()
          .gte('created_at', dayStart.toUtc().toIso8601String())
          .lt('created_at', dayEnd.toUtc().toIso8601String())
          .order('created_at', ascending: false);

      final orders = _mapRowsToOrders(
        rows: List<Map<String, dynamic>>.from(rows),
        include: (order) =>
            _closingCountableStatuses.contains(order.status) &&
            _orderMatchesSlug(order, normalized),
        logParseErrors: true,
      );

      var totalSales = 0.0;
      final lineAggregates = <String, ClosingProductLine>{};

      for (final order in orders) {
        totalSales += order.totalPrice;
        for (final item in order.items) {
          final name = item.printableName.trim();
          if (name.isEmpty) continue;

          final key = '$name|${item.unitPrice}';
          final existing = lineAggregates[key];
          if (existing == null) {
            lineAggregates[key] = ClosingProductLine(
              productName: name,
              quantitySold: item.quantity,
              unitPrice: item.unitPrice,
            );
          } else {
            lineAggregates[key] = ClosingProductLine(
              productName: name,
              quantitySold: existing.quantitySold + item.quantity,
              unitPrice: item.unitPrice,
            );
          }
        }
      }

      final productLines = lineAggregates.values.toList()
        ..sort((a, b) => a.productName.compareTo(b.productName));

      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint(
        '[SupabaseOrderService] تقرير إغلاق $dayStart — '
        '${orders.length} طلب، $totalSales د.ع، '
        '${productLines.length} منتج',
      );

      return EndOfDayReport(
        reportDate: dayStart,
        orderCount: orders.length,
        totalSales: totalSales,
        productLines: productLines,
        orders: orders,
      );
    } catch (e, stack) {
      debugPrint('[SupabaseOrderService] fetchTodayClosingReport فشل: $e\n$stack');
      reportSupabaseError(e, stack, operation: 'fetchTodayClosingReport');
      rethrow;
    }
  }

  /// تحديث حالة الطلب.
  static Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final correlationId = AppTelemetry.newCorrelationId(scope: 'order_status');
    try {
      await _client.from(tableName).update({
        'status': status,
      }).eq('id', orderId);
      debugPrint('[SupabaseOrderService] تحديث حالة $orderId → $status');
      AppTelemetry.logEvent(
        'order_status_updated',
        correlationId: correlationId,
        fields: <String, Object?>{
          'order_id': orderId,
          'status': status,
        },
      );
    } catch (e, stack) {
      debugPrint('[SupabaseOrderService] updateOrderStatus فشل: $e\n$stack');
      AppTelemetry.logError(
        'order_status_update_failed',
        correlationId: correlationId,
        error: e,
        stackTrace: stack,
        fields: <String, Object?>{
          'order_id': orderId,
          'status': status,
        },
      );
      reportSupabaseError(e, stack, operation: 'updateOrderStatus');
      rethrow;
    }
  }

  /// حفظ سبب الرفض لطلب مرفوض.
  static Future<void> updateRejectionReason({
    required String orderId,
    required String reason,
  }) async {
    final normalizedId = orderId.trim();
    final trimmedReason = reason.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('معرّف الطلب فارغ');
    }
    try {
      await _client.from(tableName).update({
        'rejection_reason': trimmedReason.isEmpty ? null : trimmedReason,
      }).eq('id', normalizedId);
      debugPrint(
        '[SupabaseOrderService] سبب الرفض $normalizedId → '
        '${trimmedReason.isEmpty ? "(فارغ)" : trimmedReason}',
      );
    } catch (e, stack) {
      debugPrint('[SupabaseOrderService] updateRejectionReason فشل: $e\n$stack');
      reportSupabaseError(e, stack, operation: 'updateRejectionReason');
      rethrow;
    }
  }

  static String _normalizeSlug(String slug) => slug.trim().toLowerCase();

  /// أقدم وقت إنشاء يُجلب في بث «طلباتي» (UTC ISO8601).
  static String _customerOrdersCreatedAfterIso() {
    return DateTime.now()
        .toUtc()
        .subtract(CustomerMyOrdersConfig.visibleOrdersWindow)
        .toIso8601String();
  }

  static Stream<List<Map<String, dynamic>>> _watchRecentOrderRows() {
    return _client
        .from(tableName)
        .stream(primaryKey: const ['id'])
        .gte('created_at', _customerOrdersCreatedAfterIso());
  }

  /// يحوّل صف Supabase إلى [DeliveryOrder] مع تخطّي الصفوف التالفة.
  static DeliveryOrder? _tryParseOrderRow(
    dynamic row, {
    String? rowIdForLog,
  }) {
    try {
      return DeliveryOrder.fromSupabase(Map<String, dynamic>.from(row));
    } catch (e, st) {
      final rowId = rowIdForLog ??
          (row is Map
              ? ModelParseValidation.recordIdFromMap(
                  Map<String, dynamic>.from(row),
                )
              : '(unknown)');
      debugPrint(
        '[SupabaseOrderService] تخطي صف طلب id=$rowId: $e\n$st',
      );
      return null;
    }
  }

  /// يحوّل صفوفاً إلى طلبات مع فلترة وترتيب اختياري.
  static List<DeliveryOrder> _mapRowsToOrders({
    required List<Map<String, dynamic>> rows,
    required bool Function(DeliveryOrder order) include,
    int Function(DeliveryOrder a, DeliveryOrder b)? compare,
    bool logParseErrors = false,
  }) {
    final orders = <DeliveryOrder>[];
    for (final row in rows) {
      final order = _tryParseOrderRow(
        row,
        rowIdForLog: logParseErrors ? row['id']?.toString() : null,
      );
      if (order == null || !include(order)) continue;
      orders.add(order);
    }
    if (compare != null) {
      orders.sort(compare);
    }
    debugPrint(
      '[SupabaseOrderService] _mapRowsToOrders: ${rows.length} صف خام → '
      '${orders.length} طلب',
    );
    return orders;
  }

  /// هل ينتمي الطلب إلى المطعم المحدد بالـ slug؟
  static bool orderMatchesSlug(DeliveryOrder order, String slug) {
    return _orderMatchesSlug(order, _normalizeSlug(slug));
  }

  static bool _orderMatchesSlug(DeliveryOrder order, String normalizedSlug) {
    final orderSlug = order.slug.trim().toLowerCase();
    final orderRestaurant = order.restaurantId.trim().toLowerCase();
    if (orderSlug.isEmpty && orderRestaurant.isEmpty) return true;
    return orderSlug == normalizedSlug || orderRestaurant == normalizedSlug;
  }

  static List<DeliveryOrder> _filterOrdersByPhoneAndSlug({
    required List<Map<String, dynamic>> rows,
    required String normalizedSlug,
    required String normalizedPhone,
  }) {
    return _mapRowsToOrders(
      rows: rows,
      include: (order) {
        final orderPhone = IraqiPhoneValidator.normalize(order.customerPhone);
        if (orderPhone != normalizedPhone) return false;
        if (!_orderMatchesSlug(order, normalizedSlug)) return false;
        return _includeCustomerPhoneOrder(order);
      },
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
      logParseErrors: true,
    );
  }

  static Stream<T> _resilientOrdersStream<T>({
    required Stream<List<Map<String, dynamic>>> Function() sourceFactory,
    required T Function(List<Map<String, dynamic>> rows) transform,
    required String streamTag,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return Stream<T>.multi((controller) {
      StreamSubscription<List<Map<String, dynamic>>>? subscription;
      bool closed = false;
      int reconnectAttempt = 0;
      DateTime lastDataAt = DateTime.now();
      late Future<void> Function() subscribe;

      void publishHealth(StreamHealth health) {
        onHealthChanged?.call(health);
      }

      Duration reconnectDelayForAttempt(int attempt) {
        final seconds = 1 << (attempt - 1).clamp(0, 4);
        final delay = Duration(seconds: seconds);
        if (delay > _streamReconnectMaxDelay) return _streamReconnectMaxDelay;
        if (delay < _streamReconnectBaseDelay) return _streamReconnectBaseDelay;
        return delay;
      }

      Future<void> scheduleReconnect(String reason, {Object? error}) async {
        reconnectAttempt += 1;
        final delay = reconnectDelayForAttempt(reconnectAttempt);
        publishHealth(StreamHealth.reconnecting);
        AppTelemetry.logEvent(
          'reconnect_attempt',
          fields: <String, Object?>{
            'stream': streamTag,
            'attempt': reconnectAttempt,
            'delay_ms': delay.inMilliseconds,
            'reason': reason,
            if (error != null) 'error': error.toString(),
          },
        );
        await Future<void>.delayed(delay);
        if (!closed) {
          unawaited(subscribe());
        }
      }

      subscribe = () async {
        if (closed) return;
        await subscription?.cancel();
        if (reconnectAttempt == 0) {
          publishHealth(StreamHealth.connecting);
        }
        subscription = sourceFactory().listen(
          (rows) {
            if (closed) return;
            reconnectAttempt = 0;
            lastDataAt = DateTime.now();
            publishHealth(StreamHealth.live);
            controller.add(transform(rows));
          },
          onError: (Object error, StackTrace stackTrace) async {
            debugPrint('[SupabaseOrderService] $streamTag error: $error');
            AppTelemetry.logError(
              'stream_disconnected',
              error: error,
              stackTrace: stackTrace,
              fields: <String, Object?>{
                'stream': streamTag,
                'error_kind': _errorKind(error),
              },
            );
            reportSupabaseError(
              error,
              stackTrace,
              operation: streamTag,
              showSnackBar: false,
            );
            if (closed) return;
            await subscription?.cancel();
            publishHealth(StreamHealth.error);
            await scheduleReconnect('on_error', error: error);
          },
          onDone: () async {
            if (closed) return;
            final idleFor = DateTime.now().difference(lastDataAt);
            if (idleFor > const Duration(seconds: 30)) {
              publishHealth(StreamHealth.stale);
            }
            await scheduleReconnect('on_done');
          },
          cancelOnError: false,
        );
      };

      unawaited(subscribe());

      controller.onCancel = () async {
        closed = true;
        publishHealth(StreamHealth.disposed);
        await subscription?.cancel();
      };
    });
  }

  static String _errorKind(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('jwt') || raw.contains('auth')) {
      return 'auth';
    }
    if (raw.contains('socket') ||
        raw.contains('network') ||
        raw.contains('timeout') ||
        raw.contains('connection')) {
      return 'network';
    }
    return 'unknown';
  }

  /// Legacy path kept as strict rollback target.
  static Stream<List<DeliveryOrder>> _legacyWatchPendingOrders({
    required String slug,
  }) {
    final normalized = _normalizeSlug(slug);
    return _client.from(tableName).stream(primaryKey: const ['id']).map(
      (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) =>
            order.status == DeliveryOrderStatus.pending &&
            _orderMatchesSlug(order, normalized),
        compare: (a, b) => a.createdAt.compareTo(b.createdAt),
      ),
    );
  }

  static Stream<List<DeliveryOrder>> _legacyWatchActiveOrders({
    required String slug,
  }) {
    final normalized = _normalizeSlug(slug);
    return _client.from(tableName).stream(primaryKey: const ['id']).map(
      (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) =>
            _activeOrderStatuses.contains(order.status) &&
            _orderMatchesSlug(order, normalized),
        compare: (a, b) => b.createdAt.compareTo(a.createdAt),
      ),
    );
  }

  static Stream<List<DeliveryOrder>> _legacyWatchKitchenDashboardOrders({
    required String slug,
  }) {
    final normalized = _normalizeSlug(slug);
    return _client.from(tableName).stream(primaryKey: const ['id']).map(
      (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) => _includeKitchenDashboardOrder(order, normalized),
        compare: (a, b) => b.createdAt.compareTo(a.createdAt),
      ),
    );
  }

  static Stream<List<DeliveryOrder>> _legacyWatchOrdersByPhone({
    required String slug,
    required String phoneNumber,
  }) {
    return _watchRecentOrderRows().map(
      (rows) => _filterOrdersByPhoneAndSlug(
        rows: rows,
        normalizedSlug: slug,
        normalizedPhone: phoneNumber,
      ),
    );
  }

  /// Legacy path kept as strict rollback target.
  static Stream<DeliveryOrder?> _legacyWatchOrderById({
    required String orderId,
  }) {
    final normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) {
      return const Stream<DeliveryOrder?>.empty();
    }
    return _client
        .from(tableName)
        .stream(primaryKey: const ['id']).eq('id', normalizedOrderId)
        .map((rows) {
      if (rows.isEmpty) return null;
      return _tryParseOrderRow(rows.first);
    });
  }
}

enum StreamHealth {
  connecting,
  live,
  reconnecting,
  stale,
  error,
  disposed,
}
