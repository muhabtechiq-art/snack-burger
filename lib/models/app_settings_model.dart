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
    this.updatedAt,
  });

  final String id;
  final bool maintenanceMode;
  final String maintenanceTitle;
  final String maintenanceMessage;
  final String phone1;
  final String phone2;
  final DateTime? updatedAt;

  factory AppSettingsModel.defaults() {
    return const AppSettingsModel(
      id: AppSettingsDefaults.settingsId,
      maintenanceMode: AppSettingsDefaults.maintenanceMode,
      maintenanceTitle: AppSettingsDefaults.maintenanceTitle,
      maintenanceMessage: AppSettingsDefaults.maintenanceMessage,
      phone1: AppSettingsDefaults.phone1,
      phone2: AppSettingsDefaults.phone2,
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
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  AppSettingsModel copyWith({
    bool? maintenanceMode,
    String? maintenanceTitle,
    String? maintenanceMessage,
    String? phone1,
    String? phone2,
  }) {
    return AppSettingsModel(
      id: id,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceTitle: maintenanceTitle ?? this.maintenanceTitle,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      phone1: phone1 ?? this.phone1,
      phone2: phone2 ?? this.phone2,
      updatedAt: updatedAt,
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
