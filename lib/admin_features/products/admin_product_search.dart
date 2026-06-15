import '../../core/utils/price_utils.dart';
import '../../models/product_model.dart';

/// فلترة محلية لمنتجات لوحة الإدارة — بدون طلبات شبكة.
abstract final class AdminProductSearch {
  AdminProductSearch._();

  static String normalizeQuery(String raw) => raw.trim().toLowerCase();

  static List<ProductModel> filter(
    List<ProductModel> products,
    String rawQuery,
  ) {
    final query = normalizeQuery(rawQuery);
    if (query.isEmpty) {
      return List<ProductModel>.from(products);
    }

    return products
        .where((product) => matches(product, query))
        .toList(growable: false);
  }

  static bool matches(ProductModel product, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;

    final name = product.name.trim().toLowerCase();
    final category = product.category.trim().toLowerCase();
    final priceText = PriceUtils.normalizedPriceKey(product.price);
    final displayPriceText = PriceUtils.normalizedPriceKey(product.displayPrice);
    final formattedPrice = PriceUtils.formatPrice(product.price);
    final formattedDisplayPrice = PriceUtils.formatPrice(product.displayPrice);

    return name.contains(normalizedQuery) ||
        category.contains(normalizedQuery) ||
        priceText.contains(normalizedQuery) ||
        displayPriceText.contains(normalizedQuery) ||
        formattedPrice.contains(normalizedQuery) ||
        formattedDisplayPrice.contains(normalizedQuery);
  }
}
