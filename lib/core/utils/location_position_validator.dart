import 'package:geolocator/geolocator.dart';

import '../config/location_feature_flags.dart';

/// تحقق من جودة قراءة GPS قبل حفظها أو قفلها.
abstract final class LocationPositionValidator {
  LocationPositionValidator._();

  static bool isFreshReading(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    if (age.isNegative) return true;
    return age <= LocationFeatureFlags.maxReadingAge;
  }

  static bool isUsableReading(Position position) {
    if (position.isMocked) return false;
    if (!isFreshReading(position)) return false;
    if (position.accuracy > LocationFeatureFlags.maxRejectAccuracyMeters) {
      return false;
    }
    return true;
  }

  /// للمعاينة على الخريطة — قراءة حديثة بدقة ≤ 30م فقط.
  static bool isPreviewReading(Position position) {
    if (position.isMocked) return false;
    if (!isFreshReading(position)) return false;
    return position.accuracy <= LocationFeatureFlags.maxPreviewAccuracyMeters;
  }

  static bool isLockInQuality(Position position) {
    if (!isUsableReading(position)) return false;
    return position.accuracy <= LocationFeatureFlags.maxAcceptableAccuracyMeters;
  }

  /// fallback لـ `getLastKnownPosition` — دقة عالية جداً فقط (بدون شرط العمر).
  static bool isLastKnownFallback(Position position) {
    if (position.isMocked) return false;
    return position.accuracy <= LocationFeatureFlags.maxAcceptableAccuracyMeters;
  }

  static bool isAcceptableAccuracy(double? accuracyMeters, {required bool manualPin}) {
    if (manualPin) return true;
    if (accuracyMeters == null) return false;
    return accuracyMeters <= LocationFeatureFlags.maxAcceptableAccuracyMeters;
  }
}
