import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'location_position_validator.dart';

/// جلب موقع حالي من نظام التشغيل — بدون `getLastKnownPosition` (لا كاش قديم).
abstract final class DeviceLocationReader {
  DeviceLocationReader._();

  /// `LocationAccuracy.best` + طباعة في وضع التطوير/المحاكي.
  static Future<Position?> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log('GPS service disabled');
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _log('location permission denied: $permission');
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _freshLocationSettings(),
      );

      _logPosition('getCurrentPosition', position);

      if (!LocationPositionValidator.isPreviewReading(position)) {
        _log(
          'reading rejected for preview '
          '(mocked=${position.isMocked}, accuracy=${position.accuracy}m)',
        );
        return null;
      }

      return position;
    } catch (e, stack) {
      _log('getCurrentPosition failed: $e\n$stack');
      return null;
    }
  }

  static LocationSettings _freshLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        forceLocationManager: true,
        intervalDuration: const Duration(milliseconds: 300),
        timeLimit: const Duration(seconds: 25),
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.other,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        timeLimit: const Duration(seconds: 25),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
      timeLimit: Duration(seconds: 25),
    );
  }

  static void _logPosition(String source, Position position) {
    _log(
      '$source ← OS: '
      'lat=${position.latitude.toStringAsFixed(6)}, '
      'lng=${position.longitude.toStringAsFixed(6)}, '
      'accuracy=${position.accuracy.toStringAsFixed(1)}m, '
      'mocked=${position.isMocked}, '
      'ts=${position.timestamp.toIso8601String()}',
    );
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[DeviceLocationReader] $message');
    }
  }
}
