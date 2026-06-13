import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/product_model.dart';
import '../../models/promo_banner_model.dart';

/// Cache محلي للمنيو — منتجات وبانرات حسب slug المطعم.
abstract final class MenuCatalogCache {
  MenuCatalogCache._();

  static String _productsKey(String slug) =>
      'menu_catalog_products_${slug.trim().toLowerCase()}';

  static String _bannersKey(String slug) =>
      'menu_catalog_banners_${slug.trim().toLowerCase()}';

  static Future<List<ProductModel>?> loadProducts(String slug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_productsKey(slug));
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;

      final products = <ProductModel>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        try {
          products.add(
            ProductModel.fromMap(Map<String, dynamic>.from(entry)),
          );
        } catch (error) {
          debugPrint('[MenuCatalogCache] skip product row: $error');
        }
      }
      return products.isEmpty ? null : products;
    } catch (error, stack) {
      debugPrint('[MenuCatalogCache] loadProducts failed: $error\n$stack');
      return null;
    }
  }

  static Future<void> saveProducts(
    String slug,
    List<ProductModel> products,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(products.map((p) => p.toMap()).toList());
      await prefs.setString(_productsKey(slug), payload);
    } catch (error, stack) {
      debugPrint('[MenuCatalogCache] saveProducts failed: $error\n$stack');
    }
  }

  static Future<List<PromoBannerModel>?> loadBanners(String slug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_bannersKey(slug));
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;

      final banners = <PromoBannerModel>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        try {
          banners.add(
            PromoBannerModel.fromSupabase(Map<String, dynamic>.from(entry)),
          );
        } catch (error) {
          debugPrint('[MenuCatalogCache] skip banner row: $error');
        }
      }
      return banners.isEmpty ? null : banners;
    } catch (error, stack) {
      debugPrint('[MenuCatalogCache] loadBanners failed: $error\n$stack');
      return null;
    }
  }

  static Future<void> saveBanners(
    String slug,
    List<PromoBannerModel> banners,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(
        banners.map((banner) => banner.toCacheMap()).toList(),
      );
      await prefs.setString(_bannersKey(slug), payload);
    } catch (error, stack) {
      debugPrint('[MenuCatalogCache] saveBanners failed: $error\n$stack');
    }
  }
}
