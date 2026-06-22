import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/services/supabase_order_service.dart';

void main() {
  group('SupabaseOrderService.activeOrdersStreamServerFilterLabel', () {
    test('returns slug=eq label for normalized slug', () {
      expect(
        SupabaseOrderService.activeOrdersStreamServerFilterLabel(
          'snack_burger',
        ),
        'slug=eq.snack_burger',
      );
    });

    test('trims and lowercases slug in label', () {
      expect(
        SupabaseOrderService.activeOrdersStreamServerFilterLabel(
          '  Snack_Burger  ',
        ),
        'slug=eq.snack_burger',
      );
    });

    test('returns none when slug is empty', () {
      expect(
        SupabaseOrderService.activeOrdersStreamServerFilterLabel(''),
        'none',
      );
      expect(
        SupabaseOrderService.activeOrdersStreamServerFilterLabel('   '),
        'none',
      );
    });
  });
}
