import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/services/supabase_order_service.dart';

void main() {
  group('SupabaseOrderService.pendingOrdersStreamServerFilterLabel', () {
    test('returns slug=eq label for normalized slug', () {
      expect(
        SupabaseOrderService.pendingOrdersStreamServerFilterLabel(
          'snack_burger',
        ),
        'slug=eq.snack_burger',
      );
    });

    test('trims and lowercases slug in label', () {
      expect(
        SupabaseOrderService.pendingOrdersStreamServerFilterLabel(
          '  Snack_Burger  ',
        ),
        'slug=eq.snack_burger',
      );
    });

    test('returns none when slug is empty', () {
      expect(
        SupabaseOrderService.pendingOrdersStreamServerFilterLabel(''),
        'none',
      );
      expect(
        SupabaseOrderService.pendingOrdersStreamServerFilterLabel('   '),
        'none',
      );
    });
  });
}
