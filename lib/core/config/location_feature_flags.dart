/// إعدادات ميزة تحديد موقع التوصيل.
abstract final class LocationFeatureFlags {
  LocationFeatureFlags._();

  static const bool enabled = true;

  /// دقة مقبولة للقفل التلقائي (أمتار).
  static const double maxAcceptableAccuracyMeters = 15;

  /// فوق هذا الحد = إشارة ضعيفة / برج اتصال — لا يُستخدم كقفل GPS.
  static const double maxRejectAccuracyMeters = 80;

  /// حد أقصى لتحريك الدبوس أثناء التحديث (المحاكي غالباً > 80م).
  static const double maxPreviewAccuracyMeters = 500;

  /// مدة تثبيت GPS في الخلفية.
  static const Duration acquisitionDuration = Duration(seconds: 4);

  static const String maintenanceMessage =
      'خدمة تحديد الموقع غير متاحة حالياً';

  static const String gpsDisabledMessage =
      'خدمة الموقع (GPS) مغلقة — فعّلها من إعدادات الهاتف ثم أعد المحاولة';

  static const String weakSignalMessage =
      'إشارة GPS ضعيفة — انتقل لمكان مكشوف أو أعد المحاولة، '
      'أو اسحب الدبوس يدوياً على الخريطة';

  static const String locationRequiredMessage =
      'يجب تحديد موقع التوصيل قبل إرسال الطلب';
}
