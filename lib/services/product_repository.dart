import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/utils/product_id_generator.dart';
import '../models/product_model.dart';
import '../models/product_variants_cleanup_report.dart';
import 'image_pick_upload_service.dart';
import 'public_catalog_service.dart';
import 'supabase_product_service.dart';

/// مصدر doc id للمطعم عند [ProductRepository.resolveRestaurantDocId].
enum RestaurantDocIdSource {
  restaurantId,
  slug,
  legacyFallback,
}

/// واجهة مستودع المنتجات — تفوّض إلى Supabase.
class ProductRepository {
  ProductRepository({ImagePickUploadService? imageUploadService})
      : _imageUploadService = imageUploadService ?? ImagePickUploadService();

  final ImagePickUploadService _imageUploadService;

  /// يُحدّد doc id والمصدر — للاختبار والتشخيص.
  @visibleForTesting
  static ({String docId, RestaurantDocIdSource source}) resolveRestaurantDocIdWithSource({
    required String restaurantId,
    required String slug,
  }) {
    final normalizedRestaurantId = restaurantId.trim().toLowerCase();
    if (normalizedRestaurantId.isNotEmpty) {
      return (
        docId: normalizedRestaurantId,
        source: RestaurantDocIdSource.restaurantId,
      );
    }

    final normalizedSlug = slug.trim().toLowerCase();
    if (normalizedSlug.isNotEmpty) {
      return (
        docId: normalizedSlug,
        source: RestaurantDocIdSource.slug,
      );
    }

    return (
      docId: '',
      source: RestaurantDocIdSource.legacyFallback,
    );
  }

  /// تسمية المصدر للاختبار والسجلات.
  @visibleForTesting
  static String restaurantDocIdSourceLabel(RestaurantDocIdSource source) {
    return switch (source) {
      RestaurantDocIdSource.restaurantId => 'restaurantId',
      RestaurantDocIdSource.slug => 'slug',
      RestaurantDocIdSource.legacyFallback => 'legacyFallback',
    };
  }

  static String resolveRestaurantDocId({
    required String restaurantId,
    required String slug,
  }) {
    final resolution = resolveRestaurantDocIdWithSource(
      restaurantId: restaurantId,
      slug: slug,
    );
    if (resolution.source == RestaurantDocIdSource.legacyFallback) {
      debugPrint(
        '[ProductRepository] WARNING legacy tenant fallback: restaurantId and '
        'slug both empty — using ${SupabaseProductService.defaultRestaurantId} '
        '(temporary; pass explicit tenant scope)',
      );
    }
    return resolution.docId;
  }

  String _docId({
    required String restaurantId,
    required String slug,
  }) {
    return resolveRestaurantDocId(restaurantId: restaurantId, slug: slug);
  }

  static ProductModel _productForSave({
    required ProductModel product,
    required String restaurantDocId,
    String? imageUrl,
  }) {
    return ProductModel(
      id: product.id,
      restaurantId: restaurantDocId,
      name: product.name,
      description: product.description,
      price: product.price,
      category: product.category,
      addons: product.addons,
      variants: product.variants,
      imageUrl: imageUrl ?? product.imageUrl,
      isAvailable: product.isAvailable,
      createdAt: product.createdAt,
    );
  }

  Future<List<ProductModel>> fetchProductsForRestaurant({
    required String restaurantId,
    required String slug,
  }) {
    return SupabaseProductService.fetchProducts(
      restaurantId: _docId(restaurantId: restaurantId, slug: slug),
    );
  }

  /// منيو الزبون — قراءة عبر RPC (C-04) وليس SELECT مباشر.
  Future<List<ProductModel>> fetchProductsForCustomerMenu({
    required String restaurantId,
    required String slug,
  }) {
    final docId = _docId(restaurantId: restaurantId, slug: slug);
    return PublicCatalogService.fetchMenuProducts(
      restaurantSlug: slug,
      restaurantDocId: docId,
    );
  }

  Stream<List<ProductModel>> watchProductsForRestaurant({
    required String restaurantId,
    required String slug,
  }) {
    return SupabaseProductService.watchProducts(
      restaurantId: _docId(restaurantId: restaurantId, slug: slug),
    );
  }

  /// منيو الزبون — polling عبر RPC (C-04).
  Stream<List<ProductModel>> watchProductsForCustomerMenu({
    required String restaurantId,
    required String slug,
  }) {
    final docId = _docId(restaurantId: restaurantId, slug: slug);
    return PublicCatalogService.watchMenuProducts(
      restaurantSlug: slug,
      restaurantDocId: docId,
    );
  }

  Future<List<String>> fetchDistinctCategories({
    required String restaurantId,
    required String slug,
  }) {
    return SupabaseProductService.fetchDistinctCategories(
      restaurantId: _docId(restaurantId: restaurantId, slug: slug),
    );
  }

  Future<ProductModel?> fetchProductById({
    required String restaurantId,
    required String slug,
    required String productId,
  }) {
    return SupabaseProductService.fetchProductById(
      productId,
      restaurantId: _docId(restaurantId: restaurantId, slug: slug),
    );
  }

  /// يرفع صورة المنتج إلى Supabase Storage ويعيد الرابط العام.
  Future<String> uploadProductImage({
    required String restaurantId,
    required String slug,
    required XFile pickedImageFile,
    required Uint8List pickedImageBytes,
    String? productId,
  }) {
    final docId = _docId(restaurantId: restaurantId, slug: slug);
    final targetId =
        (productId != null && productId.trim().isNotEmpty)
            ? productId.trim()
            : ProductIdGenerator.newId();

    return _imageUploadService.uploadProductImage(
      restaurantId: docId,
      productId: targetId,
      bytes: pickedImageBytes,
      fileName: pickedImageFile.name,
    );
  }

  /// يحفظ المنتج في جدول `products` مع [imageUrl] إن وُجد.
  Future<String> saveProduct({
    required String restaurantId,
    required String slug,
    required ProductModel product,
    String? imageUrl,
  }) {
    final docId = _docId(restaurantId: restaurantId, slug: slug);
    final payload = _productForSave(
      product: product,
      restaurantDocId: docId,
      imageUrl: imageUrl,
    );

    return SupabaseProductService.saveProduct(
      product: payload,
      imageUrl: imageUrl,
      tenantRestaurantId: docId,
    );
  }

  Future<void> deleteProduct({required String productId}) {
    return SupabaseProductService.deleteProduct(productId);
  }

  /// تنظيف صفوف product_variants المكررة — للاستخدام الإداري/debug فقط.
  Future<ProductVariantsCleanupReport> cleanupDuplicateProductVariants() {
    return SupabaseProductService.cleanupDuplicateVariantRows();
  }
}
