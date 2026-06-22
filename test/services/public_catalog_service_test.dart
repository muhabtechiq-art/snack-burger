import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/services/public_catalog_service.dart';
import 'package:snack_burger/services/supabase_product_service.dart';

void main() {
  group('PublicCatalogService', () {
    test('publicCatalogRpcLabel normalizes slug', () {
      expect(
        PublicCatalogService.publicCatalogRpcLabel('  Snack_Burger  '),
        'get_public_*(p_restaurant_slug=snack_burger)',
      );
    });

    test('parsePublicBannerRows keeps active banners sorted', () {
      final banners = PublicCatalogService.parsePublicBannerRows(
        [
          {
            'id': 'b2',
            'restaurant_id': 'snack_burger',
            'image_url': 'https://example.com/2.jpg',
            'title': 'ثاني',
            'is_active': true,
            'sort_order': 1,
            'created_at': '2026-01-02T00:00:00Z',
          },
          {
            'id': 'b1',
            'restaurant_id': 'snack_burger',
            'image_url': 'https://example.com/1.jpg',
            'title': 'أول',
            'is_active': true,
            'sort_order': 0,
            'created_at': '2026-01-01T00:00:00Z',
          },
          {
            'id': 'b3',
            'restaurant_id': 'snack_burger',
            'image_url': 'https://example.com/3.jpg',
            'title': 'معطّل',
            'is_active': false,
            'sort_order': 2,
            'created_at': '2026-01-03T00:00:00Z',
          },
        ],
        'snack_burger',
      );

      expect(banners, hasLength(2));
      expect(banners.first.id, 'b1');
      expect(banners.last.id, 'b2');
    });
  });

  group('SupabaseProductService.assemblePublicMenuProducts', () {
    test('merges RPC product, addon, and variant rows for tenant', () {
      final products = SupabaseProductService.assemblePublicMenuProducts(
        restaurantDocId: 'snack_burger',
        productRows: [
          {
            'id': 10,
            'restaurant_id': 'snack_burger',
            'name': 'برجر',
            'price': 5000,
            'category': 'burgers',
            'variants': [],
            'is_available': true,
            'created_at': '2026-01-01T00:00:00Z',
          },
        ],
        addonRows: [
          {'product_id': 10, 'name': 'جبن', 'price': 500},
        ],
        variantRows: [
          {
            'id': 1,
            'product_id': 10,
            'name': 'كبير',
            'price': 7000,
            'sort_order': 0,
          },
        ],
      );

      expect(products, hasLength(1));
      expect(products.first.name, 'برجر');
      expect(products.first.addons, hasLength(1));
      expect(products.first.addons.first.name, 'جبن');
      expect(products.first.variants, hasLength(1));
      expect(products.first.variants.first.name, 'كبير');
    });

    test('merges uuid variant ids from RPC (production schema)', () {
      const variantUuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
      final products = SupabaseProductService.assemblePublicMenuProducts(
        restaurantDocId: 'snack_burger',
        productRows: [
          {
            'id': 42,
            'restaurant_id': 'snack_burger',
            'name': 'ساندويتش',
            'price': 3000,
            'category': 'sandwiches',
            'variants': [],
            'is_available': true,
            'created_at': '2026-01-01T00:00:00Z',
          },
        ],
        addonRows: const [],
        variantRows: [
          {
            'id': variantUuid,
            'product_id': 42,
            'name': 'وسط',
            'price': 3500,
            'sort_order': 0,
          },
        ],
      );

      expect(products, hasLength(1));
      expect(products.first.variants, hasLength(1));
      expect(products.first.variants.first.id, variantUuid);
      expect(products.first.variants.first.name, 'وسط');
    });

    test('excludes products outside restaurant scope', () {
      final products = SupabaseProductService.assemblePublicMenuProducts(
        restaurantDocId: 'snack_burger',
        productRows: [
          {
            'id': 11,
            'restaurant_id': 'other_place',
            'name': 'خارج النطاق',
            'price': 1000,
            'category': 'x',
            'is_available': true,
            'created_at': '2026-01-01T00:00:00Z',
          },
        ],
        addonRows: const [],
        variantRows: const [],
      );

      expect(products, isEmpty);
    });
  });
}
