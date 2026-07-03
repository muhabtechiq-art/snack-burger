import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/models/product_model.dart';
import 'package:snack_burger/services/supabase_product_service.dart';

void main() {
  ProductModel product({String restaurantId = ''}) {
    return ProductModel(
      id: '1',
      restaurantId: restaurantId,
      name: 'Burger',
      price: 5000,
      category: 'general',
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  group('SupabaseProductService.resolveSaveProductRestaurantId', () {
    test('prefers product.restaurantId when present', () {
      final resolution = SupabaseProductService.resolveSaveProductRestaurantId(
        product: product(restaurantId: '  Tenant_A  '),
        tenantRestaurantId: 'tenant_b',
      );

      expect(resolution.restaurantId, 'tenant_a');
      expect(
        resolution.source,
        ProductSaveRestaurantIdSource.productRestaurantId,
      );
    });

    test('uses caller tenant when product restaurantId is empty', () {
      final resolution = SupabaseProductService.resolveSaveProductRestaurantId(
        product: product(),
        tenantRestaurantId: '  snack_burger  ',
      );

      expect(resolution.restaurantId, 'snack_burger');
      expect(resolution.source, ProductSaveRestaurantIdSource.callerTenant);
      expect(
        SupabaseProductService.saveProductRestaurantIdSourceLabel(
          resolution.source,
        ),
        'callerTenant',
      );
    });

    test('uses legacy fallback when product and caller tenant are empty', () {
      final resolution = SupabaseProductService.resolveSaveProductRestaurantId(
        product: product(),
        tenantRestaurantId: '   ',
      );

      expect(resolution.restaurantId, '');
      expect(resolution.source, ProductSaveRestaurantIdSource.legacyFallback);
      expect(
        SupabaseProductService.saveProductRestaurantIdSourceLabel(
          resolution.source,
        ),
        'legacyFallback',
      );
    });

    test('legacy fallback returns empty restaurant id without explicit tenant', () {
      final resolution = SupabaseProductService.resolveSaveProductRestaurantId(
        product: product(),
      );

      expect(resolution.restaurantId, isEmpty);
      expect(resolution.source, ProductSaveRestaurantIdSource.legacyFallback);
    });
  });
}
