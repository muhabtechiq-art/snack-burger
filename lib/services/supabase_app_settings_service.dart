import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_settings_defaults.dart';
import '../models/app_settings_model.dart';
import 'supabase_error_reporter.dart';

/// قراءة وتحديث جدول `app_settings` في Supabase.
abstract final class SupabaseAppSettingsService {
  SupabaseAppSettingsService._();

  static const String tableName = 'app_settings';
  static const String globalId = AppSettingsDefaults.settingsId;

  static SupabaseClient get _client => Supabase.instance.client;

  /// جلب الإعدادات العامة — يُرجع الافتراضيات عند غياب الجدول أو الصف.
  static Future<AppSettingsModel> fetch() async {
    try {
      final row = await _client
          .from(tableName)
          .select()
          .eq('id', globalId)
          .maybeSingle();

      if (row == null) {
        debugPrint(
          '[SupabaseAppSettingsService] fetch: no row — using defaults',
        );
        return AppSettingsModel.defaults();
      }

      final settings =
          AppSettingsModel.fromMap(Map<String, dynamic>.from(row));
      if (kDebugMode) {
        debugPrint(
          '[SupabaseAppSettingsService] fetch maintenanceMode='
          '${settings.maintenanceMode}',
        );
      }
      return settings;
    } on PostgrestException catch (e, stack) {
      if (_isMissingTable(e)) {
        debugPrint(
          '[SupabaseAppSettingsService] table missing — defaults '
          '(run supabase/app_settings_schema.sql)',
        );
        return AppSettingsModel.defaults();
      }
      debugPrint('[SupabaseAppSettingsService] fetch failed: ${e.message}');
      reportSupabaseError(e, stack, operation: 'fetchAppSettings');
      rethrow;
    } catch (e, stack) {
      debugPrint('[SupabaseAppSettingsService] fetch error: $e\n$stack');
      reportSupabaseError(e, stack, operation: 'fetchAppSettings');
      rethrow;
    }
  }

  /// تحديث الإعدادات — يتطلب جلسة إدارة (authenticated).
  static Future<AppSettingsModel> save(AppSettingsModel settings) async {
    final payload = <String, dynamic>{
      'id': globalId,
      ...settings.toUpdateMap(),
    };

    try {
      final row = await _client
          .from(tableName)
          .upsert(payload, onConflict: 'id')
          .select()
          .single();

      final saved =
          AppSettingsModel.fromMap(Map<String, dynamic>.from(row));
      debugPrint(
        '[SupabaseAppSettingsService] saved maintenanceMode='
        '${saved.maintenanceMode}',
      );
      return saved;
    } on PostgrestException catch (e, stack) {
      debugPrint('[SupabaseAppSettingsService] save failed: ${e.message}');
      reportSupabaseError(e, stack, operation: 'saveAppSettings');
      rethrow;
    }
  }

  /// بث خفيف لصف الإعدادات الوحيد — لا يمس بث الطلبات أو المنتجات.
  static Stream<AppSettingsModel> watchGlobalSettings() {
    return _client
        .from(tableName)
        .stream(primaryKey: const ['id'])
        .eq('id', globalId)
        .map((rows) {
      if (rows.isEmpty) return AppSettingsModel.defaults();
      return AppSettingsModel.fromMap(
        Map<String, dynamic>.from(rows.first),
      );
    });
  }

  static bool _isMissingTable(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == 'PGRST205' ||
        error.code == '42P01' ||
        message.contains('app_settings') && message.contains('does not exist');
  }
}
