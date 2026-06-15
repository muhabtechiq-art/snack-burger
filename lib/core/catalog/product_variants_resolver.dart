import 'package:flutter/foundation.dart';

import '../../models/product_model.dart';

/// مصدر أحجام المنتج للزبون — jsonb أولاً، ثم جدول product_variants.
abstract final class ProductVariantsResolver {
  ProductVariantsResolver._();

  static const String sourceJsonb = 'jsonb';
  static const String sourceTable = 'table';

  /// مصدر واحد فقط — لا دمج بين jsonb والجدول.
  static ({List<ProductVariant> variants, String source}) resolve({
    required String productId,
    required List<ProductVariant> jsonbVariants,
    required List<ProductVariant> tableVariants,
    bool logCustomerSource = false,
  }) {
    final raw =
        jsonbVariants.isNotEmpty ? jsonbVariants : tableVariants;
    final source =
        jsonbVariants.isNotEmpty ? sourceJsonb : sourceTable;
    final deduped = ProductVariant.deduplicate(raw);

    if (logCustomerSource && kDebugMode && deduped.isNotEmpty) {
      debugPrint(
        '[QA][CustomerVariantsSource] productId=$productId '
        'source=$source count=${deduped.length}',
      );
    }

    return (variants: deduped, source: source);
  }

  /// يُسجّل مصدر الأحجام عند فتح تفاصيل المنتج للزبون.
  static void logCustomerProductDetail(ProductModel product) {
    if (!kDebugMode || !product.hasVariants) return;

    final source = product.variantsSource ?? 'unknown';
    debugPrint(
      '[QA][CustomerVariantsSource] productId=${product.id} '
      'source=$source count=${product.variants.length}',
    );
  }
}
