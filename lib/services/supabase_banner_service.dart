import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/promo_banner_model.dart';

/// CRUD لجدول `banners` في Supabase.
abstract final class SupabaseBannerService {
  SupabaseBannerService._();

  static const String tableName = 'banners';
  static const String defaultRestaurantId = 'snack_burger';

  static SupabaseClient get _client => Supabase.instance.client;

  static List<PromoBannerModel> _parseRows(List<dynamic> rows) {
    final banners = <PromoBannerModel>[];
    for (final row in rows) {
      try {
        banners.add(
          PromoBannerModel.fromSupabase(Map<String, dynamic>.from(row)),
        );
      } catch (e, st) {
        debugPrint('[SupabaseBannerService] تخطي صف بانر: $e\n$st');
      }
    }
    banners.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return b.createdAt.compareTo(a.createdAt);
    });
    return banners;
  }

  static Future<List<PromoBannerModel>> fetchActiveBanners({
    required String restaurantId,
  }) async {
    final normalized = restaurantId.trim().toLowerCase();
    try {
      final rows = await _client
          .from(tableName)
          .select()
          .eq('restaurant_id', normalized)
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false);

      final banners = _parseRows(rows as List);
      debugPrint(
        '[SupabaseBannerService] fetchActiveBanners($normalized): '
        '${banners.length} بانر',
      );
      return banners;
    } catch (e, stack) {
      debugPrint('[SupabaseBannerService] fetchActiveBanners فشل: $e\n$stack');
      rethrow;
    }
  }

  static List<PromoBannerModel> _filterActiveForRestaurant(
    List<dynamic> rows,
    String restaurantId,
  ) {
    final normalized = restaurantId.trim().toLowerCase();
    return _parseRows(rows)
        .where(
          (banner) =>
              banner.restaurantId.trim().toLowerCase() == normalized &&
              banner.isActive,
        )
        .toList(growable: false);
  }

  /// بث التحديثات — فلترة محلية (مثل المنتجات) لأن Realtime قد لا يكون
  /// مفعّلاً على جدول banners أو لا يُرسل اللقطة الأولى فور الاشتراك.
  static Stream<List<PromoBannerModel>> watchActiveBanners({
    required String restaurantId,
  }) {
    final normalized = restaurantId.trim().toLowerCase();
    return _client
        .from(tableName)
        .stream(primaryKey: const ['id'])
        .map((rows) => _filterActiveForRestaurant(rows, normalized));
  }

  static Stream<List<PromoBannerModel>> watchAllBanners({
    required String restaurantId,
  }) {
    final normalized = restaurantId.trim().toLowerCase();
    return _client.from(tableName).stream(primaryKey: const ['id']).map((rows) {
      return _parseRows(rows)
          .where(
            (banner) => banner.restaurantId.trim().toLowerCase() == normalized,
          )
          .toList(growable: false);
    });
  }

  static Future<PromoBannerModel> insertBanner(PromoBannerModel banner) async {
    final row = await _client
        .from(tableName)
        .insert(banner.toInsertMap())
        .select()
        .single();

    return PromoBannerModel.fromSupabase(Map<String, dynamic>.from(row));
  }

  static Future<void> updateBanner(PromoBannerModel banner) async {
    await _client
        .from(tableName)
        .update(banner.toUpdateMap())
        .eq('id', banner.id);
  }

  static Future<List<PromoBannerModel>> fetchAllBanners({
    required String restaurantId,
  }) async {
    final normalized = restaurantId.trim().toLowerCase();
    final rows = await _client
        .from(tableName)
        .select()
        .eq('restaurant_id', normalized)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);

    return _parseRows(rows as List);
  }

  static bool _readIsActive(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return false;
  }

  static Future<void> setBannerActive({
    required String bannerId,
    required bool isActive,
  }) async {
    final normalizedId = bannerId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('معرّف البانر فارغ');
    }

    try {
      final rows = await _client
          .from(tableName)
          .update({'is_active': isActive})
          .eq('id', normalizedId)
          .select('id, is_active');

      final updated = List<Map<String, dynamic>>.from(rows as List);
      if (updated.isEmpty) {
        throw StateError(
          'لم يُحدَّث أي صف — نفّذ banners_rls_fix.sql في Supabase (سياسات UPDATE)',
        );
      }

      final saved = _readIsActive(updated.first['is_active']);
      if (saved != isActive) {
        throw StateError('لم تُحفظ الحالة المطلوبة في عمود is_active');
      }

      debugPrint(
        '[SupabaseBannerService] setBannerActive id=$normalizedId '
        'is_active=$isActive — تم الحفظ (${updated.length} صف)',
      );
    } on PostgrestException catch (e, stack) {
      debugPrint(
        '[SupabaseBannerService] setBannerActive فشل: '
        'code=${e.code} message=${e.message}\n$stack',
      );
      rethrow;
    }
  }

  static Future<void> deleteBanner({required String bannerId}) async {
    await _client.from(tableName).delete().eq('id', bannerId);
  }
}
