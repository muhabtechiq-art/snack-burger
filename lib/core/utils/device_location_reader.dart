import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'location_position_validator.dart';

/// جلب موقع حالي من نظام التشغيل — GPS جديد أولاً، ثم lastKnown بدقة عالية جداً فقط.
abstract final class DeviceLocationReader {
  DeviceLocationReader._();

  /// يطلب قراءة GPS جديدة؛ إن فشلت يُجرّب `getLastKnownPosition` بدقة ≤ 15م فقط.
  static Future<Position?> getCurrentLocation() async {
    if (!await _ensureReady()) return null;

    final fresh = await _readFreshPosition();
    if (fresh != null) return fresh;

    return _readLastKnownIfPrecise();
  }

  static Future<Position?> _readFreshPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _freshLocationSettings(),
      );

      if (!LocationPositionValidator.isPreviewReading(position)) {
        _log(
          'getCurrentPosition rejected: '
          'latitude=${position.latitude}, '
          'longitude=${position.longitude}, '
          'accuracy=${position.accuracy}, '
          'source=getCurrentPosition',
        );
        return null;
      }

      _logReading(source: 'getCurrentPosition', position: position);
      return position;
    } catch (e, stack) {
      _log('getCurrentPosition failed: $e\n$stack');
      return null;
    }
  }

  static Future<Position?> _readLastKnownIfPrecise() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        _log('lastKnownPosition unavailable');
        return null;
      }

      if (!LocationPositionValidator.isLastKnownFallback(position)) {
        _log(
          'lastKnownPosition rejected: '
          'latitude=${position.latitude}, '
          'longitude=${position.longitude}, '
          'accuracy=${position.accuracy}, '
          'source=lastKnownPosition',
        );
        return null;
      }

      _logReading(source: 'lastKnownPosition', position: position);
      return position;
    } catch (e, stack) {
      _log('lastKnownPosition failed: $e\n$stack');
      return null;
    }
  }

  static Future<bool> _ensureReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log('GPS service disabled');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _log('location permission denied: $permission');
      return false;
    }

    return true;
  }

  static LocationSettings _freshLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: false,
        intervalDuration: const Duration(milliseconds: 500),
        timeLimit: const Duration(seconds: 30),
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        timeLimit: const Duration(seconds: 30),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      timeLimit: Duration(seconds: 30),
    );
  }

  static void _logReading({
    required String source,
    required Position position,
  }) {
    _log(
      'latitude=${position.latitude}, '
      'longitude=${position.longitude}, '
      'accuracy=${position.accuracy}, '
      'source=$source',
    );
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[DeviceLocationReader] $message');
    }
  }
}
