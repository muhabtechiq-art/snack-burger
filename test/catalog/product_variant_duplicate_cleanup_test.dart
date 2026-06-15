import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/core/catalog/product_variant_duplicate_cleanup.dart';

void main() {
  group('ProductVariantDuplicateCleanup', () {
    test('keeps first row and marks later duplicates for delete', () {
      const productId = '1781097320';
      final rows = [
        const ProductVariantDuplicateRow(
          id: '10',
          productId: productId,
          name: 'وسط',
          price: 5000,
        ),
        const ProductVariantDuplicateRow(
          id: '11',
          productId: productId,
          name: 'وسط',
          price: 5000,
        ),
        const ProductVariantDuplicateRow(
          id: '12',
          productId: productId,
          name: 'كبير',
          price: 8000,
        ),
        const ProductVariantDuplicateRow(
          id: '13',
          productId: productId,
          name: 'كبير',
          price: 8000,
        ),
      ];

      final duplicateIds =
          ProductVariantDuplicateCleanup.duplicateIdsToDelete(rows);

      expect(duplicateIds, ['11', '13']);
    });

    test('returns empty when no duplicates', () {
      final duplicateIds = ProductVariantDuplicateCleanup.duplicateIdsToDelete(
        const [
          ProductVariantDuplicateRow(
            id: '1',
            productId: 'p1',
            name: 'وسط',
            price: 5000,
          ),
          ProductVariantDuplicateRow(
            id: '2',
            productId: 'p1',
            name: 'كبير',
            price: 8000,
          ),
        ],
      );

      expect(duplicateIds, isEmpty);
    });
  });
}
