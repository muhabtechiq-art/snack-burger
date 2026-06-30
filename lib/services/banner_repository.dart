import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/promo_banner_model.dart';
import 'banner_image_upload_service.dart';
import 'product_repository.dart';
import 'public_catalog_service.dart';
import 'supabase_banner_service.dart';

/// مستودع البانرات — منفصل عن المنتجات.
class BannerRepository {
  BannerRepository({
    BannerImageUploadService? imageUploadService,
  }) : _imageUploadService = imageUploadService ?? BannerImageUploadService();

  final BannerImageUploadService _imageUploadService;
  static const _uuid = Uuid();

  String _docId({
    required String restaurantId,
    required String slug,
  }) {
    return ProductRepository.resolveRestaurantDocId(
      restaurantId: restaurantId,
      slug: slug,
    );
  }

  Future<List<PromoBannerModel>> fetchActiveBanners({
    required String restaurantId,
    required String slug,
  }) {
    return SupabaseBannerService.fetchActiveBanners(
      restaurantId: _docId(restaurantId: restaurantId, slug: slug),
    );
  }

  /// منيو الزبون — بانرات نشطة عبر RPC (C-04).
  Future<List<PromoBannerModel>> fetchActiveBannersForCustomerMenu({
    required String restaurantId,
    required String slug,
  }) {
    final docId = _docId(restaurantId: restaurantId, slug: slug);
    return PublicCatalogService.fetchActiveBanners(
      restaurantSlug: slug,
      restaurantDocId: docId,
    );
  }

  Stream<List<PromoBannerModel>> watchActiveBanners({
    required String restaurantId,
    required String slug,
  }) {
    return SupabaseBannerService.watchActiveBanners(
      restaurantId: _docId(restaurantId: restaurantId, slug: slug),
    );
  }

  /// منيو الزبون — polling بانرات عبر RPC (C-04).
  Stream<List<PromoBannerModel>> watchActiveBannersForCustomerMenu({
    required String restaurantId,
    required String slug,
  }) {
    final docId = _docId(restaurantId: restaurantId, slug: slug);
    return PublicCatalogService.watchActiveBanners(
      restaurantSlug: slug,
      restaurantDocId: docId,
    );
  }

  Stream<List<PromoBannerModel>> watchAllBanners({
    required String restaurantId,
    required String slug,
  }) {
    return SupabaseBannerService.watchAllBanners(
      restaurantId: _docId(restaurantId: restaurantId, slug: slug),
    );
  }

  Future<List<PromoBannerModel>> fetchAllBanners({
    required String restaurantId,
    required String slug,
  }) {
    return SupabaseBannerService.fetchAllBanners(
      restaurantId: _docId(restaurantId: restaurantId, slug: slug),
    );
  }

  Future<void> setBannerActive({
    required String bannerId,
    required bool isActive,
  }) {
    return SupabaseBannerService.setBannerActive(
      bannerId: bannerId,
      isActive: isActive,
    );
  }

  Future<void> deleteBanner({required String bannerId}) {
    return SupabaseBannerService.deleteBanner(bannerId: bannerId);
  }

  Future<PromoBannerModel> createBanner({
    required String restaurantId,
    required String slug,
    required String title,
    required XFile pickedImageFile,
    required Uint8List pickedImageBytes,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final docId = _docId(restaurantId: restaurantId, slug: slug);
    final bannerId = _uuid.v4();

    if (pickedImageBytes.isEmpty) {
      throw StateError('ملف البانر فارغ أو تالف');
    }

    final imageUrl = await _imageUploadService.uploadBannerImage(
      restaurantId: docId,
      bannerId: bannerId,
      bytes: pickedImageBytes,
    );

    final draft = PromoBannerModel(
      id: bannerId,
      restaurantId: docId,
      imageUrl: imageUrl,
      title: title,
      isActive: isActive,
      sortOrder: sortOrder,
      createdAt: DateTime.now().toUtc(),
    );

    return SupabaseBannerService.insertBanner(
      draft.copyWith(id: bannerId),
    );
  }

  Future<PromoBannerModel> updateBanner({
    required PromoBannerModel banner,
    required String title,
    required bool isActive,
    required int sortOrder,
    bool imageChanged = false,
    Uint8List? pickedImageBytes,
  }) async {
    var imageUrl = banner.imageUrl;

    if (imageChanged) {
      if (pickedImageBytes == null || pickedImageBytes.isEmpty) {
        throw StateError('صورة البانر الجديدة فارغة أو تالفة');
      }

      final uploadedUrl = await _imageUploadService.uploadBannerImage(
        restaurantId: banner.restaurantId,
        bannerId: banner.id,
        bytes: pickedImageBytes,
      );
      imageUrl = BannerImageUploadService.publicUrlWithCacheBust(uploadedUrl);
    }

    final updated = banner.copyWith(
      title: title,
      isActive: isActive,
      sortOrder: sortOrder,
      imageUrl: imageUrl,
    );

    final saved = await SupabaseBannerService.updateBanner(updated);

    if (imageChanged && saved.imageUrl.trim().isEmpty) {
      throw StateError('لم يُحفظ رابط الصورة الجديد في قاعدة البيانات');
    }

    return saved;
  }

  Future<void> updateBannerSortOrders(List<PromoBannerModel> ordered) {
    return SupabaseBannerService.updateBannerSortOrders(ordered);
  }
}
