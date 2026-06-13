import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/config/location_feature_flags.dart';
import '../core/utils/device_location_reader.dart';
import '../core/utils/location_position_validator.dart';
import '../models/delivery_location_source_kind.dart';

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
  Position? _lastPrecisePosition;
  DeliveryLocationSourceKind? _orderSourceKind;
  bool _persistSavedLocationAfterOrder = false;
  OrderLocationIntent _pendingMapIntent = OrderLocationIntent.none;

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

  DeliveryLocationSourceKind? get orderSourceKind => _orderSourceKind;

  bool get persistSavedLocationAfterOrder => _persistSavedLocationAfterOrder;

  OrderLocationIntent get pendingMapIntent => _pendingMapIntent;

  bool get isAcquiring => _status == DeliveryLocationStatus.loading;

  bool get isManualConfirmReady => _status == DeliveryLocationStatus.refining;

  bool get hasAcceptableAccuracy =>
      LocationPositionValidator.isAcceptableAccuracy(
        _accuracyMeters,
        manualPin: _manualPin,
      );

  bool get hasPreciseReading => _lastPrecisePosition != null;

  double? get lastPreciseLatitude => _lastPrecisePosition?.latitude;

  double? get lastPreciseLongitude => _lastPrecisePosition?.longitude;

  double? get lastPreciseAccuracyMeters => _lastPrecisePosition?.accuracy;

  String? get accuracyDisplayLabel {
    final meters = _accuracyMeters;
    if (meters == null) return null;
    return 'دقة الموقع: ${meters.toStringAsFixed(0)} متر';
  }

  bool get hasLocation =>
      _latitude != null &&
      _longitude != null &&
      _status == DeliveryLocationStatus.granted;

  bool get hasAcceptableLocation {
    if (!hasLocation) return false;
    if (_orderSourceKind == DeliveryLocationSourceKind.savedHome) return true;
    if (_orderSourceKind == DeliveryLocationSourceKind.manualMarker) return true;
    if (_manualPin) return true;
    return hasAcceptableAccuracy;
  }

  void setPendingMapIntent(OrderLocationIntent intent) {
    _pendingMapIntent = intent;
  }

  void applyOrderOnlyIntent() {
    _persistSavedLocationAfterOrder = false;
    _orderSourceKind = _manualPin
        ? DeliveryLocationSourceKind.manualMarker
        : DeliveryLocationSourceKind.temporaryNew;
    notifyListeners();
  }

  void applyUpdateSavedIntent() {
    _persistSavedLocationAfterOrder = true;
    _orderSourceKind = DeliveryLocationSourceKind.updatedHome;
    notifyListeners();
  }

  /// اعتماد موقع محفوظ — بدون تشغيل GPS ولا تحديث profiles.
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
    _orderSourceKind = DeliveryLocationSourceKind.savedHome;
    _persistSavedLocationAfterOrder = false;
    _pendingMapIntent = OrderLocationIntent.none;
    _previewLatitude = null;
    _previewLongitude = null;
    _status = DeliveryLocationStatus.granted;
    _logConfirmed(
      latitude: latitude,
      longitude: longitude,
      sourceKind: DeliveryLocationSourceKind.savedHome,
    );
    notifyListeners();
  }

  String get displayLabel {
    switch (_status) {
      case DeliveryLocationStatus.loading:
        return 'جاري تثبيت موقعك بدقة (GPS)...';
      case DeliveryLocationStatus.refining:
        if (_accuracyMeters != null) {
          return '${accuracyDisplayLabel!} — '
              'اسحب الدبوس أو اضغط «استخدم موقعي الحالي»';
        }
        return 'انتظر إشارة GPS أو اسحب الدبوس يدوياً';
      case DeliveryLocationStatus.granted:
        if (_orderSourceKind != null) {
          return _orderSourceKind!.displayLabel;
        }
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

  /// يبدأ PositionStream — قفل تلقائي عند دقة ≤ 15م خلال 10 ثوانٍ.
  Future<LocationAcquisitionSnapshot?> startHighAccuracyAcquisition() async {
    await _stopAcquisition();
    _status = DeliveryLocationStatus.loading;
    _previewLatitude = null;
    _previewLongitude = null;
    _accuracyMeters = null;
    _manualPin = false;
    _source = DeliveryLocationSource.none;
    _lastPrecisePosition = null;
    notifyListeners();

    if (!await _ensureLocationReady()) {
      return null;
    }

    final completer = Completer<LocationAcquisitionSnapshot?>();
    Position? bestPosition;

    final initial = await DeviceLocationReader.getCurrentLocation();
    if (initial != null) {
      bestPosition = initial;
      _applyPreviewFromPosition(initial);
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
          _applyPreviewFromPosition(position);
        }

        if (LocationPositionValidator.isLockInQuality(position)) {
          _lastPrecisePosition = position;
        }

        if (kDebugMode) {
          debugPrint(
            '[DeliveryLocationNotifier] stream: '
            'latitude=${position.latitude}, '
            'longitude=${position.longitude}, '
            'accuracy=${position.accuracy}, '
            'source=positionStream',
          );
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

        if (bestPosition != null &&
            LocationPositionValidator.isPreviewReading(bestPosition!)) {
          _applyPreviewFromPosition(bestPosition!);
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

        _status = DeliveryLocationStatus.weakSignal;
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

      if (LocationPositionValidator.isPreviewReading(bestPosition!)) {
        _status = DeliveryLocationStatus.refining;
        _applyPreviewFromPosition(bestPosition!);
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

      _status = DeliveryLocationStatus.weakSignal;
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

  /// جلب موقع حالي من GPS (زر «تحديث موقعي الحالي») — انتظار قراءة جديدة.
  Future<LocationAcquisitionSnapshot?> refreshCurrentLocation() {
    return startHighAccuracyAcquisition();
  }

  Future<LocationAcquisitionSnapshot?> refreshHighAccuracyAcquisition() {
    return refreshCurrentLocation();
  }

  /// يثبّت الموقع من الخريطة — الإحداثيات من الدبوس فقط.
  bool confirmMapLocation({
    required double latitude,
    required double longitude,
    required bool fromManualMarker,
  }) {
    if (!latitude.isFinite || !longitude.isFinite) {
      return false;
    }

    unawaited(_stopAcquisition());

    final sourceKind = _resolveSourceKindForMapConfirm(fromManualMarker);

    _latitude = latitude;
    _longitude = longitude;
    _accuracyMeters = fromManualMarker ? null : _accuracyMeters;
    _manualPin = fromManualMarker;
    _source = DeliveryLocationSource.gps;
    _orderSourceKind = sourceKind;
    _persistSavedLocationAfterOrder =
        _pendingMapIntent == OrderLocationIntent.updateSaved ||
        sourceKind == DeliveryLocationSourceKind.updatedHome;
    _previewLatitude = null;
    _previewLongitude = null;
    _lastPrecisePosition = null;
    _status = DeliveryLocationStatus.granted;
    _pendingMapIntent = OrderLocationIntent.none;

    _logConfirmed(
      latitude: latitude,
      longitude: longitude,
      sourceKind: sourceKind,
    );
    notifyListeners();
    return true;
  }

  DeliveryLocationSourceKind _resolveSourceKindForMapConfirm(bool fromManual) {
    if (_pendingMapIntent == OrderLocationIntent.updateSaved) {
      return DeliveryLocationSourceKind.updatedHome;
    }
    if (_pendingMapIntent == OrderLocationIntent.orderOnly) {
      return fromManual
          ? DeliveryLocationSourceKind.manualMarker
          : DeliveryLocationSourceKind.temporaryNew;
    }
    return fromManual
        ? DeliveryLocationSourceKind.manualMarker
        : DeliveryLocationSourceKind.gps;
  }

  void _logConfirmed({
    required double latitude,
    required double longitude,
    required DeliveryLocationSourceKind sourceKind,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[DeliveryLocationNotifier] order location: '
      'delivery_latitude=$latitude, '
      'delivery_longitude=$longitude, '
      'delivery_location_source=${sourceKind.logValue}, '
      'persist_saved=$_persistSavedLocationAfterOrder',
    );
  }

  /// للتوافق — يُفضَّل `confirmMapLocation`.
  bool tryConfirmLocation({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    required bool manualPin,
  }) {
    if (!latitude.isFinite || !longitude.isFinite) {
      return false;
    }

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

    if (kDebugMode) {
      debugPrint(
        '[DeliveryLocationNotifier] confirmed: '
        'latitude=$latitude, longitude=$longitude, '
        'accuracy=${accuracyMeters ?? 'manual'}, '
        'source=${manualPin ? 'manual' : 'gps'}',
      );
    }
    return true;
  }

  /// تحديث إحداثيات المعاينة عند سحب الدبوس يدوياً.
  void applyManualPreview({
    required double latitude,
    required double longitude,
  }) {
    if (!latitude.isFinite || !longitude.isFinite) return;

    _previewLatitude = latitude;
    _previewLongitude = longitude;
    _manualPin = true;
    if (_status == DeliveryLocationStatus.loading) {
      _status = DeliveryLocationStatus.refining;
    }
    notifyListeners();

    if (kDebugMode) {
      debugPrint(
        '[DeliveryLocationNotifier] manual preview: '
        'latitude=$latitude, longitude=$longitude, '
        'accuracy=manual, source=manual',
      );
    }
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
    _lastPrecisePosition = null;
    _orderSourceKind = null;
    _persistSavedLocationAfterOrder = false;
    _pendingMapIntent = OrderLocationIntent.none;
    notifyListeners();
  }

  void _applyPreviewFromPosition(Position position) {
    if (!LocationPositionValidator.isPreviewReading(position)) {
      return;
    }
    _previewLatitude = position.latitude;
    _previewLongitude = position.longitude;
    _accuracyMeters = position.accuracy;
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
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: false,
        intervalDuration: const Duration(milliseconds: 500),
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
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
    if (LocationPositionValidator.isLockInQuality(position)) {
      _lastPrecisePosition = position;
    }

    if (LocationPositionValidator.isPreviewReading(position)) {
      _status = DeliveryLocationStatus.refining;
      _previewLatitude = position.latitude;
      _previewLongitude = position.longitude;
      _accuracyMeters = position.accuracy;
    } else {
      _status = DeliveryLocationStatus.weakSignal;
      _accuracyMeters = position.accuracy;
    }
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
