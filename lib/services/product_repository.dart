import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/utils/product_id_generator.dart';
import '../models/product_model.dart';
import 'image_pick_upload_service.dart';
import 'supabase_product_service.dart';

/// واجهة مستودع المنتجات — تفوّض إلى Supabase.
class ProductRepository {
  ProductRepository({ImagePickUploadService? imageUploadService})
      : _imageUploadService = imageUploadService ?? ImagePickUploadService();

  final ImagePickUploadService _imageUploadService;

  static String resolveRestaurantDocId({
    required String restaurantId,
    required String slug,
  }) {
    for (final raw in [restaurantId, slug, SupabaseProductService.defaultRestaurantId]) {
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) return trimmed.toLowerCase();
    }
    return SupabaseProductService.defaultRestaurantId;
  }

  Stream<List<ProductModel>> watchProductsForRestaurant({
    required String restaurantId,
    required String slug,
  }) {
    final docId = resolveRestaurantDocId(restaurantId: restaurantId, slug: slug);
    return SupabaseProductService.watchProducts(restaurantId: docId);
  }

  Future<List<String>> fetchDistinctCategories({
    required String restaurantId,
    required String slug,
  }) {
    final docId = resolveRestaurantDocId(restaurantId: restaurantId, slug: slug);
    return SupabaseProductService.fetchDistinctCategories(restaurantId: docId);
  }

  Future<ProductModel?> fetchProductById({
    required String restaurantId,
    required String slug,
    required String productId,
  }) {
    return SupabaseProductService.fetchProductById(productId);
  }

  /// يرفع صورة المنتج إلى Supabase Storage ويعيد الرابط العام.
  Future<String> uploadProductImage({
    required String restaurantId,
    required String slug,
    required XFile pickedImageFile,
    required Uint8List pickedImageBytes,
    String? productId,
  }) {
    final docId = resolveRestaurantDocId(restaurantId: restaurantId, slug: slug);
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
  }) async {
    final docId = resolveRestaurantDocId(restaurantId: restaurantId, slug: slug);

    final payload = ProductModel(
      id: product.id,
      restaurantId: docId,
      name: product.name,
      description: product.description,
      price: product.price,
      category: product.category,
      addons: product.addons,
      imageUrl: imageUrl ?? product.imageUrl,
      isAvailable: product.isAvailable,
      createdAt: product.createdAt,
    );

    return SupabaseProductService.saveProduct(
      product: payload,
      imageUrl: imageUrl,
    );
  }

  Future<void> deleteProduct({required String productId}) {
    return SupabaseProductService.deleteProduct(productId);
  }
}
