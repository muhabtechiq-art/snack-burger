import '../../core/auth/admin_profile_session.dart';
import '../../core/config/restaurant_ids.dart';
import '../../models/delivery_order_model.dart';
import '../../models/end_of_day_report_model.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/product_model.dart';
import '../../services/product_repository.dart';
import '../../services/supabase_order_service.dart';

/// مستودع إداري — كل الاستعلامات مربوطة بـ [restaurantId].
class AdminOrderRepository {
  AdminOrderRepository();

  String resolveRestaurantId({
    required String restaurantId,
    required String slug,
  }) {
    final sessionRestaurantId = AdminProfileSession.restaurantId?.trim();
    if (sessionRestaurantId != null && sessionRestaurantId.isNotEmpty) {
      return sessionRestaurantId.toLowerCase();
    }

    final uuid = RestaurantIds.snackBurgerUuid;
    if (uuid != null && uuid.trim().isNotEmpty) {
      return uuid.trim().toLowerCase();
    }
    final trimmed = restaurantId.trim();
    if (trimmed.isNotEmpty) return trimmed.toLowerCase();
    return slug.trim().toLowerCase();
  }

  Stream<List<DeliveryOrder>> watchPendingOrders({
    required String restaurantId,
    required String slug,
  }) {
    final scopedId = resolveRestaurantId(
      restaurantId: restaurantId,
      slug: slug,
    );
    return SupabaseOrderService.watchPendingOrders(slug: scopedId);
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) {
    return SupabaseOrderService.updateOrderStatus(
      orderId: orderId,
      status: status,
    );
  }

  Future<EndOfDayReport> fetchTodayClosingReport({
    required String restaurantId,
    required String slug,
    DateTime? day,
  }) {
    final scopedId = resolveRestaurantId(
      restaurantId: restaurantId,
      slug: slug,
    );
    return SupabaseOrderService.fetchTodayClosingReport(
      slug: scopedId,
      day: day,
    );
  }
}

/// مستودع منتجات إداري — CRUD مع نطاق [restaurantId].
class AdminProductRepository {
  AdminProductRepository({ProductRepository? productRepository})
      : _productRepository = productRepository ?? ProductRepository();

  final ProductRepository _productRepository;

  Stream<List<ProductModel>> watchProducts({
    required String restaurantId,
    required String slug,
  }) {
    return _productRepository.watchProductsForRestaurant(
      restaurantId: restaurantId,
      slug: slug,
    );
  }

  Future<List<String>> fetchDistinctCategories({
    required String restaurantId,
    required String slug,
  }) {
    return _productRepository.fetchDistinctCategories(
      restaurantId: restaurantId,
      slug: slug,
    );
  }

  Future<ProductModel?> fetchProductById({
    required String restaurantId,
    required String slug,
    required String productId,
  }) {
    return _productRepository.fetchProductById(
      restaurantId: restaurantId,
      slug: slug,
      productId: productId,
    );
  }

  Future<String> saveProduct({
    required String restaurantId,
    required String slug,
    required ProductModel product,
    String? imageUrl,
  }) {
    return _productRepository.saveProduct(
      restaurantId: restaurantId,
      slug: slug,
      product: product,
      imageUrl: imageUrl,
    );
  }

  Future<void> deleteProduct({required String productId}) {
    return _productRepository.deleteProduct(productId: productId);
  }

  Future<String> uploadProductImage({
    required String restaurantId,
    required String slug,
    required XFile pickedImageFile,
    required Uint8List pickedImageBytes,
    String? productId,
  }) {
    return _productRepository.uploadProductImage(
      restaurantId: restaurantId,
      slug: slug,
      pickedImageFile: pickedImageFile,
      pickedImageBytes: pickedImageBytes,
      productId: productId,
    );
  }
}
