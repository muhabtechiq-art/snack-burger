import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/config/location_feature_flags.dart';
import '../core/utils/device_location_reader.dart';
import '../core/utils/location_position_validator.dart';

enum DeliveryLocationStatus {
  idle,
  loading,
  refining,
  granted,
  denied,
  gpsDisabled,
  weakSignal,
  error,
}

enum DeliveryLocationSource { none, saved, gps }

/// نتيجة جلسة GPS — تلميح أولي؛ التثبيت النهائي من الدبوس أو قفل دقة ≤ 15م.
class LocationAcquisitionSnapshot {
  const LocationAcquisitionSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.reachedTargetAccuracy,
    required this.timedOut,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final bool reachedTargetAccuracy;
  final bool timedOut;
}

/// موقع التوصيل — PositionStream للقفل؛ الإحداثيات النهائية بعد تحقق الدقة.
class DeliveryLocationNotifier extends ChangeNotifier {
  DeliveryLocationNotifier();

  DeliveryLocationStatus _status = DeliveryLocationStatus.idle;
  double? _latitude;
  double? _longitude;
  double? _previewLatitude;
  double? _previewLongitude;
  double? _accuracyMeters;
  bool _manualPin = false;
  DeliveryLocationSource _source = DeliveryLocationSource.none;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _acquisitionTimer;

  DeliveryLocationStatus get status => _status;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  double? get previewLatitude => _previewLatitude;
  double? get previewLongitude => _previewLongitude;
  double? get accuracyMeters => _accuracyMeters;
  bool get isManualPin => _manualPin;
  DeliveryLocationSource get source => _source;

  bool get isAcquiring => _status == DeliveryLocationStatus.loading;

  bool get isManualConfirmReady => _status == DeliveryLocationStatus.refining;

  bool get hasAcceptableAccuracy =>
      LocationPositionValidator.isAcceptableAccuracy(
        _accuracyMeters,
        manualPin: _manualPin,
      );

  bool get hasLocation =>
      _latitude != null &&
      _longitude != null &&
      _status == DeliveryLocationStatus.granted;

  bool get hasAcceptableLocation =>
      hasLocation &&
      (_source == DeliveryLocationSource.saved || hasAcceptableAccuracy);

  /// اعتماد موقع محفوظ — بدون تشغيل GPS.
  void applySavedLocation({
    required double latitude,
    required double longitude,
  }) {
    unawaited(_stopAcquisition());
    _latitude = latitude;
    _longitude = longitude;
    _accuracyMeters = null;
    _manualPin = false;
    _source = DeliveryLocationSource.saved;
    _previewLatitude = null;
    _previewLongitude = null;
    _status = DeliveryLocationStatus.granted;
    notifyListeners();
  }

  String get displayLabel {
    switch (_status) {
      case DeliveryLocationStatus.loading:
        return 'جاري تثبيت موقعك بدقة (GPS)...';
      case DeliveryLocationStatus.refining:
        if (_accuracyMeters != null) {
          return 'الدقة الحالية ~${_accuracyMeters!.toStringAsFixed(0)}م — '
              'اسحب الدبوس أو أعد المحاولة';
        }
        return 'اسحب الدبوس أو أعد المحاولة';
      case DeliveryLocationStatus.granted:
        if (_source == DeliveryLocationSource.saved) {
          return 'تم اعتماد عنوانك المحفوظ للتوصيل';
        }
        if (_latitude != null && _longitude != null) {
          final acc = _accuracyMeters != null
              ? ' (±${_accuracyMeters!.toStringAsFixed(0)}م)'
              : _manualPin
                  ? ' (يدوي)'
                  : '';
          return 'تم تحديد الموقع$acc';
        }
        return 'تم تحديد الموقع';
      case DeliveryLocationStatus.denied:
        return 'تم رفض إذن الموقع';
      case DeliveryLocationStatus.gpsDisabled:
        return LocationFeatureFlags.gpsDisabledMessage;
      case DeliveryLocationStatus.weakSignal:
        return LocationFeatureFlags.weakSignalMessage;
      case DeliveryLocationStatus.error:
        return 'تعذّر تحديد الموقع';
      case DeliveryLocationStatus.idle:
        return 'حدّد موقع التوصيل';
    }
  }

