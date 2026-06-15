import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/core/catalog/product_variants_resolver.dart';
import 'package:snack_burger/models/product_model.dart';

void main() {
  test('prefers jsonb variants over duplicated table rows', () {
    const jsonb = [
      ProductVariant(name: 'وسط', price: 5000),
      ProductVariant(name: 'كبير', price: 8000),
    ];
    const table = [
      ProductVariant(name: 'وسط', price: 5000),
      ProductVariant(name: 'كبير', price: 8000),
      ProductVariant(name: 'وسط', price: 5000),
      ProductVariant(name: 'كبير', price: 8000),
    ];

    final resolved = ProductVariantsResolver.resolve(
      productId: '1781097320',
      jsonbVariants: jsonb,
      tableVariants: table,
    );

    expect(resolved.source, ProductVariantsResolver.sourceJsonb);
    expect(resolved.variants.length, 2);
    expect(resolved.variants.map((v) => v.name).toList(), ['وسط', 'كبير']);
  });

  test('falls back to table when jsonb is empty', () {
    final resolved = ProductVariantsResolver.resolve(
      productId: '1',
      jsonbVariants: const [],
      tableVariants: const [
        ProductVariant(name: 'صغير', price: 3000),
      ],
    );

    expect(resolved.source, ProductVariantsResolver.sourceTable);
    expect(resolved.variants.length, 1);
  });
}
