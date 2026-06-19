import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/core/utils/business_day_order_aggregation.dart';
import 'package:snack_burger/models/delivery_order_model.dart';
import 'package:snack_burger/models/delivery_order_status.dart';

DeliveryOrder _order({
  required String status,
  double totalPrice = 0,
}) {
  return DeliveryOrder(
    id: 'order-$status-$totalPrice',
    restaurantId: 'restaurant',
    slug: 'snack_burger',
    customerName: 'Customer',
    customerPhone: '07701234567',
    address: 'Address',
    items: const [],
    totalPrice: totalPrice,
    status: status,
    createdAt: DateTime.utc(2026, 6, 3),
    businessDayId: 'day-1',
  );
}

void main() {
  group('aggregateBusinessDayOrders', () {
    test('counts pending separately from closing countable sales', () {
      final stats = aggregateBusinessDayOrders([
        _order(status: DeliveryOrderStatus.pending),
        _order(status: DeliveryOrderStatus.pending),
        _order(status: DeliveryOrderStatus.accepted, totalPrice: 100),
        _order(status: DeliveryOrderStatus.delivered, totalPrice: 50),
        _order(status: DeliveryOrderStatus.rejected),
      ]);

      expect(stats.allOrdersCount, 5);
      expect(stats.pendingOrdersCount, 2);
      expect(stats.closingCountableOrders, 2);
      expect(stats.closingCountableSales, 150);
    });

    test('excludes pending from closing sales', () {
      final stats = aggregateBusinessDayOrders([
        _order(status: DeliveryOrderStatus.pending, totalPrice: 999),
      ]);

      expect(stats.allOrdersCount, 1);
      expect(stats.pendingOrdersCount, 1);
      expect(stats.closingCountableOrders, 0);
      expect(stats.closingCountableSales, 0);
    });
  });
}
