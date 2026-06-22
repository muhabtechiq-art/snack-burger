import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/models/product_model.dart';
import 'package:snack_burger/services/supabase_product_service.dart';

void main() {
  group('SupabaseProductService.fetchProductByIdServerFilterLabel', () {
    test('returns restaurant_id=eq label when scope is set', () {
      expect(
        SupabaseProductService.fetchProductByIdServerFilterLabel('snack_burger'),
        'restaurant_id=eq.snack_burger',
      );
    });

    test('returns none when restaurant id is empty', () {
      expect(
        SupabaseProductService.fetchProductByIdServerFilterLabel(''),
        'none',
      );
      expect(
        SupabaseProductService.fetchProductByIdServerFilterLabel(null),
        'none',
      );
    });
  });

  group('SupabaseProductService.productBelongsToRestaurantScope', () {
    ProductModel product({required String restaurantId}) {
      return ProductModel(
        id: '1',
        restaurantId: restaurantId,
        name: 'Burger',
        price: 5000,
        category: 'general',
        createdAt: DateTime.utc(2026, 1, 1),
      );
    }

    test('allows any product when restaurant scope is empty', () {
      expect(
        SupabaseProductService.productBelongsToRestaurantScope(
          product(restaurantId: 'other_tenant'),
          null,
        ),
        isTrue,
      );
    });

    test('matches normalized restaurant id', () {
      expect(
        SupabaseProductService.productBelongsToRestaurantScope(
          product(restaurantId: 'snack_burger'),
          '  Snack_Burger  ',
        ),
        isTrue,
      );
    });

    test('rejects product from another restaurant', () {
      expect(
        SupabaseProductService.productBelongsToRestaurantScope(
          product(restaurantId: 'other_tenant'),
          'snack_burger',
        ),
        isFalse,
      );
    });
  });
}
