import 'package:geolocator/geolocator.dart';

/// حساب المسافة بين نقطتين GPS (أمتار).
abstract final class GeoDistance {
  GeoDistance._();

  static double metersBetween({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) {
    return Geolocator.distanceBetween(
      fromLatitude,
      fromLongitude,
      toLatitude,
      toLongitude,
    );
  }
}
