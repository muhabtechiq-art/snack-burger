import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/location_feature_flags.dart';
import '../../../core/theme/tenant_palette.dart';
import '../../../state/delivery_location_notifier.dart';

/// موقع افتراضي (بغداد) عند غياب GPS — يُستبدل بحركة الدبوس.
const LatLng _fallbackMapCenter = LatLng(33.3152, 44.3661);

/// خريطة تأكيدية — الإحداثيات النهائية من مكان الدبوس وليس تخمين GPS.
class DeliveryLocationMapDialog extends StatefulWidget {
  const DeliveryLocationMapDialog({
    super.key,
    required this.notifier,
    required this.palette,
    this.startGpsOnOpen = true,
  });

  final DeliveryLocationNotifier notifier;
  final TenantPalette palette;

  /// `true` = تشغيل GPS عند الفتح (تغيير الموقع). `false` = خريطة فقط.
  final bool startGpsOnOpen;

  static Future<bool?> show({
    required BuildContext context,
    required DeliveryLocationNotifier notifier,
    required TenantPalette palette,
    bool startGpsOnOpen = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeliveryLocationMapDialog(
        notifier: notifier,
        palette: palette,
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

  late LatLng _markerPoint;
  bool _pinIsAuthoritative = false;
  bool _manualConfirmReady = false;
  bool _isRefreshing = false;
  String? _statusHint;

  @override
  void initState() {
    super.initState();
    _markerPoint = _fallbackMapCenter;
    widget.notifier.addListener(_onNotifierChanged);

    if (widget.startGpsOnOpen) {
      unawaited(_beginAcquisition());
    } else {
      _manualConfirmReady = true;
      _statusHint = 'اسحب الدبوس أو اضغط على الخريطة.';
    }
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onNotifierChanged);
    widget.notifier.stopAcquisitionForManualPin();
    super.dispose();
  }

  Future<void> _beginAcquisition() async {
    setState(() {
      _statusHint = 'جاري تحديد موقعك بدقة...';
      _manualConfirmReady = false;
    });

    final snapshot = await widget.notifier.startHighAccuracyAcquisition();
    if (!mounted) return;

    setState(() {
      _isRefreshing = false;
      if (snapshot != null && !_pinIsAuthoritative) {
        _markerPoint = LatLng(snapshot.latitude, snapshot.longitude);
      }
      _manualConfirmReady =
          snapshot == null ||
          snapshot.timedOut ||
          !snapshot.reachedTargetAccuracy ||
          widget.notifier.isManualConfirmReady;
      _statusHint = _manualConfirmReady
          ? 'إشارة GPS ضعيفة أو غير متوفرة.\n'
              'اسحب الدبوس للمكان الصحيح ثم اضغط «تأكيد الموقع».'
          : 'تم تلميح GPS — يمكنك ضبط الدبوس يدوياً.';
    });

    _moveMapToMarker();
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
      if (snapshot != null) {
        _markerPoint = LatLng(snapshot.latitude, snapshot.longitude);
        _manualConfirmReady = true;
        final acc = snapshot.accuracyMeters.toStringAsFixed(0);
        _statusHint = snapshot.reachedTargetAccuracy
            ? 'تم تحديث موقعك (±$acc م) — أكّد أو اسحب الدبوس.'
            : 'تم تحديث موقعك تقريباً (±$acc م) — اسحب الدبوس إن لزم.';
      } else {
        _manualConfirmReady = true;
        _statusHint =
            'تعذّر جلب GPS — تأكد من المحاكي/الإذن، أو اسحب الدبوس يدوياً.';
      }
    });

    _moveMapToMarker();
  }

  void _onNotifierChanged() {
    if (_pinIsAuthoritative || !mounted) return;

    final lat = widget.notifier.previewLatitude;
    final lng = widget.notifier.previewLongitude;
    if (lat == null || lng == null) return;

    setState(() {
      _markerPoint = LatLng(lat, lng);
      if (widget.notifier.isManualConfirmReady) {
        _manualConfirmReady = true;
        _statusHint =
            'جاري تحسين الدقة، يرجى الانتظار...\n'
            'اسحب الدبوس للمكان الصحيح.';
      }
    });

    if (widget.notifier.isAcquiring) {
      _mapController.move(_markerPoint, _mapController.camera.zoom);
    }
  }

  void _moveMapToMarker() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(_markerPoint, 17);
    });
  }

  void _setMarkerFromScreen(Offset globalPosition) {
    final renderBox =
        _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final local = renderBox.globalToLocal(globalPosition);
    final latLng = _mapController.camera.pointToLatLng(
      Point<double>(local.dx, local.dy),
    );

    setState(() {
      _pinIsAuthoritative = true;
      _manualConfirmReady = true;
      _markerPoint = latLng;
      _statusHint = 'تم ضبط الموقع يدوياً — اضغط «تأكيد الموقع يدوياً».';
    });
    widget.notifier.stopAcquisitionForManualPin();
  }

  void _confirmLocation() {
    final treatAsManual = _pinIsAuthoritative || _manualConfirmReady;
    final accuracy = treatAsManual ? null : widget.notifier.accuracyMeters;
    final ok = widget.notifier.tryConfirmLocation(
      latitude: _markerPoint.latitude,
      longitude: _markerPoint.longitude,
      accuracyMeters: accuracy,
      manualPin: treatAsManual,
    );
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(LocationFeatureFlags.weakSignalMessage),
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
    final canConfirm = !widget.notifier.isAcquiring || _pinIsAuthoritative;

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
                          initialCenter: _markerPoint,
                          initialZoom: 17,
                          minZoom: 5,
                          maxZoom: 19,
                          onTap: (_, point) {
                            setState(() {
                              _pinIsAuthoritative = true;
                              _manualConfirmReady = true;
                              _markerPoint = point;
                              _statusHint =
                                  'تم ضبط الموقع يدوياً — اضغط «تأكيد الموقع يدوياً».';
                            });
                            widget.notifier.stopAcquisitionForManualPin();
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.snack_burger',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _markerPoint,
                                width: 52,
                                height: 52,
                                alignment: Alignment.bottomCenter,
                                child: GestureDetector(
                                  onPanUpdate: (details) =>
                                      _setMarkerFromScreen(
                                        details.globalPosition,
                                      ),
                                  onPanEnd: (_) {
                                    setState(() {
                                      _pinIsAuthoritative = true;
                                      _manualConfirmReady = true;
                                      _statusHint =
                                          'تم ضبط الموقع يدوياً — اضغط «تأكيد الموقع يدوياً».';
                                    });
                                    widget.notifier.stopAcquisitionForManualPin();
                                  },
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
              Text(
                '${_markerPoint.latitude.toStringAsFixed(5)}, '
                '${_markerPoint.longitude.toStringAsFixed(5)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.palette.primary.withValues(alpha: 0.65),
                  fontSize: 11,
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
                label: const Text('تحديث'),
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
