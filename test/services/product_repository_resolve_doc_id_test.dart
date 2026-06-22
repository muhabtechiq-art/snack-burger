import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/services/product_repository.dart';
import 'package:snack_burger/services/supabase_product_service.dart';

void main() {
  group('ProductRepository.resolveRestaurantDocIdWithSource', () {
    test('prefers restaurantId when present', () {
      final resolution = ProductRepository.resolveRestaurantDocIdWithSource(
        restaurantId: '  Tenant_A  ',
        slug: 'tenant_b',
      );

      expect(resolution.docId, 'tenant_a');
      expect(resolution.source, RestaurantDocIdSource.restaurantId);
      expect(
        ProductRepository.restaurantDocIdSourceLabel(resolution.source),
        'restaurantId',
      );
    });

    test('uses slug when restaurantId is empty', () {
      final resolution = ProductRepository.resolveRestaurantDocIdWithSource(
        restaurantId: '',
        slug: '  Snack_Burger  ',
      );

      expect(resolution.docId, 'snack_burger');
      expect(resolution.source, RestaurantDocIdSource.slug);
      expect(
        ProductRepository.restaurantDocIdSourceLabel(resolution.source),
        'slug',
      );
    });

    test('uses legacy fallback when both are blank', () {
      final resolution = ProductRepository.resolveRestaurantDocIdWithSource(
        restaurantId: '   ',
        slug: '',
      );

      expect(resolution.docId, SupabaseProductService.defaultRestaurantId);
      expect(resolution.source, RestaurantDocIdSource.legacyFallback);
      expect(
        ProductRepository.restaurantDocIdSourceLabel(resolution.source),
        'legacyFallback',
      );
    });
  });

  group('ProductRepository.resolveRestaurantDocId', () {
    test('returns same doc id as resolveRestaurantDocIdWithSource', () {
      expect(
        ProductRepository.resolveRestaurantDocId(
          restaurantId: 'tenant_a',
          slug: 'tenant_b',
        ),
        'tenant_a',
      );
      expect(
        ProductRepository.resolveRestaurantDocId(
          restaurantId: '',
          slug: 'tenant_b',
        ),
        'tenant_b',
      );
      expect(
        ProductRepository.resolveRestaurantDocId(
          restaurantId: '',
          slug: '',
        ),
        SupabaseProductService.defaultRestaurantId,
      );
    });
  });
}
