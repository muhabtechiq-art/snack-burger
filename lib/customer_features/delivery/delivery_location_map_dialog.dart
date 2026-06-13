import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/location_feature_flags.dart';
import '../../../core/theme/tenant_palette.dart';
import '../../../state/delivery_location_notifier.dart';

/// مركز الخريطة قبل تحديد موقع — للعرض فقط ولا يُحفظ أبداً.
const LatLng _mapViewportCenter = LatLng(20, 0);
const double _mapViewportZoom = 3;

/// خريطة تأكيدية — الإحداثيات النهائية من مكان الدبوس فقط.
class DeliveryLocationMapDialog extends StatefulWidget {
  const DeliveryLocationMapDialog({
    super.key,
    required this.notifier,
    required this.palette,
    this.mapInitialCenter,
    this.startGpsOnOpen = true,
  });

  final DeliveryLocationNotifier notifier;
  final TenantPalette palette;

  /// مركز الخريطة (مثلاً الموقع المحفوظ) — للعرض فقط.
  final LatLng? mapInitialCenter;

  /// `true` = طلب GPS عند الفتح. `false` = انتظر زر «استخدم موقعي الحالي».
  final bool startGpsOnOpen;

  static Future<bool?> show({
    required BuildContext context,
    required DeliveryLocationNotifier notifier,
    required TenantPalette palette,
    LatLng? mapInitialCenter,
    bool startGpsOnOpen = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeliveryLocationMapDialog(
        notifier: notifier,
        palette: palette,
        mapInitialCenter: mapInitialCenter,
        startGpsOnOpen: startGpsOnOpen,
      ),
    );
  }

  @override
  State<DeliveryLocationMapDialog> createState() =>
      _DeliveryLocationMapDialogState();
}

class _DeliveryLocationMapDialogState extends State<DeliveryLocationMapDialog> {
  final MapController _mapController = MapController();
  final GlobalKey _mapKey = GlobalKey();

