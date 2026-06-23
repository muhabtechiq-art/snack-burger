import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/services/supabase_order_service.dart';

void main() {
  group('mapMyOrdersCustomerRpcRow', () {
    test('maps RPC aliases to DeliveryOrder field names', () {
      final mapped = SupabaseOrderService.mapMyOrdersCustomerRpcRow({
        'id': 245,
        'status': 'accepted',
        'total': 15000,
        'customer_name': 'زبون',
        'phone_number': '07827399119',
        'delivery_address': 'بغداد',
        'notes': 'سبب',
        'created_at': '2026-06-23T20:00:00Z',
        'slug': 'snack_burger',
        'items': const [],
        'business_day_id': 'c2ff3f8c-95e8-494e-9b6a-07c2c3713136',
      });

      expect(mapped['total_price'], 15000);
      expect(mapped['address'], 'بغداد');
      expect(mapped['order_items'], isEmpty);
      expect(mapped['rejection_reason'], 'سبب');
    });
  });
}
