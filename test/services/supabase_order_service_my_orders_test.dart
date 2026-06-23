import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/core/config/customer_my_orders_config.dart';
import 'package:snack_burger/models/delivery_order_status.dart';
import 'package:snack_burger/services/supabase_order_service.dart';

void main() {
  group('SupabaseOrderService.filterOrdersByPhoneAndSlug', () {
    Map<String, dynamic> row({
      required String id,
      required String status,
      String slug = 'snack_burger',
      String restaurantId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
      String phone = '07701234567',
      DateTime? createdAt,
    }) {
      return {
        'id': id,
        'slug': slug,
        'restaurant_id': restaurantId,
        'phone_number': phone,
        'customer_name': 'زبون',
        'address': 'بغداد',
        'status': status,
        'order_items': const [],
        'total_price': 5000,
        'created_at': (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
      };
    }

    test('includes accepted orders within visibility window', () {
      final orders = SupabaseOrderService.filterOrdersByPhoneAndSlug(
        rows: [
          row(id: '1', status: DeliveryOrderStatus.accepted),
          row(id: '2', status: DeliveryOrderStatus.pending),
        ],
        normalizedSlug: 'snack_burger',
      );

      expect(orders, hasLength(2));
      expect(orders.map((o) => o.status), contains('accepted'));
    });

    test('includes accepted even when restaurant_id UUID differs', () {
      final orders = SupabaseOrderService.filterOrdersByPhoneAndSlug(
        rows: [
          row(
            id: '4',
            status: DeliveryOrderStatus.accepted,
            restaurantId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
          ),
        ],
        normalizedSlug: 'snack_burger',
      );

      expect(orders, hasLength(1));
    });

    test('excludes orders older than customer visibility window', () {
      final orders = SupabaseOrderService.filterOrdersByPhoneAndSlug(
        rows: [
          row(
            id: '5',
            status: DeliveryOrderStatus.accepted,
            createdAt:
                DateTime.now().toUtc().subtract(const Duration(hours: 7)),
          ),
        ],
        normalizedSlug: 'snack_burger',
      );

      expect(orders, isEmpty);
    });

    test('includes ready and completed statuses within window', () {
      final orders = SupabaseOrderService.filterOrdersByPhoneAndSlug(
        rows: [
          row(id: '6', status: DeliveryOrderStatus.ready),
          row(id: '7', status: DeliveryOrderStatus.completed),
        ],
        normalizedSlug: 'snack_burger',
      );

      expect(orders, hasLength(2));
    });
  });

  group('CustomerMyOrdersConfig', () {
    test('visible window is six hours', () {
      expect(CustomerMyOrdersConfig.visibleOrdersWindow.inHours, 6);
    });
  });
}