  /// يبدأ PositionStream — قفل تلقائي عند دقة ≤ 15م خلال 4 ثوانٍ.
  Future<LocationAcquisitionSnapshot?> startHighAccuracyAcquisition() async {
    await _stopAcquisition();
    _status = DeliveryLocationStatus.loading;
    _previewLatitude = null;
    _previewLongitude = null;
    _accuracyMeters = null;
    _manualPin = false;
    _source = DeliveryLocationSource.none;
    notifyListeners();

    if (!await _ensureLocationReady()) {
      return null;
    }

    final completer = Completer<LocationAcquisitionSnapshot?>();
    Position? bestPosition;

    final initial = await DeviceLocationReader.getCurrentLocation();
    if (initial != null) {
      bestPosition = initial;
      _previewLatitude = initial.latitude;
      _previewLongitude = initial.longitude;
      _accuracyMeters = initial.accuracy;
      notifyListeners();
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen(
      (position) {
        if (!LocationPositionValidator.isPreviewReading(position)) {
          return;
        }

        if (bestPosition == null || position.accuracy < bestPosition!.accuracy) {
          bestPosition = position;
          _previewLatitude = position.latitude;
          _previewLongitude = position.longitude;
          _accuracyMeters = position.accuracy;
          notifyListeners();
        }

        if (!LocationPositionValidator.isUsableReading(position)) {
          return;
        }

        if (LocationPositionValidator.isLockInQuality(position) &&
            !completer.isCompleted) {
          _finishAcquisition(
            completer: completer,
            position: position,
            reachedTargetAccuracy: true,
            timedOut: false,
          );
        }
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('DeliveryLocationNotifier stream: $error\n$stack');
        if (completer.isCompleted) return;

        if (bestPosition != null &&
            LocationPositionValidator.isLockInQuality(bestPosition!)) {
          _finishAcquisition(
            completer: completer,
            position: bestPosition!,
            reachedTargetAccuracy: true,
            timedOut: false,
          );
          return;
        }

        if (bestPosition != null) {
          _status = DeliveryLocationStatus.refining;
          _previewLatitude = bestPosition!.latitude;
          _previewLongitude = bestPosition!.longitude;
          _accuracyMeters = bestPosition!.accuracy;
          notifyListeners();
          completer.complete(
            LocationAcquisitionSnapshot(
              latitude: bestPosition!.latitude,
              longitude: bestPosition!.longitude,
              accuracyMeters: bestPosition!.accuracy,
              reachedTargetAccuracy: false,
              timedOut: true,
            ),
          );
          return;
        }

        _status = DeliveryLocationStatus.refining;
        notifyListeners();
        completer.complete(null);
      },
    );

    _acquisitionTimer = Timer(LocationFeatureFlags.acquisitionDuration, () {
      if (completer.isCompleted) return;

      if (bestPosition == null) {
        unawaited(
          DeviceLocationReader.getCurrentLocation().then((position) {
            if (completer.isCompleted) return;
            if (position != null) {
              _finishAcquisition(
                completer: completer,
                position: position,
                reachedTargetAccuracy:
                    LocationPositionValidator.isLockInQuality(position),
                timedOut: !LocationPositionValidator.isLockInQuality(position),
              );
              return;
            }
            _status = DeliveryLocationStatus.refining;
            notifyListeners();
            completer.complete(null);
          }),
        );
        return;
      }

      if (LocationPositionValidator.isLockInQuality(bestPosition!)) {
        _finishAcquisition(
          completer: completer,
          position: bestPosition!,
          reachedTargetAccuracy: true,
          timedOut: false,
        );
        return;
      }

      _status = DeliveryLocationStatus.refining;
      _previewLatitude = bestPosition!.latitude;
      _previewLongitude = bestPosition!.longitude;
      _accuracyMeters = bestPosition!.accuracy;
      notifyListeners();

      completer.complete(
        LocationAcquisitionSnapshot(
          latitude: bestPosition!.latitude,
          longitude: bestPosition!.longitude,
          accuracyMeters: bestPosition!.accuracy,
          reachedTargetAccuracy: false,
          timedOut: true,
        ),
      );
    });

    return completer.future;
  }

  /// جلب فوري من نظام التشغيل (زر «تحديث») — يتخطى last-known cache.
  Future<LocationAcquisitionSnapshot?> refreshCurrentLocation() async {
    await _stopAcquisition();
    _status = DeliveryLocationStatus.loading;
    _previewLatitude = null;
    _previewLongitude = null;
    _accuracyMeters = null;
    notifyListeners();

    if (!await _ensureLocationReady()) {
      return null;
    }

    final position = await DeviceLocationReader.getCurrentLocation();
    if (position == null) {
      _status = DeliveryLocationStatus.refining;
      notifyListeners();
      return null;
    }

    return _applyPreviewPosition(
      position,
      reachedTargetAccuracy:
          LocationPositionValidator.isLockInQuality(position),
    );
  }

  Future<LocationAcquisitionSnapshot?> refreshHighAccuracyAcquisition() {
    return refreshCurrentLocation();
  }

  /// يثبّت الموقع — يرفض إحداثيات GPS الضعيفة ما لم يكن تأكيداً يدوياً بالدبوس.
  bool tryConfirmLocation({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    required bool manualPin,
  }) {
    unawaited(_stopAcquisition());

    if (!manualPin &&
        !LocationPositionValidator.isAcceptableAccuracy(
          accuracyMeters,
          manualPin: false,
        )) {
      _status = DeliveryLocationStatus.weakSignal;
      _accuracyMeters = accuracyMeters;
      notifyListeners();
      return false;
    }

    _latitude = latitude;
    _longitude = longitude;
    _accuracyMeters = manualPin ? null : accuracyMeters;
    _manualPin = manualPin;
    _source = DeliveryLocationSource.gps;
    _previewLatitude = null;
    _previewLongitude = null;
    _status = DeliveryLocationStatus.granted;
    notifyListeners();
    return true;
  }

  void stopAcquisitionForManualPin() {
    unawaited(_stopAcquisition());
    if (_status == DeliveryLocationStatus.loading) {
      _status = DeliveryLocationStatus.refining;
      notifyListeners();
    }
  }

  void clear() {
    unawaited(_stopAcquisition());
    _status = DeliveryLocationStatus.idle;
    _latitude = null;
    _longitude = null;
    _previewLatitude = null;
    _previewLongitude = null;
    _accuracyMeters = null;
    _manualPin = false;
    _source = DeliveryLocationSource.none;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_stopAcquisition());
    super.dispose();
  }

