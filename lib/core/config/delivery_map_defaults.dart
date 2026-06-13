import 'package:latlong2/latlong.dart';

/// مراكز وزوم افتراضية لخريطة تحديد موقع التوصيل — للعرض فقط.
abstract final class DeliveryMapDefaults {
  DeliveryMapDefaults._();

  /// مركز منطقة خدمة Snack Burger (بغداد) — لا يُحفظ كموقع توصيل.
  static const LatLng serviceAreaCenter = LatLng(33.3152, 44.3661);

  static const double savedLocationZoom = 16;
  static const double restaurantFallbackZoom = 13;
  static const double gpsLockZoom = 16;
}
