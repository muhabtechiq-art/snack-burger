import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/admin_profile_session.dart';
import '../../core/config/restaurant_ids.dart';
import '../../models/delivery_order_model.dart';
import '../../models/end_of_day_report_model.dart';
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

  String _scopedSlug({
    required String restaurantId,
    required String slug,
  }) {
    return resolveRestaurantId(restaurantId: restaurantId, slug: slug);
  }

  Stream<List<DeliveryOrder>> _watchScopedOrderStream({
    required String restaurantId,
    required String slug,
    required Stream<List<DeliveryOrder>> Function({
      required String slug,
      ValueChanged<StreamHealth>? onHealthChanged,
    }) watch,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return watch(
      slug: _scopedSlug(restaurantId: restaurantId, slug: slug),
      onHealthChanged: onHealthChanged,
    );
  }

  Stream<List<DeliveryOrder>> watchPendingOrders({
    required String restaurantId,
    required String slug,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return _watchScopedOrderStream(
      restaurantId: restaurantId,
      slug: slug,
      onHealthChanged: onHealthChanged,
      watch: SupabaseOrderService.watchPendingOrders,
    );
  }

  Stream<List<DeliveryOrder>> watchActiveOrders({
    required String restaurantId,
    required String slug,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return _watchScopedOrderStream(
      restaurantId: restaurantId,
      slug: slug,
      onHealthChanged: onHealthChanged,
      watch: SupabaseOrderService.watchActiveOrders,
    );
  }

  Stream<List<DeliveryOrder>> watchKitchenDashboardOrders({
    required String restaurantId,
    required String slug,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return _watchScopedOrderStream(
      restaurantId: restaurantId,
      slug: slug,
      onHealthChanged: onHealthChanged,
      watch: SupabaseOrderService.watchKitchenDashboardOrders,
    );
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

  Future<void> updateRejectionReason({
    required String orderId,
    required String reason,
  }) {
    return SupabaseOrderService.updateRejectionReason(
      orderId: orderId,
      reason: reason,
    );
  }

  Future<EndOfDayReport> fetchTodayClosingReport({
    required String restaurantId,
    required String slug,
    DateTime? day,
  }) {
    return SupabaseOrderService.fetchTodayClosingReport(
      slug: _scopedSlug(restaurantId: restaurantId, slug: slug),
      day: day,
    );
  }
}

/// مستودع منتجات إداري — CRUD مع نطاق [restaurantId].
class AdminProductRepository {
  AdminProductRepository({ProductRepository? productRepository})
      : _productRepository = productRepository ?? ProductRepository();

  final ProductRepository _productRepository;

  T _delegateScoped<T>({
    required String restaurantId,
    required String slug,
    required T Function({
      required String restaurantId,
      required String slug,
    }) delegate,
  }) {
    return delegate(restaurantId: restaurantId, slug: slug);
  }

  Future<List<ProductModel>> fetchProducts({
    required String restaurantId,
    required String slug,
  }) {
    return _delegateScoped(
      restaurantId: restaurantId,
      slug: slug,
      delegate: _productRepository.fetchProductsForRestaurant,
    );
  }

  Stream<List<ProductModel>> watchProducts({
    required String restaurantId,
    required String slug,
  }) {
    return _delegateScoped(
      restaurantId: restaurantId,
      slug: slug,
      delegate: _productRepository.watchProductsForRestaurant,
    );
  }

  Future<List<String>> fetchDistinctCategories({
    required String restaurantId,
    required String slug,
  }) {
    return _delegateScoped(
      restaurantId: restaurantId,
      slug: slug,
      delegate: _productRepository.fetchDistinctCategories,
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