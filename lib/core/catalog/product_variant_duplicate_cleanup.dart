import '../utils/price_utils.dart';

/// تحديد صفوف product_variants المكررة للحذف — بدون insert/update.
abstract final class ProductVariantDuplicateCleanup {
  ProductVariantDuplicateCleanup._();

  static String duplicateKey({
    required String productId,
    required String name,
    required double price,
  }) {
    return PriceUtils.variantDuplicateKey(
      productId: productId,
      name: name,
      price: price,
    );
  }

  /// يُبقي أول صف (أصغر id) ويُرجع ids الباقي للحذف.
  static List<String> duplicateIdsToDelete(
    List<ProductVariantDuplicateRow> rows,
  ) {
    if (rows.length <= 1) return const [];

    final sorted = List<ProductVariantDuplicateRow>.from(rows)
      ..sort((a, b) => a.id.compareTo(b.id));

    final seenKeys = <String>{};
    final duplicateIds = <String>[];

    for (final row in sorted) {
      final key = duplicateKey(
        productId: row.productId,
        name: row.name,
        price: row.price,
      );
      if (seenKeys.add(key)) continue;
      duplicateIds.add(row.id);
    }

    return duplicateIds;
  }
}

class ProductVariantDuplicateRow {
  const ProductVariantDuplicateRow({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
  });

  final String id;
  final String productId;
  final String name;
  final double price;
}
