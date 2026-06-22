import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/network/network_timeout.dart';
import '../models/product_model.dart';
import '../models/promo_banner_model.dart';
import 'supabase_error_reporter.dart';
import 'supabase_product_service.dart';

/// قراءة منيو الزبون عبر RPC (C-04) — بدون SELECT مباشر على جداول الكتالوج.
abstract final class PublicCatalogService {
  PublicCatalogService._();

  static const String productsRpc = 'get_public_products';
  static const String addonsRpc = 'get_public_product_addons';
  static const String variantsRpc = 'get_public_product_variants';
  static const String bannersRpc = 'get_public_banners';

  /// فترة إعادة جلب المنيو عند strict mode (بديل Realtime للزبون).
  static const Duration menuPollInterval = Duration(seconds: 20);

  static SupabaseClient get _client => Supabase.instance.client;

  static String _normalizeSlug(String slug) => slug.trim().toLowerCase();

  static List<Map<String, dynamic>> _rpcRows(dynamic raw) {
    if (raw is List) {
      return raw
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    }
    if (raw is Map) {
      return [Map<String, dynamic>.from(raw)];
    }
    return const [];
  }

  static Future<List<ProductModel>> fetchMenuProducts({
    required String restaurantSlug,
    required String restaurantDocId,
  }) async {
    final slug = _normalizeSlug(restaurantSlug);
    if (slug.isEmpty) {
      throw ArgumentError('restaurantSlug required for public catalog RPC');
    }

    try {
      return await NetworkTimeouts.run(() async {
        debugPrint(
          '[PublicCatalogService] fetchMenuProducts slug=$slug '
          'docId=$restaurantDocId',
        );

        final results = await Future.wait<dynamic>([
          _client.rpc<dynamic>(productsRpc, params: {'p_restaurant_slug': slug}),
          _client.rpc<dynamic>(addonsRpc, params: {'p_restaurant_slug': slug}),
          _client.rpc<dynamic>(
            variantsRpc,
            params: {'p_restaurant_slug': slug},
          ),
        ]);

        final products = SupabaseProductService.assemblePublicMenuProducts(
          restaurantDocId: restaurantDocId,
          productRows: _rpcRows(results[0]),
          addonRows: _rpcRows(results[1]),
          variantRows: _rpcRows(results[2]),
        );

        debugPrint(
          '[PublicCatalogService] fetchMenuProducts → ${products.length} منتج',
        );
        return products;
      });
    } catch (e, stack) {
      debugPrint('[PublicCatalogService] fetchMenuProducts فشل: $e\n$stack');
      reportSupabaseError(e, stack, operation: 'fetchMenuProducts');
      rethrow;
    }
  }

  static Stream<List<ProductModel>> watchMenuProducts({
    required String restaurantSlug,
    required String restaurantDocId,
    Duration pollInterval = menuPollInterval,
  }) {
    final slug = _normalizeSlug(restaurantSlug);
    return _pollingStream(
      streamTag: 'watchMenuProducts(slug=$slug)',
      pollInterval: pollInterval,
      fetch: () => fetchMenuProducts(
        restaurantSlug: slug,
        restaurantDocId: restaurantDocId,
      ),
    );
  }

  static Future<List<PromoBannerModel>> fetchActiveBanners({
    required String restaurantSlug,
    required String restaurantDocId,
  }) async {
    final slug = _normalizeSlug(restaurantSlug);
    if (slug.isEmpty) {
      throw ArgumentError('restaurantSlug required for public catalog RPC');
    }

    try {
      return await NetworkTimeouts.run(() async {
        debugPrint('[PublicCatalogService] fetchActiveBanners slug=$slug');

        final raw = await _client.rpc<dynamic>(
          bannersRpc,
          params: {'p_restaurant_slug': slug},
        );

        final banners = _parseBannerRows(_rpcRows(raw), restaurantDocId);
        debugPrint(
          '[PublicCatalogService] fetchActiveBanners → ${banners.length} بانر',
        );
        return banners;
      });
    } catch (e, stack) {
      debugPrint('[PublicCatalogService] fetchActiveBanners فشل: $e\n$stack');
      reportSupabaseError(e, stack, operation: 'fetchPublicActiveBanners');
      rethrow;
    }
  }

  static Stream<List<PromoBannerModel>> watchActiveBanners({
    required String restaurantSlug,
    required String restaurantDocId,
    Duration pollInterval = menuPollInterval,
  }) {
    final slug = _normalizeSlug(restaurantSlug);
    return _pollingStream(
      streamTag: 'watchActiveBanners(slug=$slug)',
      pollInterval: pollInterval,
      fetch: () => fetchActiveBanners(
        restaurantSlug: slug,
        restaurantDocId: restaurantDocId,
      ),
    );
  }

  @visibleForTesting
  static List<PromoBannerModel> parsePublicBannerRows(
    List<Map<String, dynamic>> rows,
    String restaurantDocId,
  ) {
    return _parseBannerRows(rows, restaurantDocId);
  }

  static List<PromoBannerModel> _parseBannerRows(
    List<Map<String, dynamic>> rows,
    String restaurantDocId,
  ) {
    final banners = <PromoBannerModel>[];
    for (final row in rows) {
      try {
        final banner = PromoBannerModel.fromSupabase(row);
        if (!banner.isActive) continue;
        banners.add(banner);
      } catch (e, stack) {
        debugPrint(
          '[PublicCatalogService] تخطي صف بانر: $e\n$stack',
        );
      }
    }
    banners.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return b.createdAt.compareTo(a.createdAt);
    });
    return banners;
  }

  static Stream<T> _pollingStream<T>({
    required String streamTag,
    required Future<T> Function() fetch,
    required Duration pollInterval,
  }) {
    return Stream<T>.multi((controller) {
      Timer? timer;
      bool closed = false;
      bool inFlight = false;

      Future<void> emit({required bool isPoll}) async {
        if (closed || inFlight) return;
        inFlight = true;
        try {
          controller.add(await fetch());
        } catch (e, stack) {
          debugPrint('[PublicCatalogService] $streamTag ${isPoll ? 'poll' : 'initial'} error: $e\n$stack');
          controller.addError(e, stack);
        } finally {
          inFlight = false;
        }
      }

      unawaited(emit(isPoll: false));
      timer = Timer.periodic(pollInterval, (_) {
        unawaited(emit(isPoll: true));
      });

      controller.onCancel = () async {
        closed = true;
        timer?.cancel();
      };
    });
  }

  /// تسمية RPC للاختبار والسجلات.
  @visibleForTesting
  static String publicCatalogRpcLabel(String slug) =>
      'get_public_*(p_restaurant_slug=${_normalizeSlug(slug)})';
}
