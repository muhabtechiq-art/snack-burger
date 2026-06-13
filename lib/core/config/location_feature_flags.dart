/// إعدادات ميزة تحديد موقع التوصيل.
abstract final class LocationFeatureFlags {
  LocationFeatureFlags._();

  static const bool enabled = true;

  /// دقة مقبولة للقفل التلقائي (أمتار).
  static const double maxAcceptableAccuracyMeters = 15;

  /// فوق هذا الحد = إشارة ضعيفة / برج اتصال — لا يُستخدم كقفل GPS.
  static const double maxRejectAccuracyMeters = 80;

  /// حد أقصى لعرض قراءة GPS على الخريطة — فوقه = كاش/ضعيف ويُرفض.
  static const double maxPreviewAccuracyMeters = 30;

  /// أقصى عمر مقبول لقراءة GPS (تجاهل الكاش القديم).
  static const Duration maxReadingAge = Duration(seconds: 15);

  /// مدة انتظار تحسّن إشارة GPS قبل التثبيت اليدوي.
  static const Duration acquisitionDuration = Duration(seconds: 10);

  static const String maintenanceMessage =
      'خدمة تحديد الموقع غير متاحة حالياً';

  static const String gpsDisabledMessage =
      'خدمة الموقع (GPS) مغلقة — فعّلها من إعدادات الهاتف ثم أعد المحاولة';

  static const String weakSignalMessage =
      'دقة الموقع ضعيفة، اقترب من مكان مفتوح أو فعّل GPS';

  static const String locationFailedMessage =
      'تعذّر تحديد الموقع — فعّل GPS أو حدّد موقعك يدوياً على الخريطة';

  static const String locationRequiredMessage =
      'يرجى تحديد موقع التوصيل';

  /// إذا تجاوز الفرق عن الموقع المحفوظ هذا الحد — نسأل الزبون.
  static const double savedLocationDiffThresholdMeters = 100;
}
