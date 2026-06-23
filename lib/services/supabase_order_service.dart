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
import '../core/utils/order_tenant_match.dart';
import '../core/utils/restaurant_slug_utils.dart';
import '../core/utils/business_day_order_aggregation.dart';
import '../core/utils/business_day_scope.dart';
import '../core/utils/delivery_coordinates.dart';
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

  static bool _matchesOrderTenant(
    DeliveryOrder order, {
    required String activeSlug,
    String? restaurantUuid,
  }) {
    return OrderTenantMatch.matches(
      order,
      activeSlug: activeSlug,
      activeRestaurantUuid: restaurantUuid,
    );
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
    final normalizedSlug = normalizeRestaurantSlug(slug);
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

    debugPrint('[MyOrdersSave] phone_number=${customerPhone.trim()} slug=$normalizedSlug');
    debugPrint('[SubmitOrder] scopedRestaurantId=$scopedRestaurantId');
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
    String? restaurantUuid,
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
              _matchesOrderTenant(
                order,
                activeSlug: normalized,
                restaurantUuid: restaurantUuid,
              ),
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
  ///
  /// Server-side: `.stream().eq('slug', normalized)` — pending stream فقط.
  /// Client-side: pending status + [OrderTenantMatch] كطبقة ثانية.
  static Stream<List<DeliveryOrder>> watchPendingOrders({
    required String slug,
    String? restaurantUuid,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    if (!StabilityPhase1Flags.enablePhase1RealtimeHardening) {
      return _legacyWatchPendingOrders(
        slug: slug,
        restaurantUuid: restaurantUuid,
      );
    }
    final normalized = _normalizeSlug(slug);

    // بث التغييرات للمطعم (slug filter) ثم فلترة pending محلياً — يزيل الطلب فور accepted.
    return _resilientOrdersStream(
      sourceFactory: () => _pendingOrdersRowsStream(normalized),
      transform: (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) =>
            order.status == DeliveryOrderStatus.pending &&
            _matchesOrderTenant(
              order,
              activeSlug: normalized,
              restaurantUuid: restaurantUuid,
            ),
        compare: (a, b) => a.createdAt.compareTo(b.createdAt),
        logParseErrors: true,
        fallbackSlug: normalized,
      ),
      streamTag:
          'watchPendingOrders(slug=$normalized,'
          'serverFilter=${pendingOrdersStreamServerFilterLabel(slug)})',
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

  /// بث طلبات الزبون — جلب أولي عبر [fetchOrdersByPhone] ثم تحديث عند Realtime.
  static Stream<List<DeliveryOrder>> watchOrdersByPhone({
    required String slug,
    required String phoneNumber,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    final normalizedSlug = _normalizeSlug(slug);
    final normalizedPhone = phoneNumber.trim();
    if (normalizedPhone.isEmpty) {
      return const Stream<List<DeliveryOrder>>.empty();
    }

    debugPrint(
      '[MyOrdersRead] watchOrdersByPhone phone_number=$normalizedPhone '
      'slug=$normalizedSlug',
    );

    return _watchOrdersByPhoneWithInitialFetch(
      normalizedSlug: normalizedSlug,
      normalizedPhone: normalizedPhone,
      onHealthChanged: onHealthChanged,
    );
  }

  /// جلب طلبات «طلباتي» — RPC [get_customer_orders_by_phone] (يتجاوز RLS).
  /// لا فلتر restaurant_id — slug + phone_number فقط.
  static Future<List<DeliveryOrder>> fetchOrdersByPhone({
    required String slug,
    required String phoneNumber,
  }) async {
    final normalizedSlug = _normalizeSlug(slug);
    final normalizedPhone = phoneNumber.trim();
    if (normalizedPhone.isEmpty) return [];

    final since = DateTime.now()
        .toUtc()
        .subtract(CustomerMyOrdersConfig.visibleOrdersWindow);

    // ignore: avoid_print
    print(
      '[MY_ORDERS_QUERY] slug=$normalizedSlug phone=$normalizedPhone '
      'since=${since.toIso8601String()}',
    );

    debugPrint(
      '[MyOrdersRead] RPC get_customer_orders_by_phone '
      'phone_number=$normalizedPhone slug=$normalizedSlug '
      'since=${since.toIso8601String()}',
    );

    try {
      return await NetworkTimeouts.run(() async {
        debugPrint(
          '[MyOrdersRead] query=RPC get_customer_orders_by_phone('
          'p_slug=$normalizedSlug, p_phone_number=$normalizedPhone)',
        );

        final raw = await _client.rpc(
          'get_customer_orders_by_phone',
          params: <String, dynamic>{
            'p_slug': normalizedSlug,
            'p_phone_number': normalizedPhone,
          },
        );

        final rows = List<Map<String, dynamic>>.from(
          (raw as List<dynamic>? ?? const <dynamic>[]).map(
            (dynamic entry) => mapMyOrdersCustomerRpcRow(
              Map<String, dynamic>.from(entry as Map),
            ),
          ),
        );

        // ignore: avoid_print
        print('[MY_ORDERS_RESULT] count=${rows.length} rows=$rows');

        if (rows.isEmpty) {
          _logMyOrdersRpcEmptyResult(
            normalizedSlug: normalizedSlug,
            normalizedPhone: normalizedPhone,
            since: since,
          );
        }

        debugPrint('[MyOrdersRead] rpcRowCount=${rows.length}');

        return filterOrdersByPhoneAndSlug(
          rows: rows,
          normalizedSlug: normalizedSlug,
          logFilterBreakdown: true,
        );
      });
    } catch (e, stack) {
      debugPrint('[SupabaseOrderService] fetchOrdersByPhone فشل: $e\n$stack');
      reportSupabaseError(
        e,
        stack,
        operation: 'fetchOrdersByPhone',
        showSnackBar: false,
      );
      rethrow;
    }
  }

  /// يحوّل صف RPC إلى شكل [DeliveryOrder.fromSupabase] المتوقع.
  @visibleForTesting
  static Map<String, dynamic> mapMyOrdersCustomerRpcRow(
    Map<String, dynamic> row,
  ) {
    return <String, dynamic>{
      'id': row['id'],
      'status': row['status'],
      'total_price': row['total'],
      'customer_name': row['customer_name'],
      'phone_number': row['phone_number'],
      'address': row['delivery_address'],
      'created_at': row['created_at'],
      'slug': row['slug'],
      'order_items': row['items'],
      'business_day_id': row['business_day_id'],
      if (row['notes'] != null &&
          row['notes'].toString().trim().isNotEmpty)
        'rejection_reason': row['notes'],
    };
  }

  static void _logMyOrdersRpcEmptyResult({
    required String normalizedSlug,
    required String normalizedPhone,
    required DateTime since,
  }) {
    // ignore: avoid_print
    print(
      '[MyOrdersFilter] rpcRows=0 — slug=$normalizedSlug '
      'phone=$normalizedPhone since=${since.toIso8601String()} '
      '(لا طلبات في 6 ساعات أو RPC غير منشور في Supabase)',
    );
  }

  /// سجلات تشخيص عند فتح «طلباتي» — مقارنة مسار الحفظ مع مسار الاستعلام.
  static Future<void> logMyOrdersOpenDiagnostics({
    required String slug,
    required String phoneNumber,
  }) async {
    final normalizedSlug = _normalizeSlug(slug);
    final phone = phoneNumber.trim();
    final window = CustomerMyOrdersConfig.visibleOrdersWindow;
    final since = DateTime.now().toUtc().subtract(window);
    final statuses = DeliveryOrderStatus.myOrdersTrackedStatuses.join(',');

    debugPrint('[MyOrdersDiag] read phone_number=$phone slug=$normalizedSlug');
    debugPrint('[MyOrdersDiag] since=${since.toIso8601String()} (${window.inHours}h)');
    debugPrint('[MyOrdersDiag] statuses=$statuses');

    try {
      final visible = await fetchOrdersByPhone(
        slug: normalizedSlug,
        phoneNumber: phone,
      );
      debugPrint('[MyOrdersDiag] visibleAfterFilter=${visible.length}');

      if (visible.isEmpty) {
        await _logLastTenOrdersForSlug(normalizedSlug);
        await _logMyOrdersEmptyReason(
          normalizedSlug: normalizedSlug,
          normalizedPhone: phone,
          windowStart: since,
        );
      }
    } catch (e, stack) {
      debugPrint('[MyOrdersDiag] diagnostics failed: $e\n$stack');
    }
  }

  /// آخر 10 طلبات لنفس [slug] — عند عدم ظهور أي طلب للزبون.
  static Future<void> _logLastTenOrdersForSlug(String normalizedSlug) async {
    try {
      final rows = List<Map<String, dynamic>>.from(
        await _client
            .from(tableName)
            .select('id, phone_number, status, created_at')
            .eq('slug', normalizedSlug)
            .order('created_at', ascending: false)
            .limit(10),
      );
      debugPrint(
        '[MyOrdersDiag] last10ForSlug=$normalizedSlug count=${rows.length}',
      );
      for (final row in rows) {
        debugPrint(
          '[MyOrdersDiag] last10 '
          'id=${row['id']} '
          'customer_phone=${row['phone_number']} '
          'status=${row['status']} '
          'created_at=${row['created_at']}',
        );
      }
    } catch (e, stack) {
      debugPrint('[MyOrdersDiag] last10ForSlug failed: $e\n$stack');
    }
  }

  static Future<void> _logMyOrdersEmptyReason({
    required String normalizedSlug,
    required String normalizedPhone,
    required DateTime windowStart,
  }) async {
    var query = _client
        .from(tableName)
        .select(
          'id, slug, status, created_at, phone_number, restaurant_id',
        );

    if (normalizedSlug.isNotEmpty) {
      query = query.eq('slug', normalizedSlug);
    }
    query = query.eq('phone_number', normalizedPhone);

    final rows = List<Map<String, dynamic>>.from(
      await query
          .order('created_at', ascending: false)
          .limit(CustomerMyOrdersConfig.fetchRowCap),
    );

    debugPrint(
      '[MyOrdersDiag] صفوف Supabase بنفس slug+phone: ${rows.length}',
    );

    if (rows.isEmpty) {
      debugPrint(
        '[MyOrdersDiag] سبب محتمل: لا صف في orders بهذا slug+phone — '
        'تحقق من [SubmitOrder] phone_number و normalizedSlug عند الإرسال، '
        'أو RLS يمنع SELECT للزبون (anon).',
      );
      return;
    }

    var index = 0;
    for (final row in rows.take(5)) {
      index++;
      final parsed = _tryParseOrderRow(
        row,
        rowIdForLog: row['id']?.toString(),
        fallbackSlug: normalizedSlug,
      );
      if (parsed == null) {
        debugPrint(
          '[MyOrdersDiag] صف#$index id=${row['id']} → تخطي (parse فشل)',
        );
        continue;
      }

      final visibleOk = _includeCustomerPhoneOrder(parsed);
      final inWindow = CustomerMyOrdersConfig.isOrderVisibleToCustomer(
        parsed.createdAt,
      );

      debugPrint(
        '[MyOrdersDiag] row#$index id=${parsed.id} '
        'status=${parsed.status} '
        'slug=${parsed.slug} restaurant_id=${parsed.restaurantId} '
        'phone=${parsed.customerPhone} created_at=${parsed.createdAt.toUtc()} '
        'visibility=$visibleOk inWindow=$inWindow '
        '→ ${visibleOk ? 'يُفترض ظهوره' : 'مستبعد: visibility(وقت/مرفوض)'}',
      );
    }
  }

  static Stream<List<DeliveryOrder>> _watchOrdersByPhoneWithInitialFetch({
    required String normalizedSlug,
    required String normalizedPhone,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return Stream<List<DeliveryOrder>>.multi((controller) {
      StreamSubscription<List<DeliveryOrder>>? streamSub;
      bool closed = false;
      bool inFlight = false;

      Future<void> emitFetch({required String reason}) async {
        if (closed || inFlight) return;
        inFlight = true;
        try {
          final orders = await fetchOrdersByPhone(
            slug: normalizedSlug,
            phoneNumber: normalizedPhone,
          );
          if (!closed) {
            onHealthChanged?.call(StreamHealth.live);
            controller.add(orders);
          }
          debugPrint(
            '[SupabaseOrderService] watchOrdersByPhone($reason) → '
            '${orders.length} طلب',
          );
        } catch (e, stack) {
          debugPrint(
            '[SupabaseOrderService] watchOrdersByPhone($reason) error: '
            '$e\n$stack',
          );
          if (!closed) {
            onHealthChanged?.call(StreamHealth.error);
            controller.addError(e, stack);
          }
        } finally {
          inFlight = false;
        }
      }

      onHealthChanged?.call(StreamHealth.connecting);
      unawaited(emitFetch(reason: 'initial'));

      final realtimeStream = StabilityPhase1Flags.enablePhase1RealtimeHardening
          ? _resilientOrdersStream<List<DeliveryOrder>>(
              sourceFactory: () => _ordersByPhoneRowsStream(normalizedSlug),
              transform: (_) => const <DeliveryOrder>[],
              streamTag:
                  'watchOrdersByPhone(slug=$normalizedSlug,'
                  'serverFilter='
                  '${ordersByPhoneStreamServerFilterLabel(normalizedSlug)})',
              onHealthChanged: onHealthChanged,
            )
          : _ordersByPhoneRowsStream(normalizedSlug).map(
              (_) => const <DeliveryOrder>[],
            );

      streamSub = realtimeStream.listen(
        (_) => unawaited(emitFetch(reason: 'realtime')),
        onError: (Object error, StackTrace stack) {
          debugPrint(
            '[SupabaseOrderService] watchOrdersByPhone realtime: '
            '$error\n$stack',
          );
          if (!closed) {
            controller.addError(error, stack);
          }
        },
      );

      controller.onCancel = () async {
        closed = true;
        await streamSub?.cancel();
        onHealthChanged?.call(StreamHealth.disposed);
      };
    });
  }

  /// بث كل الطلبات النشطة (غير المُسلّمة/الملغية) مع فلترة المطعم.
  ///
  /// Server-side: `.stream().eq('slug', normalized)` — active stream فقط.
  /// Client-side: active statuses + [OrderTenantMatch] كطبقة ثانية.
  static Stream<List<DeliveryOrder>> watchActiveOrders({
    required String slug,
    String? restaurantUuid,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    if (!StabilityPhase1Flags.enablePhase1RealtimeHardening) {
      return _legacyWatchActiveOrders(
        slug: slug,
        restaurantUuid: restaurantUuid,
      );
    }
    final normalized = _normalizeSlug(slug);

    return _resilientOrdersStream(
      sourceFactory: () => _activeOrdersRowsStream(normalized),
      transform: (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) =>
            _activeOrderStatuses.contains(order.status) &&
            _matchesOrderTenant(
              order,
              activeSlug: normalized,
              restaurantUuid: restaurantUuid,
            ),
        compare: (a, b) => b.createdAt.compareTo(a.createdAt),
        fallbackSlug: normalized,
      ),
      streamTag:
          'watchActiveOrders(slug=$normalized,'
          'serverFilter=${activeOrdersStreamServerFilterLabel(slug)})',
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

  /// طلبات «طلباتي»: نافذة الوقت فقط — لا فلتر status (accepted/preparing/… تظهر).
  /// المرفوض/الملغي: نافذة الوقت أو يوم العمل المفتوح.
  static bool _includeCustomerPhoneOrder(DeliveryOrder order) {
    final status = order.status.trim().toLowerCase();
    if (status == DeliveryOrderStatus.rejected ||
        status == DeliveryOrderStatus.cancelled) {
      if (CustomerMyOrdersConfig.isOrderVisibleToCustomer(order.createdAt)) {
        return true;
      }
      return RejectedOrdersConfig.isRejectedVisibleForCurrentBusinessDay(order);
    }
    return CustomerMyOrdersConfig.isOrderVisibleToCustomer(order.createdAt);
  }

  /// لوحة الإدارة: معلّق كما هو؛ مرفوض من اليوم المحلي فقط.
  static bool _includeKitchenDashboardOrder(
    DeliveryOrder order,
    String normalizedSlug, {
    String? restaurantUuid,
  }) {
    if (!_matchesOrderTenant(
      order,
      activeSlug: normalizedSlug,
      restaurantUuid: restaurantUuid,
    )) {
      return false;
    }
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
  ///
  /// Server-side: `.stream().eq('slug', normalized)` — kitchen dashboard stream فقط.
  /// Client-side: kitchen include rules + [OrderTenantMatch] كطبقة ثانية.
  static Stream<List<DeliveryOrder>> watchKitchenDashboardOrders({
    required String slug,
    String? restaurantUuid,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    if (!StabilityPhase1Flags.enablePhase1RealtimeHardening) {
      return _legacyWatchKitchenDashboardOrders(
        slug: slug,
        restaurantUuid: restaurantUuid,
      );
    }
    final normalized = _normalizeSlug(slug);

    return _resilientOrdersStream(
      sourceFactory: () => _kitchenDashboardOrdersRowsStream(normalized),
      transform: (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) => _includeKitchenDashboardOrder(
          order,
          normalized,
          restaurantUuid: restaurantUuid,
        ),
        compare: (a, b) => b.createdAt.compareTo(a.createdAt),
        fallbackSlug: normalized,
      ),
      streamTag:
          'watchKitchenDashboardOrders(slug=$normalized,'
          'serverFilter=${kitchenDashboardOrdersStreamServerFilterLabel(slug)})',
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

  static String _normalizeSlug(String slug) => normalizeRestaurantSlug(slug);

  /// Realtime rows stream لـ [watchPendingOrders] — `slug=eq.<slug>` إن أمكن.
  static Stream<List<Map<String, dynamic>>> _pendingOrdersRowsStream(
    String normalizedSlug,
  ) {
    final builder = _client.from(tableName).stream(primaryKey: const ['id']);
    if (normalizedSlug.isEmpty) {
      debugPrint(
        '[SupabaseOrderService] watchPendingOrders: empty slug — '
        'server filter skipped; client OrderTenantMatch guard active',
      );
      return builder;
    }
    return builder.eq('slug', normalizedSlug);
  }

  /// وصف فلتر Realtime server-side لـ pending — للاختبار والسجلات.
  @visibleForTesting
  static String pendingOrdersStreamServerFilterLabel(String slug) {
    final normalized = _normalizeSlug(slug);
    if (normalized.isEmpty) return 'none';
    return 'slug=eq.$normalized';
  }

  /// Realtime rows stream لـ [watchActiveOrders] — `slug=eq.<slug>` إن أمكن.
  static Stream<List<Map<String, dynamic>>> _activeOrdersRowsStream(
    String normalizedSlug,
  ) {
    final builder = _client.from(tableName).stream(primaryKey: const ['id']);
    if (normalizedSlug.isEmpty) {
      debugPrint(
        '[SupabaseOrderService] watchActiveOrders: empty slug — '
        'server filter skipped; client OrderTenantMatch guard active',
      );
      return builder;
    }
    return builder.eq('slug', normalizedSlug);
  }

  /// وصف فلتر Realtime server-side لـ active — للاختبار والسجلات.
  @visibleForTesting
  static String activeOrdersStreamServerFilterLabel(String slug) {
    final normalized = _normalizeSlug(slug);
    if (normalized.isEmpty) return 'none';
    return 'slug=eq.$normalized';
  }

  /// Realtime rows stream لـ [watchKitchenDashboardOrders] — `slug=eq.<slug>` إن أمكن.
  static Stream<List<Map<String, dynamic>>> _kitchenDashboardOrdersRowsStream(
    String normalizedSlug,
  ) {
    final builder = _client.from(tableName).stream(primaryKey: const ['id']);
    if (normalizedSlug.isEmpty) {
      debugPrint(
        '[SupabaseOrderService] watchKitchenDashboardOrders: empty slug — '
        'server filter skipped; client OrderTenantMatch guard active',
      );
      return builder;
    }
    return builder.eq('slug', normalizedSlug);
  }

  /// وصف فلتر Realtime server-side لـ kitchen dashboard — للاختبار والسجلات.
  @visibleForTesting
  static String kitchenDashboardOrdersStreamServerFilterLabel(String slug) {
    final normalized = _normalizeSlug(slug);
    if (normalized.isEmpty) return 'none';
    return 'slug=eq.$normalized';
  }

  /// أقدم وقت إنشاء يُجلب في بث «طلباتي» (UTC ISO8601).
  static String _customerOrdersCreatedAfterIso() {
    return DateTime.now()
        .toUtc()
        .subtract(CustomerMyOrdersConfig.visibleOrdersWindow)
        .toIso8601String();
  }

  /// Realtime rows stream لـ [watchOrdersByPhone].
  ///
  /// Supabase `.stream()` يقبل فلتر server-side واحد فقط؛ نُفضّل `slug=eq`.
  /// نافذة 6 ساعات تبقى client-side عبر [_includeCustomerPhoneOrder].
  static Stream<List<Map<String, dynamic>>> _ordersByPhoneRowsStream(
    String normalizedSlug,
  ) {
    final base = _client.from(tableName).stream(primaryKey: const ['id']);
    if (normalizedSlug.isEmpty) {
      debugPrint(
        '[SupabaseOrderService] watchOrdersByPhone: empty slug — '
        'server filter skipped; client OrderTenantMatch guard active',
      );
      return base.gte('created_at', _customerOrdersCreatedAfterIso());
    }
    return base.eq('slug', normalizedSlug);
  }

  /// وصف فلتر Realtime server-side لـ phone orders — للاختبار والسجلات.
  @visibleForTesting
  static String ordersByPhoneStreamServerFilterLabel(String slug) {
    final normalized = _normalizeSlug(slug);
    if (normalized.isEmpty) return 'none';
    return 'slug=eq.$normalized';
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

  /// هل ينتمي الطلب إلى المطعم النشط (slug و/أو restaurant UUID)?
  static bool orderMatchesSlug(
    DeliveryOrder order,
    String slug, {
    String? restaurantUuid,
  }) {
    return OrderTenantMatch.matches(
      order,
      activeSlug: slug,
      activeRestaurantUuid: restaurantUuid,
    );
  }

  /// بعد فلترة Supabase (slug + phone_number): parse + نافذة الوقت فقط.
  /// لا فلتر restaurant_id ولا إعادة فلترة phone client-side.
  @visibleForTesting
  static List<DeliveryOrder> filterOrdersByPhoneAndSlug({
    required List<Map<String, dynamic>> rows,
    required String normalizedSlug,
    bool logFilterBreakdown = false,
  }) {
    var visibilityExcluded = 0;
    var parseSkipped = 0;

    final orders = <DeliveryOrder>[];
    for (final row in rows) {
      final order = _tryParseOrderRow(
        row,
        rowIdForLog: logFilterBreakdown ? row['id']?.toString() : null,
        fallbackSlug: normalizedSlug,
      );
      if (order == null) {
        parseSkipped++;
        continue;
      }

      if (!_includeCustomerPhoneOrder(order)) {
        visibilityExcluded++;
        if (logFilterBreakdown) {
          debugPrint(
            '[MyOrdersFilter] id=${order.id} excluded: visibility '
            'status=${order.status} created_at=${order.createdAt.toUtc()}',
          );
        }
        continue;
      }

      orders.add(order);
    }

    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (logFilterBreakdown) {
      debugPrint(
        '[MyOrdersFilter] supabaseRows=${rows.length} → visible=${orders.length} '
        '(visibilityExcluded=$visibilityExcluded parseSkipped=$parseSkipped)',
      );
    }

    return orders;
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

  /// Legacy path kept as strict rollback target — نفس فلتر slug server-side.
  static Stream<List<DeliveryOrder>> _legacyWatchPendingOrders({
    required String slug,
    String? restaurantUuid,
  }) {
    final normalized = _normalizeSlug(slug);
    return _pendingOrdersRowsStream(normalized).map(
      (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) =>
            order.status == DeliveryOrderStatus.pending &&
            _matchesOrderTenant(
              order,
              activeSlug: normalized,
              restaurantUuid: restaurantUuid,
            ),
        compare: (a, b) => a.createdAt.compareTo(b.createdAt),
        fallbackSlug: normalized,
      ),
    );
  }

  static Stream<List<DeliveryOrder>> _legacyWatchActiveOrders({
    required String slug,
    String? restaurantUuid,
  }) {
    final normalized = _normalizeSlug(slug);
    return _activeOrdersRowsStream(normalized).map(
      (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) =>
            _activeOrderStatuses.contains(order.status) &&
            _matchesOrderTenant(
              order,
              activeSlug: normalized,
              restaurantUuid: restaurantUuid,
            ),
        compare: (a, b) => b.createdAt.compareTo(a.createdAt),
        fallbackSlug: normalized,
      ),
    );
  }

  static Stream<List<DeliveryOrder>> _legacyWatchKitchenDashboardOrders({
    required String slug,
    String? restaurantUuid,
  }) {
    final normalized = _normalizeSlug(slug);
    return _kitchenDashboardOrdersRowsStream(normalized).map(
      (rows) => _mapRowsToOrders(
        rows: rows,
        include: (order) => _includeKitchenDashboardOrder(
          order,
          normalized,
          restaurantUuid: restaurantUuid,
        ),
        compare: (a, b) => b.createdAt.compareTo(a.createdAt),
        fallbackSlug: normalized,
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