  LatLng? _markerPoint;
  bool _pinIsAuthoritative = false;
  bool _isRefreshing = false;
  String? _statusHint;

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onNotifierChanged);

    if (widget.mapInitialCenter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(widget.mapInitialCenter!, 16);
      });
      _statusHint = widget.startGpsOnOpen
          ? 'جاري جلب موقعك الحالي من GPS...'
          : 'الخريطة على موقعك المحفوظ — حدّد نقطة جديدة أو اضغط «استخدم موقعي الحالي».';
    }

    if (widget.startGpsOnOpen) {
      unawaited(_beginAcquisition());
    } else if (widget.mapInitialCenter == null) {
      _statusHint = 'اضغط على الخريطة أو اسحب الدبوس لتحديد موقعك.';
    }
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onNotifierChanged);
    widget.notifier.stopAcquisitionForManualPin();
    super.dispose();
  }

  Future<void> _beginAcquisition({int autoRetry = 0}) async {
    setState(() {
      _statusHint = 'جاري جلب موقعك الحالي من GPS...';
    });

    final snapshot = await widget.notifier.startHighAccuracyAcquisition();
    if (!mounted) return;

    final needsRetry = snapshot == null ||
        snapshot.accuracyMeters >
            LocationFeatureFlags.maxAcceptableAccuracyMeters;
    if (needsRetry && autoRetry < 1) {
      setState(() {
        _statusHint = LocationFeatureFlags.weakSignalMessage;
      });
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      await _beginAcquisition(autoRetry: autoRetry + 1);
      return;
    }

    setState(() {
      _isRefreshing = false;
      if (snapshot != null &&
          snapshot.accuracyMeters <=
              LocationFeatureFlags.maxPreviewAccuracyMeters &&
          !_pinIsAuthoritative) {
        _markerPoint = LatLng(snapshot.latitude, snapshot.longitude);
      }
      _statusHint = _buildStatusHint(snapshot);
    });

    if (_markerPoint != null) {
      _moveMapToMarker();
    }
  }

  String _buildStatusHint(LocationAcquisitionSnapshot? snapshot) {
    if (snapshot == null) {
      return '${LocationFeatureFlags.locationFailedMessage}\n'
          'حدّد النقطة يدوياً على الخريطة أو اضغط «استخدم موقعي الحالي».';
    }

    final accuracyLabel = widget.notifier.accuracyDisplayLabel;
    if (snapshot.reachedTargetAccuracy) {
      return '${accuracyLabel ?? ''}\n'
          'اسحب الدبوس للتعديل ثم أكّد الموقع.';
    }

    if (snapshot.accuracyMeters >
        LocationFeatureFlags.maxAcceptableAccuracyMeters) {
      return '${LocationFeatureFlags.weakSignalMessage}\n'
          '${accuracyLabel ?? ''}\n'
          'اسحب الدبوس يدوياً أو أعد المحاولة.';
    }

    return '${accuracyLabel ?? ''}\n'
        'اسحب الدبوس للتعديل ثم أكّد الموقع.';
  }

  Future<void> _refreshAcquisition() async {
    setState(() {
      _pinIsAuthoritative = false;
      _isRefreshing = true;
      _statusHint = 'جاري جلب موقعك الحالي من GPS...';
    });

    final snapshot = await widget.notifier.refreshCurrentLocation();
    if (!mounted) return;

    setState(() {
      _isRefreshing = false;
      if (snapshot != null &&
          snapshot.accuracyMeters <=
              LocationFeatureFlags.maxPreviewAccuracyMeters &&
          !_pinIsAuthoritative) {
        _markerPoint = LatLng(snapshot.latitude, snapshot.longitude);
      }
      _statusHint = _buildStatusHint(snapshot);
    });

    if (_markerPoint != null) {
      _moveMapToMarker();
    }
  }

  void _onNotifierChanged() {
    if (_pinIsAuthoritative || !mounted) return;

    final lat = widget.notifier.previewLatitude;
    final lng = widget.notifier.previewLongitude;
    if (lat == null || lng == null) return;

    setState(() {
      _markerPoint = LatLng(lat, lng);
      final accuracyLabel = widget.notifier.accuracyDisplayLabel;
      if (accuracyLabel != null) {
        _statusHint = '$accuracyLabel\n'
            'اسحب الدبوس للتعديل ثم أكّد الموقع.';
      }
    });

    if (widget.notifier.isAcquiring && _markerPoint != null) {
      _mapController.move(_markerPoint!, _mapController.camera.zoom);
    }
  }

  void _moveMapToMarker() {
    final point = _markerPoint;
    if (point == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(point, 17);
    });
  }

  void _applyManualMarker(LatLng latLng) {
    setState(() {
      _pinIsAuthoritative = true;
      _markerPoint = latLng;
      _statusHint =
          'تم ضبط الموقع يدوياً — اضغط «تأكيد الموقع» لحفظ الإحداثيات.';
    });
    widget.notifier.applyManualPreview(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
    );
    widget.notifier.stopAcquisitionForManualPin();
    _moveMapToMarker();
  }

  void _setMarkerFromScreen(Offset globalPosition) {
    final renderBox =
        _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final local = renderBox.globalToLocal(globalPosition);
    final latLng = _mapController.camera.pointToLatLng(
      Point<double>(local.dx, local.dy),
    );

    _applyManualMarker(latLng);
  }

  void _confirmLocation() {
    final point = _markerPoint;
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(LocationFeatureFlags.locationRequiredMessage),
        ),
      );
      return;
    }

    final ok = widget.notifier.confirmMapLocation(
      latitude: point.latitude,
      longitude: point.longitude,
      fromManualMarker: _pinIsAuthoritative,
    );
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(LocationFeatureFlags.locationRequiredMessage),
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isGpsHintLoading = widget.notifier.isAcquiring && !_pinIsAuthoritative;
    final viewHeight = MediaQuery.sizeOf(context).height;
    final mapHeight = (viewHeight * 0.30).clamp(180.0, 240.0);
    final canConfirm = !widget.notifier.isAcquiring && _markerPoint != null;
    final accuracyLabel = widget.notifier.accuracyDisplayLabel;
    final mapCenter =
        _markerPoint ?? widget.mapInitialCenter ?? _mapViewportCenter;
    final mapZoom = _markerPoint != null
        ? 17.0
        : widget.mapInitialCenter != null
            ? 16.0
            : _mapViewportZoom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تأكيد موقع التوصيل',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: viewHeight * 0.52),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_statusHint != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.palette.surfaceTint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.palette.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        _statusHint!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: widget.palette.primary,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: mapHeight,
                      child: Stack(
                        children: [
                          FlutterMap(
                            key: _mapKey,
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: mapCenter,
                              initialZoom: mapZoom,
                              minZoom: 3,
                              maxZoom: 19,
                              onTap: (_, point) => _applyManualMarker(point),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.snack_burger',
                              ),
                              if (_markerPoint != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _markerPoint!,
                                      width: 52,
                                      height: 52,
                                      alignment: Alignment.bottomCenter,
                                      child: GestureDetector(
                                        onPanUpdate: (details) =>
                                            _setMarkerFromScreen(
                                          details.globalPosition,
                                        ),
                                        child: Icon(
                                          Icons.location_on_rounded,
                                          size: 46,
                                          color: widget.palette.primary,
                                          shadows: const [
                                            Shadow(
                                              blurRadius: 8,
                                              color: Colors.black26,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (isGpsHintLoading)
                            Positioned(
                              top: 8,
                              left: 8,
                              right: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: widget.palette.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'جاري تحديد موقعك بدقة...',
                                          style: TextStyle(
                                            color: widget.palette.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'اسحب الدبوس أو اضغط على الخريطة — الموقع النهائي هو مكان الدبوس.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.palette.primary.withValues(alpha: 0.75),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (accuracyLabel != null && !_pinIsAuthoritative)
                    Text(
                      accuracyLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.palette.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (accuracyLabel != null && !_pinIsAuthoritative)
                    const SizedBox(height: 4),
                  if (_markerPoint != null)
                    Text(
                      '${_markerPoint!.latitude.toStringAsFixed(5)}, '
                      '${_markerPoint!.longitude.toStringAsFixed(5)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.palette.primary.withValues(alpha: 0.65),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      'لم يُحدد موقع بعد',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.palette.primary.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          OverflowBar(
            spacing: 8,
            overflowSpacing: 8,
            overflowAlignment: OverflowBarAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              OutlinedButton.icon(
                onPressed: _isRefreshing ? null : _refreshAcquisition,
                icon: _isRefreshing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.palette.primary,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded, size: 20),
                label: const Text('استخدم موقعي الحالي'),
              ),
              FilledButton(
                onPressed: canConfirm ? _confirmLocation : null,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.palette.primary,
                  foregroundColor: widget.palette.onPrimary,
                ),
                child: const Text(
                  'تأكيد الموقع',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
