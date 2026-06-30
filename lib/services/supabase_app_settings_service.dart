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

  /// جلب الإعدادات — صف المطعم [restaurantId] أولاً ثم fallback إلى [globalId]
  /// ثم الافتراضيات. يبقى متوافقاً رجعياً: `fetch()` بلا وسيط = المسار العالمي.
  static Future<AppSettingsModel> fetch({String? restaurantId}) async {
    try {
      final scopedId = restaurantId?.trim() ?? '';

      if (scopedId.isNotEmpty) {
        final scopedRow = await _client
            .from(tableName)
            .select()
            .eq('id', scopedId)
            .maybeSingle();

        if (scopedRow != null) {
          final scopedSettings = AppSettingsModel.fromMap(
            Map<String, dynamic>.from(scopedRow),
          );
          if (kDebugMode) {
            debugPrint(
              '[SupabaseAppSettingsService] fetch id=$scopedId '
              'maintenanceMode=${scopedSettings.maintenanceMode}',
            );
          }
          return scopedSettings;
        }

        if (kDebugMode) {
          debugPrint(
            '[SupabaseAppSettingsService] fetch id=$scopedId not found — '
            'falling back to $globalId',
          );
        }
      }

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

      final settings = AppSettingsModel.fromMap(Map<String, dynamic>.from(row));
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
  /// يكتب صف [restaurantId] عند توفّره، وإلا الصف العالمي [globalId].
  static Future<AppSettingsModel> save(
    AppSettingsModel settings, {
    String? restaurantId,
  }) async {
    return savePatch(settings.toUpdateMap(), restaurantId: restaurantId);
  }

  /// تحديث جزئي — يرسل [partialUpdate] فقط دون مسح حقول شاشات أخرى.
  static Future<AppSettingsModel> savePatch(
    Map<String, dynamic> partialUpdate, {
    String? restaurantId,
  }) async {
    if (partialUpdate.isEmpty) {
      return fetch(restaurantId: restaurantId);
    }

    final scopedId = restaurantId?.trim() ?? '';
    final writeId = scopedId.isEmpty ? globalId : scopedId;
    final payload = <String, dynamic>{
      'id': writeId,
      ...partialUpdate,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final row = await _client
          .from(tableName)
          .upsert(payload, onConflict: 'id')
          .select()
          .single();

      final saved = AppSettingsModel.fromMap(Map<String, dynamic>.from(row));
      debugPrint(
        '[SupabaseAppSettingsService] savePatch id=$writeId '
        'keys=${partialUpdate.keys.join(',')} '
        'maintenanceMode=${saved.maintenanceMode} '
        'dailySoundEnabled=${saved.dailySoundEnabled}',
      );
      return saved;
    } on PostgrestException catch (e, stack) {
      debugPrint('[SupabaseAppSettingsService] savePatch failed: ${e.message}');
      reportSupabaseError(e, stack, operation: 'saveAppSettingsPatch');
      rethrow;
    }
  }

  /// بث إعدادات مطعم محدد عبر [restaurantId]، أو الصف العالمي عند غيابه.
  /// لا يمسّ بث الطلبات أو المنتجات.
  static Stream<AppSettingsModel> watchSettings({String? restaurantId}) {
    final scopedId = restaurantId?.trim() ?? '';
    final watchId = scopedId.isEmpty ? globalId : scopedId;
    return _client
        .from(tableName)
        .stream(primaryKey: const ['id'])
        .eq('id', watchId)
        .map((rows) {
          if (rows.isEmpty) return AppSettingsModel.defaults();
          return AppSettingsModel.fromMap(
            Map<String, dynamic>.from(rows.first),
          );
        });
  }

  /// بث خفيف لصف الإعدادات العالمي — متوافق رجعياً عبر [watchSettings].
  static Stream<AppSettingsModel> watchGlobalSettings() {
    return watchSettings();
  }

  static bool _isMissingTable(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == 'PGRST205' ||
        error.code == '42P01' ||
        message.contains('app_settings') && message.contains('does not exist');
  }
}
