import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/services/supabase_product_service.dart';

void main() {
  group('SupabaseProductService.productsServerFilterLabel', () {
    test('returns restaurant_id=eq label for normalized id', () {
      expect(
        SupabaseProductService.productsServerFilterLabel('snack_burger'),
        'restaurant_id=eq.snack_burger',
      );
    });

    test('trims and lowercases restaurant id in label', () {
      expect(
        SupabaseProductService.productsServerFilterLabel('  Snack_Burger  '),
        'restaurant_id=eq.snack_burger',
      );
    });

    test('returns none when restaurant id is empty', () {
      expect(
        SupabaseProductService.productsServerFilterLabel(''),
        'none',
      );
      expect(
        SupabaseProductService.productsServerFilterLabel('   '),
        'none',
      );
      expect(
        SupabaseProductService.productsServerFilterLabel(null),
        'none',
      );
    });
  });
}
