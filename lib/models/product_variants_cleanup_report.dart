/// نتيجة تنظيف صفوف product_variants المكررة.
class ProductVariantsCleanupReport {
  const ProductVariantsCleanupReport({
    required this.products,
    required this.totalDeleted,
    required this.jsonbSyncedProductIds,
  });

  final List<ProductVariantsCleanupProductLog> products;
  final int totalDeleted;
  final List<String> jsonbSyncedProductIds;

  int get productsAffected =>
      products.where((entry) => entry.deletedCount > 0).length;

  bool get hasChanges => totalDeleted > 0;
}

class ProductVariantsCleanupProductLog {
  const ProductVariantsCleanupProductLog({
    required this.productId,
    required this.beforeCount,
    required this.afterCount,
    required this.deletedCount,
  });

  final String productId;
  final int beforeCount;
  final int afterCount;
  final int deletedCount;
}
