import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/models/delivery_order_model.dart';
import 'package:snack_burger/models/order_model.dart';
import 'package:snack_burger/services/receipt_escpos_builder.dart';

DeliveryOrder _sampleOrder() {
  return DeliveryOrder(
    id: '42',
    restaurantId: 'snack_burger',
    slug: 'snack_burger',
    customerName: 'أحمد',
    customerPhone: '07701234567',
    address: 'بغداد',
    items: const [
      CartItem(
        lineId: 'line-1',
        productId: 'p1',
        name: 'برجر',
        quantity: 2,
        baseUnitPrice: 5000,
        unitPrice: 5000,
        selectedAddons: [],
      ),
    ],
    totalPrice: 10000,
    status: 'accepted',
    createdAt: DateTime.utc(2026, 6, 19, 12, 30),
    businessDayOrderNumber: 7,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptEscPosBuilder split receipt bytes', () {
    test('buildCashierReceiptBytes and buildKitchenReceiptBytes are non-empty',
        () async {
      final order = _sampleOrder();

      final cashier = await ReceiptEscPosBuilder.buildCashierReceiptBytes(order);
      final kitchen = await ReceiptEscPosBuilder.buildKitchenReceiptBytes(order);

      expect(cashier, isNotEmpty);
      expect(kitchen, isNotEmpty);
    });

    test('buildOrderReceiptBytes equals cashier + kitchen concatenation',
        () async {
      final order = _sampleOrder();

      final combined = await ReceiptEscPosBuilder.buildOrderReceiptBytes(order);
      final cashier = await ReceiptEscPosBuilder.buildCashierReceiptBytes(order);
      final kitchen = await ReceiptEscPosBuilder.buildKitchenReceiptBytes(order);

      expect(combined, <int>[...cashier, ...kitchen]);
    });

    test('kitchen bytes differ from cashier bytes', () async {
      final order = _sampleOrder();

      final cashier = await ReceiptEscPosBuilder.buildCashierReceiptBytes(order);
      final kitchen = await ReceiptEscPosBuilder.buildKitchenReceiptBytes(order);

      expect(kitchen, isNot(equals(cashier)));
    });
  });
}
