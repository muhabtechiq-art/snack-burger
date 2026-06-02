import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/location_feature_flags.dart';
import '../core/config/restaurant_ids.dart';
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
  static const Duration _streamReconnectDelay = Duration(seconds: 2);

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
      return id;
    } catch (e, stack) {
      debugPrint('[SupabaseOrderService] submitOrder فشل: $e\n$stack');
      rethrow;
    }
  }

  /// بث الطلبات ذات الحالة `pending`.
  static Stream<List<DeliveryOrder>> watchPendingOrders({
    required String slug,
  }) {
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
    );
  }

  /// بث تفاصيل طلب واحد بالمعرّف لدعم شاشة تتبع الزبون.
  static Stream<DeliveryOrder?> watchOrderById({
    required String orderId,
  }) {
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
    );
  }

  static const Set<String> _closingCountableStatuses = {
    DeliveryOrderStatus.accepted,
    DeliveryOrderStatus.delivering,
    DeliveryOrderStatus.delivered,
  };

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
          .lt('created_at', dayEnd.toUtc().toIso8601String());

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
    try {
      await _client.from(tableName).update({
        'status': status,
      }).eq('id', orderId);
      debugPrint('[SupabaseOrderService] تحديث حالة $orderId → $status');
    } catch (e, stack) {
      debugPrint('[SupabaseOrderService] updateOrderStatus فشل: $e\n$stack');
      rethrow;
    }
  }

  static Stream<T> _resilientOrdersStream<T>({
    required Stream<List<Map<String, dynamic>>> Function() sourceFactory,
    required T Function(List<Map<String, dynamic>> rows) transform,
    required String streamTag,
  }) {
    return Stream<T>.multi((controller) {
      StreamSubscription<List<Map<String, dynamic>>>? subscription;
      bool closed = false;

      Future<void> subscribe() async {
        if (closed) return;
        await subscription?.cancel();
        subscription = sourceFactory().listen(
          (rows) {
            if (closed) return;
            controller.add(transform(rows));
          },
          onError: (Object error, StackTrace stackTrace) async {
            debugPrint('[SupabaseOrderService] $streamTag error: $error');
            if (closed) return;
            await subscription?.cancel();
            await Future<void>.delayed(_streamReconnectDelay);
            if (!closed) {
              unawaited(subscribe());
            }
          },
          onDone: () async {
            if (closed) return;
            await Future<void>.delayed(_streamReconnectDelay);
            if (!closed) {
              unawaited(subscribe());
            }
          },
          cancelOnError: false,
        );
      }

      unawaited(subscribe());

      controller.onCancel = () async {
        closed = true;
        await subscription?.cancel();
      };
    });
  }
}
