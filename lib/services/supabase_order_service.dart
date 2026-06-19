import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/customer_my_orders_config.dart';
import '../core/config/location_feature_flags.dart';
import '../core/config/rejected_orders_config.dart';
import '../core/config/restaurant_ids.dart';
import '../core/config/stability_phase1_flags.dart';
import '../core/network/network_timeout.dart';
import '../core/observability/app_telemetry.dart';
import '../core/utils/business_day_order_aggregation.dart';
import '../core/utils/business_day_scope.dart';
import '../core/utils/delivery_coordinates.dart';
import '../core/utils/iraqi_phone_validator.dart';
import '../core/utils/model_parse_validation.dart';
import '../models/business_day_model.dart';
import '../models/business_day_order_stats.dart';
import '../models/delivery_order_model.dart';
import '../models/delivery_order_status.dart';
import '../models/end_of_day_report_model.dart';
import '../models/order_model.dart';
import 'supabase_app_settings_service.dart';
import 'supabase_business_day_service.dart';
import 'supabase_error_reporter.dart';

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

  static Map<String, dynamic> _parseSubmitOrderRpcRow(dynamic raw) {
    if (raw is List) {
      if (raw.isEmpty) {
        throw StateError('submit_customer_order returned empty result');
      }
      return Map<String, dynamic>.from(raw.first as Map);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw StateError('submit_customer_order returned unexpected type: $raw');
  }

  static bool _isRpcNoOpenBusinessDay(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains(noOpenBusinessDayCode);
  }

  static ValueChanged<StreamHealth>? _streamHealthCallback(
    ValueChanged<StreamHealth>? onHealthChanged,
  ) {
    return StabilityPhase1Flags.enablePhase1HealthSignals
        ? onHealthChanged
        : null;
  }

  static const String maintenanceBlockedCode = 'maintenance_mode_active';
  static const String noOpenBusinessDayCode = 'no_open_business_day';
  static const String businessDayIdNotPersistedCode = 'business_day_id_not_persisted';
  static const String closedRestaurantMessage =
      'المطعم مغلق حالياً، يرجى المحاولة لاحقاً.';

  /// يحفظ طلباً جديداً عبر RPC — قاعدة البيانات تربط `business_day_id`.
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
    final settings = await SupabaseAppSettingsService.fetch();
    if (settings.maintenanceMode) {
      throw StateError(maintenanceBlockedCode);
    }

    final resolvedRestaurantUuid =
        _resolveRestaurantUuid(restaurantId) ??
        _resolveRestaurantUuid(RestaurantIds.snackBurgerUuid ?? '');
    final normalizedSlug = slug.trim().toLowerCase();
    final scopedRestaurantId = resolvedRestaurantUuid ??
        (restaurantId.trim().isNotEmpty
            ? restaurantId.trim().toLowerCase()
            : normalizedSlug);

    final correlationId = AppTelemetry.newCorrelationId(scope: 'order_submit');
    final orderItems = items.map((item) => item.toMap()).toList();
    final locationCoordinates = _resolveLocationCoordinates(
      latitude: latitude,
      longitude: longitude,
    );

    debugPrint('[SubmitOrder] scopedRestaurantId=$scopedRestaurantId');
    debugPrint('[SubmitOrder] normalizedSlug=$normalizedSlug');
    debugPrint(
      '[SupabaseOrderService] submitOrder RPC — '
      'restaurantUuid=${resolvedRestaurantUuid ?? 'null'}, '
      'slug=$normalizedSlug, '
      '${orderItems.length} عنصر، total=$totalPrice',
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
      final rpcParams = <String, dynamic>{
        'p_restaurant_id': scopedRestaurantId,
        'p_slug': normalizedSlug,
        'p_customer_name': customerName.trim(),
        'p_phone_number': customerPhone.trim(),
        'p_address': address.trim(),
        'p_total_price': totalPrice,
        'p_order_items': orderItems,
      };
      if (locationCoordinates != null) {
        rpcParams['p_location_coordinates'] = locationCoordinates;
      }

      final rawRow = await NetworkTimeouts.run(
        () => _client.rpc<dynamic>(
          'submit_customer_order',
          params: rpcParams,
        ),
        timeout: NetworkTimeouts.orderSubmit,
        timeoutMessage:
            'تعذر إرسال الطلب، تحقق من الإنترنت وحاول مرة أخرى',
      );

      final row = _parseSubmitOrderRpcRow(rawRow);
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) {
        throw StateError('لم يُرجَع id بعد RPC submit_customer_order.');
      }

      final insertedBusinessDayId =
          row['business_day_id']?.toString().trim() ?? '';
      final dayOrderNumber = row['business_day_order_number'];
      debugPrint(
        '[SubmitOrder] rpc id=$id business_day_id=$insertedBusinessDayId '
        'business_day_order_number=$dayOrderNumber '
        'status=${row['status']} slug=${row['slug']} '
        'restaurant_id=${row['restaurant_id']}',
      );
      if (insertedBusinessDayId.isEmpty) {
        throw StateError(
          '$businessDayIdNotPersistedCode: RPC submit_customer_order returned '
          'null business_day_id',
        );
      }

      debugPrint('[SupabaseOrderService] تم حفظ الطلب عبر RPC: $id');
      AppTelemetry.logEvent(
        'order_submit_succeeded',
        correlationId: correlationId,
        fields: <String, Object?>{
          'order_id': id,
          'business_day_id': insertedBusinessDayId,
          'business_day_order_number': dayOrderNumber,
        },
      );
      return id;
    } on PostgrestException catch (e, stack) {
      if (_isRpcNoOpenBusinessDay(e)) {
        debugPrint('[SupabaseOrderService] submitOrder — no open business day');
        throw StateError(noOpenBusinessDayCode);
      }
      debugPrint('[SupabaseOrderService] submitOrder RPC فشل: $e\n$stack');
      AppTelemetry.logError(
        'order_submit_failed',
        correlationId: correlationId,
        error: e,
        stackTrace: stack,
        fields: <String, Object?>{'slug': normalizedSlug},
      );
      reportSupabaseError(e, stack, operation: 'submitOrder');
      rethrow;
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

  /// جلب الطلبات المعلقة التي أُنشئت بعد وقت محدد — للـ polling الاحتياطي.
  static Future<List<DeliveryOrder>> fetchPendingOrdersCreatedAfter({
    required String slug,
    required DateTime after,
  }) async {
    final normalized = _normalizeSlug(slug);
    try {
      return await NetworkTimeouts.run(() async {
        final rows = await _client
            .from(tableName)
            .select()
            .eq('status', DeliveryOrderStatus.pending)
            .gte('created_at', after.toUtc().toIso8601String())
            .order('created_at', ascending: false);

        return _mapRowsToOrders(
          rows: List<Map<String, dynamic>>.from(rows),
          include: (order) =>
              order.status == DeliveryOrderStatus.pending &&
              _orderMatchesSlug(order, normalized),
          compare: (a, b) => b.createdAt.compareTo(a.createdAt),
          logParseErrors: false,
          fallbackSlug: normalized,
        );
      });
    } catch (e, stack) {
      debugPrint(
        '[SupabaseOrderService] fetchPendingOrdersCreatedAfter فشل: $e\n$stack',
      );
      reportSupabaseError(
        e,
        stack,
        operation: 'fetchPendingOrdersCreatedAfter',
        showSnackBar: false,
      );
      rethrow;
    }
  }

  /// بث الطلبات المعلقة ليوم عمل محدد — للوحة الإدارة والتنبيه.
  static Stream<List<DeliveryOrder>> watchPendingOrdersForBusinessDay({
    required String businessDayId,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    if (!StabilityPhase1Flags.enablePhase1RealtimeHardening) {
      return _legacyWatchPendingOrdersForBusinessDay(businessDayId: businessDayId);
    }
    final normalizedDayId = businessDayId.trim();

    return _resilientOrdersStream(
      sourceFactory: () =>
          _client.from(tableName).stream(primaryKey: const ['id']),
      transform: (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) =>
            order.status == DeliveryOrderStatus.pending &&
            order.businessDayId?.trim() == normalizedDayId,
        compare: (a, b) => a.createdAt.compareTo(b.createdAt),
        logParseErrors: true,
      ),
      streamTag: 'watchPendingOrdersForBusinessDay(day=$normalizedDayId)',
      onHealthChanged: _streamHealthCallback(onHealthChanged),
    );
  }

  /// جلب الطلبات المعلقة ليوم عمل بعد وقت محدد — polling احتياطي.
  static Future<List<DeliveryOrder>> fetchPendingOrdersForBusinessDayCreatedAfter({
    required String businessDayId,
    required DateTime after,
  }) async {
    final normalizedDayId = businessDayId.trim();
    try {
      return await NetworkTimeouts.run(() async {
        final rows = await _client
            .from(tableName)
            .select()
            .eq('business_day_id', normalizedDayId)
            .eq('status', DeliveryOrderStatus.pending)
            .gte('created_at', after.toUtc().toIso8601String())
            .order('created_at', ascending: false);

        return _mapRowsToOrders(
          rows: List<Map<String, dynamic>>.from(rows),
          include: (order) =>
              order.status == DeliveryOrderStatus.pending &&
              order.businessDayId?.trim() == normalizedDayId,
          compare: (a, b) => b.createdAt.compareTo(a.createdAt),
          logParseErrors: false,
        );
      });
    } catch (e, stack) {
      debugPrint(
        '[SupabaseOrderService] fetchPendingOrdersForBusinessDayCreatedAfter '
        'فشل: $e\n$stack',
      );
      reportSupabaseError(
        e,
        stack,
        operation: 'fetchPendingOrdersForBusinessDayCreatedAfter',
        showSnackBar: false,
      );
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
        fallbackSlug: normalized,
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
        fallbackSlug: normalized,
      ),
      streamTag: 'watchActiveOrders(slug=$normalized)',
      onHealthChanged: _streamHealthCallback(onHealthChanged),
    );
  }

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
      return RejectedOrdersConfig.isRejectedVisibleForCurrentBusinessDay(order);
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
      return RejectedOrdersConfig.isRejectedVisibleForCurrentBusinessDay(order);
    }
    return false;
  }

  /// لوحة الإدارة: معلّق أو مرفوض ضمن نفس يوم العمل.
  static bool _includeKitchenDashboardOrderForBusinessDay(
    DeliveryOrder order,
    String businessDayId,
  ) {
    if (order.businessDayId?.trim() != businessDayId.trim()) return false;
    if (order.isPending) return true;
    if (order.isRejected) return true;
    return false;
  }

  /// بث طلبات المطبخ ليوم عمل محدد: معلّقة + مرفوضة.
  static Stream<List<DeliveryOrder>> watchKitchenDashboardOrdersForBusinessDay({
    required String businessDayId,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    if (!StabilityPhase1Flags.enablePhase1RealtimeHardening) {
      return _legacyWatchKitchenDashboardOrdersForBusinessDay(
        businessDayId: businessDayId,
      );
    }
    final normalizedDayId = businessDayId.trim();

    return _resilientOrdersStream(
      sourceFactory: () =>
          _client.from(tableName).stream(primaryKey: const ['id']),
      transform: (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) =>
            _includeKitchenDashboardOrderForBusinessDay(order, normalizedDayId),
        compare: (a, b) => b.createdAt.compareTo(a.createdAt),
      ),
      streamTag:
          'watchKitchenDashboardOrdersForBusinessDay(day=$normalizedDayId)',
      onHealthChanged: _streamHealthCallback(onHealthChanged),
    );
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
        fallbackSlug: normalized,
      ),
      streamTag: 'watchKitchenDashboardOrders(slug=$normalized)',
      onHealthChanged: _streamHealthCallback(onHealthChanged),
    );
  }

  static Future<List<DeliveryOrder>> _fetchAllOrdersForBusinessDay(
    String businessDayId,
  ) async {
    final rows = await _client
        .from(tableName)
        .select()
        .eq('business_day_id', businessDayId)
        .order('created_at', ascending: false);

    return _mapRowsToOrders(
      rows: List<Map<String, dynamic>>.from(rows),
      include: (_) => true,
      logParseErrors: true,
    );
  }

  static List<ClosingProductLine> _buildClosingProductLines(
    List<DeliveryOrder> closingOrders,
  ) {
    final lineAggregates = <String, ClosingProductLine>{};

    for (final order in closingOrders) {
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

    return lineAggregates.values.toList()
      ..sort((a, b) => a.productName.compareTo(b.productName));
  }

  /// إحصائيات موحّدة ليوم عمل — تعتمد على `business_day_id` فقط.
  static Future<BusinessDayOrderStats> fetchBusinessDayOrderStats({
    required String businessDayId,
    BusinessDayModel? businessDay,
  }) async {
    final day = businessDay ??
        await SupabaseBusinessDayService.fetchById(businessDayId);
    if (day == null) {
      throw StateError('business_day_not_found');
    }

    try {
      return await NetworkTimeouts.run(() async {
        final allOrders = await _fetchAllOrdersForBusinessDay(businessDayId);
        final stats = aggregateBusinessDayOrders(allOrders);

        debugPrint(
          '[SupabaseOrderService] إحصائيات يوم العمل ${day.id} — '
          'الكل=${stats.allOrdersCount} معلّق=${stats.pendingOrdersCount} '
          'محتسب=${stats.closingCountableOrders} '
          'مبيعات=${stats.closingCountableSales} د.ع',
        );

        return stats;
      });
    } catch (e, stack) {
      debugPrint(
        '[SupabaseOrderService] fetchBusinessDayOrderStats فشل: $e\n$stack',
      );
      reportSupabaseError(e, stack, operation: 'fetchBusinessDayOrderStats');
      rethrow;
    }
  }

  /// تقرير إغلاق يوم عمل محدد — يعتمد على `business_day_id` فقط.
  static Future<EndOfDayReport> fetchClosingReport({
    required String businessDayId,
    String? slug,
    BusinessDayModel? businessDay,
  }) async {
    final day = businessDay ??
        await SupabaseBusinessDayService.fetchById(businessDayId);
    if (day == null) {
      throw StateError('business_day_not_found');
    }

    try {
      return await NetworkTimeouts.run(() async {
        final allOrders = await _fetchAllOrdersForBusinessDay(businessDayId);
        final stats = aggregateBusinessDayOrders(allOrders);
        final closingOrders = stats.closingOrders;
        final productLines = _buildClosingProductLines(closingOrders);

        debugPrint(
          '[SupabaseOrderService] تقرير يوم العمل ${day.id} — '
          '${stats.closingCountableOrders} طلب محتسب، '
          '${stats.closingCountableSales} د.ع، '
          '${productLines.length} منتج',
        );

        return EndOfDayReport(
          reportDate: BusinessDayScope.reportDateFor(day),
          orderCount: stats.closingCountableOrders,
          totalSales: stats.closingCountableSales,
          productLines: productLines,
          orders: closingOrders,
        );
      });
    } catch (e, stack) {
      debugPrint('[SupabaseOrderService] fetchClosingReport فشل: $e\n$stack');
      reportSupabaseError(e, stack, operation: 'fetchClosingReport');
      rethrow;
    }
  }

  /// بث كل الطلبات المرتبطة بيوم عمل — للتحديث الفوري في لوحة التحكم.
  static Stream<List<DeliveryOrder>> watchOrdersForBusinessDay({
    required String businessDayId,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    if (!StabilityPhase1Flags.enablePhase1RealtimeHardening) {
      return _legacyWatchOrdersForBusinessDay(businessDayId: businessDayId);
    }
    final normalizedDayId = businessDayId.trim();

    return _resilientOrdersStream(
      sourceFactory: () =>
          _client.from(tableName).stream(primaryKey: const ['id']),
      transform: (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) => order.businessDayId?.trim() == normalizedDayId,
        compare: (a, b) => b.createdAt.compareTo(a.createdAt),
        logParseErrors: true,
      ),
      streamTag: 'watchOrdersForBusinessDay(day=$normalizedDayId)',
      onHealthChanged: _streamHealthCallback(onHealthChanged),
    );
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
    String? fallbackSlug,
    String? fallbackRestaurantId,
  }) {
    try {
      return DeliveryOrder.fromSupabase(
        Map<String, dynamic>.from(row),
        fallbackSlug: fallbackSlug ?? RestaurantIds.snackBurgerSlug,
        fallbackRestaurantId: fallbackRestaurantId,
      );
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
    String? fallbackSlug,
    String? fallbackRestaurantId,
  }) {
    final resolvedFallbackSlug =
        fallbackSlug?.trim().isNotEmpty == true
            ? fallbackSlug!.trim().toLowerCase()
            : RestaurantIds.snackBurgerSlug;
    final orders = <DeliveryOrder>[];
    for (final row in rows) {
      final order = _tryParseOrderRow(
        row,
        rowIdForLog: logParseErrors ? row['id']?.toString() : null,
        fallbackSlug: resolvedFallbackSlug,
        fallbackRestaurantId: fallbackRestaurantId,
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
      fallbackSlug: normalizedSlug,
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
  static Stream<List<DeliveryOrder>> _legacyWatchPendingOrdersForBusinessDay({
    required String businessDayId,
  }) {
    final normalizedDayId = businessDayId.trim();
    return _client.from(tableName).stream(primaryKey: const ['id']).map(
      (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) =>
            order.status == DeliveryOrderStatus.pending &&
            order.businessDayId?.trim() == normalizedDayId,
        compare: (a, b) => a.createdAt.compareTo(b.createdAt),
      ),
    );
  }

  static Stream<List<DeliveryOrder>> _legacyWatchKitchenDashboardOrdersForBusinessDay({
    required String businessDayId,
  }) {
    final normalizedDayId = businessDayId.trim();
    return _client.from(tableName).stream(primaryKey: const ['id']).map(
      (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) =>
            _includeKitchenDashboardOrderForBusinessDay(order, normalizedDayId),
        compare: (a, b) => b.createdAt.compareTo(a.createdAt),
      ),
    );
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
        fallbackSlug: normalized,
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
        fallbackSlug: normalized,
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
        fallbackSlug: normalized,
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
  static Stream<List<DeliveryOrder>> _legacyWatchOrdersForBusinessDay({
    required String businessDayId,
  }) {
    final normalizedDayId = businessDayId.trim();
    return _client.from(tableName).stream(primaryKey: const ['id']).map(
      (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) => order.businessDayId?.trim() == normalizedDayId,
        compare: (a, b) => b.createdAt.compareTo(a.createdAt),
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
