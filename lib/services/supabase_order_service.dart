import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/customer_my_orders_config.dart';
import '../core/config/location_feature_flags.dart';
import '../core/observability/app_telemetry.dart';
import '../core/utils/iraqi_phone_validator.dart';
import '../core/config/restaurant_ids.dart';
import '../core/config/stability_phase1_flags.dart';
import '../core/utils/delivery_coordinates.dart';
import '../models/delivery_order_model.dart';
import '../models/delivery_order_status.dart';
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
    String? locationCoordinates;
    if (LocationFeatureFlags.enabled) {
      if (latitude == null || longitude == null) {
        throw ArgumentError(
          'إحداثيات التوصيل مطلوبة — حدّد الموقع بدقة قبل الإرسال.',
        );
      }
      locationCoordinates = DeliveryCoordinates.format(latitude, longitude);
    }
    final resolvedRestaurantUuid =
        _resolveRestaurantUuid(restaurantId) ??
        _resolveRestaurantUuid(RestaurantIds.snackBurgerUuid ?? '');
    final normalizedSlug = slug.trim();

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
    } else if (restaurantId.trim().isNotEmpty) {
      debugPrint(
        '[SupabaseOrderService] تخطي restaurant_id — القيمة ليست UUID: '
        '${restaurantId.trim()}',
      );
    }

    if (normalizedSlug.isNotEmpty) {
      payload['slug'] = normalizedSlug;
    }

    if (locationCoordinates != null) {
      payload['location_coordinates'] = locationCoordinates;
    }

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
    final normalized = slug.trim().toLowerCase();

    // بث كل التغييرات ثم فلترة pending محلياً — يزيل الطلب فور تحديث الحالة إلى accepted.
    return _resilientOrdersStream(
      sourceFactory: () =>
          _client.from(tableName).stream(primaryKey: const ['id']),
      transform: (rows) {
        final orders = <DeliveryOrder>[];
        for (final row in rows) {
          try {
            final order = DeliveryOrder.fromSupabase(
              Map<String, dynamic>.from(row),
            );
            if (order.status != DeliveryOrderStatus.pending) {
              continue;
            }
            final orderSlug = order.slug.trim().toLowerCase();
            final orderRestaurant = order.restaurantId.trim().toLowerCase();
            if (orderSlug.isEmpty && orderRestaurant.isEmpty) {
              orders.add(order);
              continue;
            }
            if (orderSlug == normalized || orderRestaurant == normalized) {
              orders.add(order);
            }
          } catch (e, st) {
            debugPrint(
              '[SupabaseOrderService] تخطي صف طلب ${row['id']}: $e\n$st',
            );
          }
        }
        orders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return orders;
      },
      streamTag: 'watchPendingOrders(slug=$normalized)',
      onHealthChanged: StabilityPhase1Flags.enablePhase1HealthSignals
          ? onHealthChanged
          : null,
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
        try {
          return DeliveryOrder.fromSupabase(Map<String, dynamic>.from(rows.first));
        } catch (e, st) {
          debugPrint(
            '[SupabaseOrderService] فشل تحويل صف الطلب $normalizedOrderId: $e\n$st',
          );
          return null;
        }
      },
      streamTag: 'watchOrderById(orderId=$normalizedOrderId)',
      onHealthChanged: StabilityPhase1Flags.enablePhase1HealthSignals
          ? onHealthChanged
          : null,
    );
  }

  /// بث طلبات الزبون حسب رقم الهاتف والمطعم (جدول `orders`).
  static Stream<List<DeliveryOrder>> watchOrdersByPhone({
    required String slug,
    required String phoneNumber,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    final normalizedSlug = slug.trim().toLowerCase();
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
      sourceFactory: () =>
          _client.from(tableName).stream(primaryKey: const ['id']),
      transform: (rows) => _filterOrdersByPhoneAndSlug(
        rows: rows,
        normalizedSlug: normalizedSlug,
        normalizedPhone: normalizedPhone,
      ),
      streamTag: 'watchOrdersByPhone(slug=$normalizedSlug)',
      onHealthChanged: StabilityPhase1Flags.enablePhase1HealthSignals
          ? onHealthChanged
          : null,
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
    final normalized = slug.trim().toLowerCase();

    return _resilientOrdersStream(
      sourceFactory: () =>
          _client.from(tableName).stream(primaryKey: const ['id']),
      transform: (rows) {
        final orders = <DeliveryOrder>[];
        for (final row in rows) {
          try {
            final order = DeliveryOrder.fromSupabase(
              Map<String, dynamic>.from(row),
            );
            if (!_activeOrderStatuses.contains(order.status)) continue;
            final orderSlug = order.slug.trim().toLowerCase();
            final orderRestaurant = order.restaurantId.trim().toLowerCase();
            if (orderSlug.isEmpty && orderRestaurant.isEmpty) {
              orders.add(order);
              continue;
            }
            if (orderSlug == normalized || orderRestaurant == normalized) {
              orders.add(order);
            }
          } catch (_) {}
        }
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return orders;
      },
      streamTag: 'watchActiveOrders(slug=$normalized)',
      onHealthChanged: StabilityPhase1Flags.enablePhase1HealthSignals
          ? onHealthChanged
          : null,
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

  static const Set<String> _kitchenDashboardStatuses = {
    DeliveryOrderStatus.pending,
    DeliveryOrderStatus.rejected,
  };

  /// بث طلبات المطبخ: معلّقة + مرفوضة (لتبويبي لوحة الإدارة).
  static Stream<List<DeliveryOrder>> watchKitchenDashboardOrders({
    required String slug,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    if (!StabilityPhase1Flags.enablePhase1RealtimeHardening) {
      return _legacyWatchKitchenDashboardOrders(slug: slug);
    }
    final normalized = slug.trim().toLowerCase();

    return _resilientOrdersStream(
      sourceFactory: () =>
          _client.from(tableName).stream(primaryKey: const ['id']),
      transform: (rows) {
        final orders = <DeliveryOrder>[];
        for (final row in rows) {
          try {
            final order = DeliveryOrder.fromSupabase(
              Map<String, dynamic>.from(row),
            );
            if (!_kitchenDashboardStatuses.contains(order.status)) continue;
            final orderSlug = order.slug.trim().toLowerCase();
            final orderRestaurant = order.restaurantId.trim().toLowerCase();
            if (orderSlug.isEmpty && orderRestaurant.isEmpty) {
              orders.add(order);
              continue;
            }
            if (orderSlug == normalized || orderRestaurant == normalized) {
              orders.add(order);
            }
          } catch (_) {}
        }
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return orders;
      },
      streamTag: 'watchKitchenDashboardOrders(slug=$normalized)',
      onHealthChanged: StabilityPhase1Flags.enablePhase1HealthSignals
          ? onHealthChanged
          : null,
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
    final normalized = slug.trim().toLowerCase();

    try {
      final rows = await _client
          .from(tableName)
          .select()
          .gte('created_at', dayStart.toUtc().toIso8601String())
          .lt('created_at', dayEnd.toUtc().toIso8601String())
          .order('created_at', ascending: false);

      final orders = <DeliveryOrder>[];
      for (final row in rows) {
        try {
          final order = DeliveryOrder.fromSupabase(
            Map<String, dynamic>.from(row),
          );
          if (!_closingCountableStatuses.contains(order.status)) {
            continue;
          }
          final orderSlug = order.slug.trim().toLowerCase();
          final orderRestaurant = order.restaurantId.trim().toLowerCase();
          if (orderSlug.isEmpty && orderRestaurant.isEmpty) {
            orders.add(order);
            continue;
          }
          if (orderSlug == normalized || orderRestaurant == normalized) {
            orders.add(order);
          }
        } catch (e, st) {
          debugPrint(
            '[SupabaseOrderService] تخطي صف تقرير ${row['id']}: $e\n$st',
          );
        }
      }

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
      rethrow;
    }
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
    final orders = <DeliveryOrder>[];
    for (final row in rows) {
      try {
        final order = DeliveryOrder.fromSupabase(
          Map<String, dynamic>.from(row),
        );
        final orderPhone = IraqiPhoneValidator.normalize(order.customerPhone);
        if (orderPhone != normalizedPhone) continue;
        if (!_orderMatchesSlug(order, normalizedSlug)) continue;
        if (!CustomerMyOrdersConfig.isOrderVisibleToCustomer(order.createdAt)) {
          continue;
        }
        orders.add(order);
      } catch (e, st) {
        debugPrint(
          '[SupabaseOrderService] تخطي صف طلب ${row['id']}: $e\n$st',
        );
      }
    }
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
    final normalized = slug.trim().toLowerCase();
    return _client.from(tableName).stream(primaryKey: const ['id']).map((rows) {
      final orders = <DeliveryOrder>[];
      for (final row in rows) {
        try {
          final order = DeliveryOrder.fromSupabase(Map<String, dynamic>.from(row));
          if (order.status != DeliveryOrderStatus.pending) continue;
          final orderSlug = order.slug.trim().toLowerCase();
          final orderRestaurant = order.restaurantId.trim().toLowerCase();
          if (orderSlug.isEmpty && orderRestaurant.isEmpty) {
            orders.add(order);
            continue;
          }
          if (orderSlug == normalized || orderRestaurant == normalized) {
            orders.add(order);
          }
        } catch (_) {
          // Legacy path: keep behavior resilient by skipping malformed rows.
        }
      }
      orders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return orders;
    });
  }

  static Stream<List<DeliveryOrder>> _legacyWatchActiveOrders({
    required String slug,
  }) {
    final normalized = slug.trim().toLowerCase();
    return _client.from(tableName).stream(primaryKey: const ['id']).map((rows) {
      final orders = <DeliveryOrder>[];
      for (final row in rows) {
        try {
          final order = DeliveryOrder.fromSupabase(Map<String, dynamic>.from(row));
          if (!_activeOrderStatuses.contains(order.status)) continue;
          final orderSlug = order.slug.trim().toLowerCase();
          final orderRestaurant = order.restaurantId.trim().toLowerCase();
          if (orderSlug.isEmpty && orderRestaurant.isEmpty) {
            orders.add(order);
            continue;
          }
          if (orderSlug == normalized || orderRestaurant == normalized) {
            orders.add(order);
          }
        } catch (_) {}
      }
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  static Stream<List<DeliveryOrder>> _legacyWatchKitchenDashboardOrders({
    required String slug,
  }) {
    final normalized = slug.trim().toLowerCase();
    return _client.from(tableName).stream(primaryKey: const ['id']).map((rows) {
      final orders = <DeliveryOrder>[];
      for (final row in rows) {
        try {
          final order = DeliveryOrder.fromSupabase(Map<String, dynamic>.from(row));
          if (!_kitchenDashboardStatuses.contains(order.status)) continue;
          final orderSlug = order.slug.trim().toLowerCase();
          final orderRestaurant = order.restaurantId.trim().toLowerCase();
          if (orderSlug.isEmpty && orderRestaurant.isEmpty) {
            orders.add(order);
            continue;
          }
          if (orderSlug == normalized || orderRestaurant == normalized) {
            orders.add(order);
          }
        } catch (_) {}
      }
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  static Stream<List<DeliveryOrder>> _legacyWatchOrdersByPhone({
    required String slug,
    required String phoneNumber,
  }) {
    return _client.from(tableName).stream(primaryKey: const ['id']).map(
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
      try {
        return DeliveryOrder.fromSupabase(Map<String, dynamic>.from(rows.first));
      } catch (_) {
        return null;
      }
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
