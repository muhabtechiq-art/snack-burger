import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/services/supabase_product_service.dart';

void main() {
  group('SupabaseProductService.hasVariantTableQueryTargets', () {
    test('returns false for empty product id list', () {
      expect(SupabaseProductService.hasVariantTableQueryTargets([]), isFalse);
    });

    test('returns false when all product ids are blank', () {
      expect(
        SupabaseProductService.hasVariantTableQueryTargets(['', '   ']),
        isFalse,
      );
    });

    test('returns true when at least one serializable product id exists', () {
      expect(
        SupabaseProductService.hasVariantTableQueryTargets(['42', '']),
        isTrue,
      );
      expect(
        SupabaseProductService.hasVariantTableQueryTargets(['abc-uuid']),
        isTrue,
      );
    });
  });
}
