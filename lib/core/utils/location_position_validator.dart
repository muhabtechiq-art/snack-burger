import 'package:geolocator/geolocator.dart';

import '../config/location_feature_flags.dart';

/// تحقق من جودة قراءة GPS قبل حفظها أو قفلها.
abstract final class LocationPositionValidator {
  LocationPositionValidator._();

  static bool isUsableReading(Position position) {
    if (position.isMocked) return false;
    if (position.accuracy > LocationFeatureFlags.maxRejectAccuracyMeters) {
      return false;
    }
    return true;
  }

  /// للمعاينة على الخريطة — أوسع من القفل (مهم للمحاكي).
  static bool isPreviewReading(Position position) {
    if (position.isMocked) return false;
    return position.accuracy <= LocationFeatureFlags.maxPreviewAccuracyMeters;
  }

  static bool isLockInQuality(Position position) {
    if (!isUsableReading(position)) return false;
    return position.accuracy <= LocationFeatureFlags.maxAcceptableAccuracyMeters;
  }

  static bool isAcceptableAccuracy(double? accuracyMeters, {required bool manualPin}) {
    if (manualPin) return true;
    if (accuracyMeters == null) return false;
    return accuracyMeters <= LocationFeatureFlags.maxAcceptableAccuracyMeters;
  }
}
