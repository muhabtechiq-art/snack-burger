import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business_day_model.dart';
import 'supabase_error_reporter.dart';

/// قراءة/بث `business_days` — الفتح/الإغلاق عبر RPC فقط.
abstract final class SupabaseBusinessDayService {
  SupabaseBusinessDayService._();

  static const String tableName = 'business_days';
  static const String alreadyOpenCode = 'business_day_already_open';
  static const String noOpenDayCode = 'no_open_business_day';

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<BusinessDayModel?> fetchOpenDay({
    required String restaurantId,
    required String slug,
  }) async {
    try {
      final row = await _client
          .from(tableName)
          .select()
          .eq('restaurant_id', restaurantId)
          .eq('status', BusinessDayStatus.open)
          .maybeSingle();

      if (row == null) return null;
      return BusinessDayModel.fromMap(Map<String, dynamic>.from(row));
    } catch (e, stack) {
      if (_isMissingTable(e)) {
        debugPrint(
          '[SupabaseBusinessDayService] table missing — run '
          'supabase/business_days_schema.sql',
        );
        return null;
      }
      reportSupabaseError(e, stack, operation: 'fetchOpenBusinessDay');
      rethrow;
    }
  }

  static Future<BusinessDayModel?> fetchById(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) return null;

    try {
      final row = await _client
          .from(tableName)
          .select()
          .eq('id', normalized)
          .maybeSingle();
      if (row == null) return null;
      return BusinessDayModel.fromMap(Map<String, dynamic>.from(row));
    } catch (e, stack) {
      reportSupabaseError(e, stack, operation: 'fetchBusinessDayById');
      rethrow;
    }
  }

  static Stream<BusinessDayModel?> watchOpenDay({
    required String restaurantId,
    required String slug,
  }) {
    return _client
        .from(tableName)
        .stream(primaryKey: const ['id'])
        .eq('restaurant_id', restaurantId)
        .map((rows) {
      for (final raw in rows) {
        final map = Map<String, dynamic>.from(raw);
        if (map['status']?.toString() == BusinessDayStatus.open) {
          return BusinessDayModel.fromMap(map);
        }
      }
      return null;
    });
  }

  static Future<BusinessDayModel> openDay({
    required String restaurantId,
    required String slug,
  }) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'open_business_day',
        params: <String, dynamic>{
          'p_restaurant_id': restaurantId,
          'p_slug': slug.trim(),
        },
      );
      final opened = BusinessDayModel.fromMap(row);
      debugPrint('[SupabaseBusinessDayService] RPC opened day ${opened.id}');
      return opened;
    } on PostgrestException catch (e, stack) {
      if (_isRpcError(e, alreadyOpenCode)) {
        throw StateError(alreadyOpenCode);
      }
      reportSupabaseError(e, stack, operation: 'openBusinessDay');
      rethrow;
    } catch (e, stack) {
      if (e is StateError) rethrow;
      reportSupabaseError(e, stack, operation: 'openBusinessDay');
      rethrow;
    }
  }

  static Future<BusinessDayModel> closeDay({
    required String restaurantId,
    String? notes,
  }) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'close_business_day',
        params: <String, dynamic>{
          'p_restaurant_id': restaurantId,
          if (notes != null && notes.trim().isNotEmpty) 'p_notes': notes.trim(),
        },
      );
      final closed = BusinessDayModel.fromMap(row);
      debugPrint(
        '[SupabaseBusinessDayService] RPC closed day ${closed.id} — '
        '${closed.closedOrderCount} orders, ${closed.closedTotalSales} sales',
      );
      return closed;
    } on PostgrestException catch (e, stack) {
      if (_isRpcError(e, noOpenDayCode)) {
        throw StateError(noOpenDayCode);
      }
      reportSupabaseError(e, stack, operation: 'closeBusinessDay');
      rethrow;
    } catch (e, stack) {
      if (e is StateError) rethrow;
      reportSupabaseError(e, stack, operation: 'closeBusinessDay');
      rethrow;
    }
  }

  static bool _isRpcError(PostgrestException error, String code) {
    final message = error.message.toLowerCase();
    return message.contains(code.toLowerCase()) || error.code == '23505';
  }

  static bool _isMissingTable(Object error) {
    if (error is! PostgrestException) return false;
    final message = error.message.toLowerCase();
    return error.code == 'PGRST205' ||
        error.code == '42P01' ||
        (message.contains('business_days') && message.contains('does not exist'));
  }
}
