import 'package:flutter/foundation.dart';

import '../../core/config/location_feature_flags.dart';
import '../../models/delivery_location_source_kind.dart';
import '../../models/delivery_order_model.dart';
import '../../models/order_model.dart';
import '../../services/supabase_customer_location_service.dart';
import '../../services/supabase_order_service.dart';

/// مستودع طلبات الزبون — إرسال الطلبات فقط (بدون صلاحيات إدارية).
class CustomerOrderRepository {
  CustomerOrderRepository();

  Stream<DeliveryOrder?> watchOrderById({
    required String orderId,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return SupabaseOrderService.watchOrderById(
      orderId: orderId,
      onHealthChanged: onHealthChanged,
    );
  }

  Stream<List<DeliveryOrder>> watchOrdersByPhone({
    required String slug,
    required String phoneNumber,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return SupabaseOrderService.watchOrdersByPhone(
      slug: slug,
      phoneNumber: phoneNumber,
      onHealthChanged: onHealthChanged,
    );
  }

  Future<void> _persistSavedHomeIfRequested({
    required String restaurantId,
    required String customerPhone,
    required String address,
    required double latitude,
    required double longitude,
    DeliveryLocationSourceKind? locationSourceKind,
  }) async {
    if (!LocationFeatureFlags.enabled) return;

    if (kDebugMode) {
      debugPrint(
        '[CustomerOrderRepository] delivery_address=$address, '
        'delivery_latitude=$latitude, '
        'delivery_longitude=$longitude, '
        'delivery_location_source=${locationSourceKind?.logValue ?? 'unknown'}',
      );
    }

    await SupabaseCustomerLocationService.updateCustomerLocation(
      restaurantId: restaurantId,
      phoneNumber: customerPhone,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }

  Future<String> submitOrder({
    required String restaurantId,
    required String slug,
    required String customerName,
    required String customerPhone,
    required String address,
    double? latitude,
    double? longitude,
    required List<CartItem> items,
    required double totalPrice,
    bool persistSavedLocation = false,
    DeliveryLocationSourceKind? locationSourceKind,
  }) async {
    if (LocationFeatureFlags.enabled &&
        (latitude == null || longitude == null)) {
      throw StateError('delivery coordinates are required');
    }

    if (kDebugMode && LocationFeatureFlags.enabled) {
      debugPrint(
        '[CustomerOrderRepository] submit order location: '
        'delivery_latitude=$latitude, '
        'delivery_longitude=$longitude, '
        'delivery_address=$address, '
        'delivery_location_source=${locationSourceKind?.logValue ?? 'unknown'}, '
        'persist_saved=$persistSavedLocation',
      );
    }

    final orderId = await SupabaseOrderService.submitOrder(
      restaurantId: restaurantId,
      slug: slug,
      customerName: customerName,
      customerPhone: customerPhone,
      address: address,
      latitude: latitude,
      longitude: longitude,
      items: items,
      totalPrice: totalPrice,
    );

    if (persistSavedLocation &&
        latitude != null &&
        longitude != null &&
        locationSourceKind == DeliveryLocationSourceKind.updatedHome) {
      await _persistSavedHomeIfRequested(
        restaurantId: restaurantId,
        customerPhone: customerPhone,
        address: address,
        latitude: latitude,
        longitude: longitude,
        locationSourceKind: locationSourceKind,
      );
    }

    return orderId;
  }
}
