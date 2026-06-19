import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/models/delivery_order_model.dart';

DeliveryOrder _order({
  required String id,
  int? businessDayOrderNumber,
}) {
  return DeliveryOrder(
    id: id,
    restaurantId: 'restaurant',
    slug: 'snack_burger',
    customerName: 'Customer',
    customerPhone: '07701234567',
    address: 'Address',
    items: const [],
    totalPrice: 5000,
    status: 'pending',
    createdAt: DateTime.utc(2026, 6, 19),
    businessDayId: 'day-1',
    businessDayOrderNumber: businessDayOrderNumber,
  );
}

void main() {
  group('DeliveryOrder display order number', () {
    test('uses daily number when present', () {
      final order = _order(id: '196', businessDayOrderNumber: 7);
      expect(order.displayOrderNumber, '#7');
      expect(order.displayOrderHeroLabel, 'طلب رقم #7');
    });

    test('falls back to legacy padded id when daily number is null', () {
      final order = _order(id: '196');
      expect(order.displayOrderNumber, '#000196');
      expect(order.displayOrderHeroLabel, 'طلب رقم #000196');
    });

    test('falls back when daily number is zero', () {
      final order = _order(id: '42', businessDayOrderNumber: 0);
      expect(order.displayOrderNumber, '#000042');
    });

    test('fromMap parses business_day_order_number', () {
      final order = DeliveryOrder.fromMap(
        {
          'customer_name': 'Test',
          'phone_number': '07701234567',
          'address': 'Addr',
          'status': 'pending',
          'created_at': '2026-06-19T12:00:00Z',
          'order_items': [],
          'slug': 'snack_burger',
          'business_day_order_number': 3,
        },
        id: '999',
      );
      expect(order.businessDayOrderNumber, 3);
      expect(order.displayOrderNumber, '#3');
    });
  });
}
