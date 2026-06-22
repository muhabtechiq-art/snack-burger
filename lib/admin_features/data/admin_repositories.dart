import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/admin_profile_session.dart';
import '../../core/config/restaurant_ids.dart';
import '../../models/business_day_model.dart';
import '../../models/business_day_order_stats.dart';
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
    String? restaurantUuid,
    required Stream<List<DeliveryOrder>> Function({
      required String slug,
      String? restaurantUuid,
      ValueChanged<StreamHealth>? onHealthChanged,
    }) watch,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return watch(
      slug: _scopedSlug(restaurantId: restaurantId, slug: slug),
      restaurantUuid: restaurantUuid,
      onHealthChanged: onHealthChanged,
    );
  }

  Stream<List<DeliveryOrder>> watchPendingOrdersForBusinessDay({
    required String businessDayId,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return SupabaseOrderService.watchPendingOrdersForBusinessDay(
      businessDayId: businessDayId,
      onHealthChanged: onHealthChanged,
    );
  }

  Future<List<DeliveryOrder>> fetchPendingOrdersForBusinessDayCreatedAfter({
    required String businessDayId,
    required DateTime after,
  }) {
    return SupabaseOrderService.fetchPendingOrdersForBusinessDayCreatedAfter(
      businessDayId: businessDayId,
      after: after,
    );
  }

  Stream<List<DeliveryOrder>> watchKitchenDashboardOrdersForBusinessDay({
    required String businessDayId,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return SupabaseOrderService.watchKitchenDashboardOrdersForBusinessDay(
      businessDayId: businessDayId,
      onHealthChanged: onHealthChanged,
    );
  }

  Stream<List<DeliveryOrder>> watchPendingOrders({
    required String restaurantId,
    required String slug,
    String? restaurantUuid,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return _watchScopedOrderStream(
      restaurantId: restaurantId,
      slug: slug,
      restaurantUuid: restaurantUuid,
      onHealthChanged: onHealthChanged,
      watch: SupabaseOrderService.watchPendingOrders,
    );
  }

  Future<List<DeliveryOrder>> fetchPendingOrdersCreatedAfter({
    required String restaurantId,
    required String slug,
    required DateTime after,
    String? restaurantUuid,
  }) {
    return SupabaseOrderService.fetchPendingOrdersCreatedAfter(
      slug: _scopedSlug(restaurantId: restaurantId, slug: slug),
      after: after,
      restaurantUuid: restaurantUuid,
    );
  }

  Stream<List<DeliveryOrder>> watchActiveOrders({
    required String restaurantId,
    required String slug,
    String? restaurantUuid,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return _watchScopedOrderStream(
      restaurantId: restaurantId,
      slug: slug,
      restaurantUuid: restaurantUuid,
      onHealthChanged: onHealthChanged,
      watch: SupabaseOrderService.watchActiveOrders,
    );
  }

  Stream<List<DeliveryOrder>> watchKitchenDashboardOrders({
    required String restaurantId,
    required String slug,
    String? restaurantUuid,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return _watchScopedOrderStream(
      restaurantId: restaurantId,
      slug: slug,
      restaurantUuid: restaurantUuid,
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

  Stream<List<DeliveryOrder>> watchOrdersForBusinessDay({
    required String businessDayId,
    ValueChanged<StreamHealth>? onHealthChanged,
  }) {
    return SupabaseOrderService.watchOrdersForBusinessDay(
      businessDayId: businessDayId,
      onHealthChanged: onHealthChanged,
    );
  }

  Future<BusinessDayOrderStats> fetchBusinessDayOrderStats({
    required String businessDayId,
    BusinessDayModel? businessDay,
  }) {
    return SupabaseOrderService.fetchBusinessDayOrderStats(
      businessDayId: businessDayId,
      businessDay: businessDay,
    );
  }

  Future<EndOfDayReport> fetchClosingReport({
    required String restaurantId,
    required String slug,
    required String businessDayId,
    BusinessDayModel? businessDay,
  }) {
    return SupabaseOrderService.fetchClosingReport(
      businessDayId: businessDayId,
      businessDay: businessDay,
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