  LocationSettings _buildLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        forceLocationManager: true,
        intervalDuration: const Duration(milliseconds: 300),
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.other,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );
  }

  Future<bool> _ensureLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _status = DeliveryLocationStatus.gpsDisabled;
      notifyListeners();
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _status = DeliveryLocationStatus.denied;
      notifyListeners();
      return false;
    }

    return true;
  }

  LocationAcquisitionSnapshot _applyPreviewPosition(
    Position position, {
    required bool reachedTargetAccuracy,
    bool timedOut = false,
  }) {
    _status = DeliveryLocationStatus.refining;
    _previewLatitude = position.latitude;
    _previewLongitude = position.longitude;
    _accuracyMeters = position.accuracy;
    notifyListeners();

    return LocationAcquisitionSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      reachedTargetAccuracy: reachedTargetAccuracy,
      timedOut: timedOut,
    );
  }

  void _finishAcquisition({
    required Completer<LocationAcquisitionSnapshot?> completer,
    required Position position,
    required bool reachedTargetAccuracy,
    required bool timedOut,
  }) {
    if (completer.isCompleted) return;

    unawaited(_stopAcquisition());

    completer.complete(
      _applyPreviewPosition(
        position,
        reachedTargetAccuracy: reachedTargetAccuracy,
        timedOut: timedOut,
      ),
    );
  }

  Future<void> _stopAcquisition() async {
    _acquisitionTimer?.cancel();
    _acquisitionTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
