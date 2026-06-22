import 'package:flutter/foundation.dart';

import '../../models/delivery_order_model.dart';
import '../observability/app_telemetry.dart';

/// مطابقة tenant للطلب — slug و/أو `restaurants.restaurant_uuid`.
abstract final class OrderTenantMatch {
  OrderTenantMatch._();

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static final Set<String> _warnedOrderIds = <String>{};
  static const int _maxWarnedIds = 200;

  static String normalizeSlug(String slug) => slug.trim().toLowerCase();

  static String? normalizeUuid(String? uuid) {
    if (uuid == null) return null;
    final normalized = uuid.trim().toLowerCase();
    if (normalized.isEmpty || !_uuidPattern.hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }

  static bool isUuid(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty && _uuidPattern.hasMatch(normalized);
  }

  static bool hasTenantMarker(DeliveryOrder order) {
    return order.slug.trim().isNotEmpty || order.restaurantId.trim().isNotEmpty;
  }

  /// يطابق الطلب إذا:
  /// - `order.slug == activeSlug`
  /// - أو `order.restaurant_id == activeRestaurantUuid` (UUID)
  /// - أو legacy: `order.restaurant_id` نصي يساوي [activeSlug]
  ///
  /// طلب بلا slug ولا restaurant_id لا يُطابق أي مطعم.
  static bool matches(
    DeliveryOrder order, {
    required String activeSlug,
    String? activeRestaurantUuid,
  }) {
    final normalizedSlug = normalizeSlug(activeSlug);
    final normalizedUuid = normalizeUuid(activeRestaurantUuid);

    final orderSlug = normalizeSlug(order.slug);
    final orderRestaurant = order.restaurantId.trim().toLowerCase();

    if (orderSlug.isEmpty && orderRestaurant.isEmpty) {
      _warnMissingTenant(order);
      return false;
    }

    if (orderSlug.isNotEmpty && orderSlug == normalizedSlug) {
      return true;
    }

    if (normalizedUuid != null &&
        orderRestaurant.isNotEmpty &&
        isUuid(orderRestaurant) &&
        orderRestaurant == normalizedUuid) {
      return true;
    }

    // Legacy — restaurant_id كان slug نصي قبل ربط UUID في orders
    if (orderRestaurant.isNotEmpty &&
        !isUuid(orderRestaurant) &&
        orderRestaurant == normalizedSlug) {
      return true;
    }

    return false;
  }

  static void _warnMissingTenant(DeliveryOrder order) {
    final id = order.id.trim();
    if (id.isNotEmpty) {
      if (_warnedOrderIds.length >= _maxWarnedIds) {
        _warnedOrderIds.clear();
      }
      if (!_warnedOrderIds.add(id)) return;
    }

    debugPrint(
      '[OrderTenantMatch] order id=${id.isEmpty ? "(unknown)" : id} '
      'missing slug and restaurant_id — excluded from tenant filter',
    );
    AppTelemetry.logEvent(
      'order_missing_tenant_marker',
      fields: <String, Object?>{
        'order_id': id.isEmpty ? null : id,
      },
    );
  }

  @visibleForTesting
  static void resetWarningsForTest() {
    _warnedOrderIds.clear();
  }
}
