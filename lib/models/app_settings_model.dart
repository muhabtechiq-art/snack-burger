import '../core/config/app_settings_defaults.dart';

/// إعدادات عامة للتطبيق — جدول `app_settings` في Supabase.
class AppSettingsModel {
  const AppSettingsModel({
    required this.id,
    required this.maintenanceMode,
    required this.maintenanceTitle,
    required this.maintenanceMessage,
    required this.phone1,
    required this.phone2,
    required this.dailySoundEnabled,
    required this.dailySoundUrl,
    required this.dailySoundTitle,
    required this.dailySoundVolume,
    required this.dailySoundLoop,
    this.updatedAt,
  });

  final String id;
  final bool maintenanceMode;
  final String maintenanceTitle;
  final String maintenanceMessage;
  final String phone1;
  final String phone2;
  final bool dailySoundEnabled;
  final String dailySoundUrl;
  final String dailySoundTitle;
  final double dailySoundVolume;
  final bool dailySoundLoop;
  final DateTime? updatedAt;

  /// صوت اليوم جاهز للعرض في واجهة الزبون.
  bool get hasDailySound =>
      dailySoundEnabled && dailySoundUrl.trim().isNotEmpty;

  factory AppSettingsModel.defaults() {
    return const AppSettingsModel(
      id: AppSettingsDefaults.settingsId,
      maintenanceMode: AppSettingsDefaults.maintenanceMode,
      maintenanceTitle: AppSettingsDefaults.maintenanceTitle,
      maintenanceMessage: AppSettingsDefaults.maintenanceMessage,
      phone1: AppSettingsDefaults.phone1,
      phone2: AppSettingsDefaults.phone2,
      dailySoundEnabled: AppSettingsDefaults.dailySoundEnabled,
      dailySoundUrl: AppSettingsDefaults.dailySoundUrl,
      dailySoundTitle: AppSettingsDefaults.dailySoundTitle,
      dailySoundVolume: AppSettingsDefaults.dailySoundVolume,
      dailySoundLoop: AppSettingsDefaults.dailySoundLoop,
    );
  }

  factory AppSettingsModel.fromMap(Map<String, dynamic> map) {
    return AppSettingsModel(
      id: _readString(map['id']).isEmpty
          ? AppSettingsDefaults.settingsId
          : _readString(map['id']),
      maintenanceMode: map['maintenance_mode'] == true ||
          map['maintenanceMode'] == true,
      maintenanceTitle: _readString(
        map['maintenance_title'] ?? map['maintenanceTitle'],
        fallback: AppSettingsDefaults.maintenanceTitle,
      ),
      maintenanceMessage: _readString(
        map['maintenance_message'] ?? map['maintenanceMessage'],
        fallback: AppSettingsDefaults.maintenanceMessage,
      ),
      phone1: _readString(
        map['phone_1'] ?? map['phone1'],
        fallback: AppSettingsDefaults.phone1,
      ),
      phone2: _readString(
        map['phone_2'] ?? map['phone2'],
        fallback: AppSettingsDefaults.phone2,
      ),
      dailySoundEnabled: map['daily_sound_enabled'] == true ||
          map['dailySoundEnabled'] == true,
      dailySoundUrl: _readString(
        map['daily_sound_url'] ?? map['dailySoundUrl'],
        fallback: AppSettingsDefaults.dailySoundUrl,
      ),
      dailySoundTitle: _readString(
        map['daily_sound_title'] ?? map['dailySoundTitle'],
        fallback: AppSettingsDefaults.dailySoundTitle,
      ),
      dailySoundVolume: _readVolume(
        map['daily_sound_volume'] ?? map['dailySoundVolume'],
        fallback: AppSettingsDefaults.dailySoundVolume,
      ),
      dailySoundLoop:
          map['daily_sound_loop'] == true || map['dailySoundLoop'] == true,
      updatedAt: _readDateTime(map['updated_at'] ?? map['updatedAt']),
    );
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'maintenance_mode': maintenanceMode,
      'maintenance_title': maintenanceTitle.trim(),
      'maintenance_message': maintenanceMessage.trim(),
      'phone_1': phone1.trim(),
      'phone_2': phone2.trim(),
      'daily_sound_enabled': dailySoundEnabled,
      'daily_sound_url': dailySoundUrl.trim().isEmpty ? null : dailySoundUrl.trim(),
      'daily_sound_title':
          dailySoundTitle.trim().isEmpty ? null : dailySoundTitle.trim(),
      'daily_sound_volume': dailySoundVolume.clamp(0.0, 1.0),
      'daily_sound_loop': dailySoundLoop,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  AppSettingsModel copyWith({
    bool? maintenanceMode,
    String? maintenanceTitle,
    String? maintenanceMessage,
    String? phone1,
    String? phone2,
    bool? dailySoundEnabled,
    String? dailySoundUrl,
    String? dailySoundTitle,
    double? dailySoundVolume,
    bool? dailySoundLoop,
  }) {
    return AppSettingsModel(
      id: id,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceTitle: maintenanceTitle ?? this.maintenanceTitle,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      phone1: phone1 ?? this.phone1,
      phone2: phone2 ?? this.phone2,
      dailySoundEnabled: dailySoundEnabled ?? this.dailySoundEnabled,
      dailySoundUrl: dailySoundUrl ?? this.dailySoundUrl,
      dailySoundTitle: dailySoundTitle ?? this.dailySoundTitle,
      dailySoundVolume: dailySoundVolume ?? this.dailySoundVolume,
      dailySoundLoop: dailySoundLoop ?? this.dailySoundLoop,
      updatedAt: updatedAt,
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static double _readVolume(dynamic value, {required double fallback}) {
    if (value == null) return fallback;
    if (value is num) {
      final parsed = value.toDouble();
      if (parsed.isNaN) return fallback;
      return parsed.clamp(0.0, 1.0);
    }
    final parsed = double.tryParse(value.toString());
    if (parsed == null || parsed.isNaN) return fallback;
    return parsed.clamp(0.0, 1.0);
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
