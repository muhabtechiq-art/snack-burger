import 'dart:async';

import '../models/delivery_order_model.dart';
import '../models/order_model.dart';
import 'supabase_order_service.dart';

/// واجهة مستودع الطلبات — تفوّض إلى Supabase.
class OrderRepository {
  OrderRepository();

  /// يحفظ طلباً جديداً في جدول `orders` على Supabase.
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
  }) {
    return SupabaseOrderService.submitOrder(
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
  }

  /// بث الطلبات المعلقة (`pending`) من Supabase.
  Stream<List<DeliveryOrder>> watchPendingOrders({required String slug}) {
    return SupabaseOrderService.watchPendingOrders(slug: slug);
  }

  /// تحديث حالة الطلب في Supabase.
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) {
    return SupabaseOrderService.updateOrderStatus(
      orderId: orderId,
      status: status,
    );
  }
}
