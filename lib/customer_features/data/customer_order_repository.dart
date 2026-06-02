import 'package:flutter/foundation.dart';

import '../../core/config/location_feature_flags.dart';
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
  }) async {
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

    if (LocationFeatureFlags.enabled &&
        latitude != null &&
        longitude != null) {
      await SupabaseCustomerLocationService.updateCustomerLocation(
        phoneNumber: customerPhone,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
    }

    return orderId;
  }
}
