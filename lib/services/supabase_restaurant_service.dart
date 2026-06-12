import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/restaurant_model.dart';
import 'supabase_error_reporter.dart';

/// قراءة بيانات المطاعم من جدول `restaurants` في Supabase.
abstract final class SupabaseRestaurantService {
  SupabaseRestaurantService._();

  static const String tableName = 'restaurants';

  static SupabaseClient get _client => Supabase.instance.client;

  /// يجلب مطعماً نشطاً بالـ slug — يُرجع null إن لم يُوجَد.
  static Future<RestaurantModel?> fetchBySlug(String slug) async {
    final normalized = slug.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    try {
      final row = await _client
          .from(tableName)
          .select()
          .eq('slug', normalized)
          .eq('is_active', true)
          .maybeSingle();

      if (row == null) {
        debugPrint(
          '[SupabaseRestaurantService] fetchBySlug($normalized): 0 سجل',
        );
        return null;
      }

      debugPrint(
        '[SupabaseRestaurantService] fetchBySlug($normalized): 1 سجل',
      );
      return RestaurantModel.fromMap(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e, stack) {
      debugPrint(
        '[SupabaseRestaurantService] fetchBySlug($normalized) فشل: '
        '${e.code} ${e.message}\n$stack',
      );
      reportSupabaseError(e, stack, operation: 'fetchBySlug');
      rethrow;
    } catch (e, stack) {
      debugPrint(
        '[SupabaseRestaurantService] fetchBySlug($normalized) خطأ: $e\n$stack',
      );
      reportSupabaseError(e, stack, operation: 'fetchBySlug');
      rethrow;
    }
  }
}
