import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/services/supabase_order_service.dart';

void main() {
  group('SupabaseOrderService.ordersByPhoneStreamServerFilterLabel', () {
    test('returns slug=eq label for normalized slug', () {
      expect(
        SupabaseOrderService.ordersByPhoneStreamServerFilterLabel(
          'snack_burger',
        ),
        'slug=eq.snack_burger',
      );
    });

    test('trims and lowercases slug in label', () {
      expect(
        SupabaseOrderService.ordersByPhoneStreamServerFilterLabel(
          '  Snack_Burger  ',
        ),
        'slug=eq.snack_burger',
      );
    });

    test('returns none when slug is empty', () {
      expect(
        SupabaseOrderService.ordersByPhoneStreamServerFilterLabel(''),
        'none',
      );
      expect(
        SupabaseOrderService.ordersByPhoneStreamServerFilterLabel('   '),
        'none',
      );
    });
  });
}
