/// القيم الافتراضية لإعدادات التطبيق العامة.
abstract final class AppSettingsDefaults {
  AppSettingsDefaults._();

  static const String settingsId = 'global';

  static const bool maintenanceMode = false;

  static const String maintenanceTitle = 'نعتذر، النظام قيد التحديث';

  static const String maintenanceMessage =
      'نعتذر عن إيقاف الخدمة بشكل مؤقت. نعمل حالياً على تحسين النظام '
      'لضمان أفضل تجربة لكم. يمكنكم إتمام الطلبات مباشرة عبر الأرقام '
      'التالية لحين عودة الخدمة. شكراً لتفهمكم.';

  static const String phone1 = '07777790170';

  static const String phone2 = '07891099899';

  static const bool dailySoundEnabled = false;

  static const String dailySoundUrl = '';

  static const String dailySoundTitle = '';

  /// مستوى الصوت الافتراضي (0.0–1.0) — 30%
  static const double dailySoundVolume = 0.3;

  static const bool dailySoundLoop = false;
}
