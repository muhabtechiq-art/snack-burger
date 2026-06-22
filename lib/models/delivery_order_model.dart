import '../core/config/location_feature_flags.dart';
import '../core/config/restaurant_ids.dart';
import '../core/utils/delivery_coordinates.dart';
import '../core/utils/model_parse_validation.dart';
import '../core/utils/order_tenant_match.dart';
import 'delivery_order_status.dart';
import 'order_model.dart';
import 'product_model.dart' show parseModelDate;

/// طلب توصيل من Supabase (جدول `orders`).
class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    required this.restaurantId,
    required this.slug,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    this.locationCoordinates,
    this.latitude,
    this.longitude,
    this.deliveryDriverId,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
    this.businessDayId,
    this.businessDayOrderNumber,
  });

  final String id;
  final String restaurantId;
  final String slug;
  final String customerName;
  final String customerPhone;
  final String address;

  /// إحداثيات GPS بصيغة `lat,long` كما تُحفظ في Supabase.
  final String? locationCoordinates;

  final double? latitude;
  final double? longitude;

  /// معرّف عامل التوصيل — جاهز للربط لاحقاً بحسابات الدلفري.
  final String? deliveryDriverId;

  final List<CartItem> items;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final String? rejectionReason;
  final String? businessDayId;

  /// رقم تسلسلي داخل يوم العمل (1، 2، 3…) — null للطلبات القديمة.
  final int? businessDayOrderNumber;

  /// رقم العرض للزبون والكاشير — يومي إن وُجد، وإلا الرقم الداخلي المنسّق.
  String get displayOrderNumber {
    final daily = businessDayOrderNumber;
    if (daily != null && daily > 0) return '#$daily';
    return legacyFormattedOrderId;
  }

  /// سطر البطل في الفاتورة والواجهات.
  String get displayOrderHeroLabel => 'طلب رقم $displayOrderNumber';

  /// الرقم الداخلي من قاعدة البيانات — للسجلات والمسارات فقط.
  String get legacyFormattedOrderId {
    final digits = id.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '#000000';
    return '#${digits.padLeft(6, '0')}';
  }

  bool get hasLocation => latitude != null && longitude != null;

  String? get googleMapsUrl {
    if (!hasLocation) return null;
    return DeliveryCoordinates.googleMapsSearchUrl(
      latitude: latitude!,
      longitude: longitude!,
    );
  }

  bool get isPending =>
      status.trim().toLowerCase() == DeliveryOrderStatus.pending;

  bool get isRejected =>
      status.trim().toLowerCase() == DeliveryOrderStatus.rejected;

  bool get needsRejectionReason =>
      isRejected && (rejectionReason == null || rejectionReason!.trim().isEmpty);

  bool get isDelivering => status == DeliveryOrderStatus.delivering;

  bool get isDelivered => status == DeliveryOrderStatus.delivered;

  /// هل ينتمي الطلب للمطعم النشط (slug و/أو restaurant UUID)?
  bool matchesActiveTenant({
    required String activeSlug,
    String? activeRestaurantUuid,
  }) {
    return OrderTenantMatch.matches(
      this,
      activeSlug: activeSlug,
      activeRestaurantUuid: activeRestaurantUuid,
    );
  }

  factory DeliveryOrder.fromSupabase(
    Map<String, dynamic> row, {
    String? fallbackSlug,
    String? fallbackRestaurantId,
  }) {
    final data = Map<String, dynamic>.from(row);
    _applyRestaurantScopeFallback(
      data,
      fallbackSlug: fallbackSlug,
      fallbackRestaurantId: fallbackRestaurantId,
    );
    return DeliveryOrder.fromMap(
      data,
      id: data['id']?.toString() ?? '',
    );
  }

  /// يملأ slug أو restaurant_id الناقص قبل التحقق — للطلبات القديمة.
  static void applyRestaurantScopeFallback(
    Map<String, dynamic> data, {
    String? fallbackSlug,
    String? fallbackRestaurantId,
  }) {
    _applyRestaurantScopeFallback(
      data,
      fallbackSlug: fallbackSlug,
      fallbackRestaurantId: fallbackRestaurantId,
    );
  }

  static void _applyRestaurantScopeFallback(
    Map<String, dynamic> data, {
    String? fallbackSlug,
    String? fallbackRestaurantId,
  }) {
    if (ModelParseValidation.hasAnyValue(data, [
      'restaurant_id',
      'restaurantId',
      'slug',
    ])) {
      return;
    }

    final slug = fallbackSlug?.trim().toLowerCase();
    if (slug != null && slug.isNotEmpty) {
      data['slug'] = slug;
    }

    final restaurantId = fallbackRestaurantId?.trim();
    if (restaurantId != null && restaurantId.isNotEmpty) {
      data['restaurant_id'] = restaurantId;
    }

    if (!ModelParseValidation.hasAnyValue(data, [
      'restaurant_id',
      'restaurantId',
      'slug',
    ])) {
      data['slug'] = RestaurantIds.snackBurgerSlug;
    }
  }

  factory DeliveryOrder.fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) {
    _validateMandatoryFields(data, id: id);
    final rawItems = data['order_items'] ?? data['items'];
    final items = <CartItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map<String, dynamic>) {
          items.add(CartItem.fromMap(entry));
        } else if (entry is Map) {
          items.add(CartItem.fromMap(Map<String, dynamic>.from(entry)));
        }
      }
    }

    String? locationCoordinates;
    double? latitude;
    double? longitude;
    if (LocationFeatureFlags.enabled) {
      locationCoordinates = _readLocationCoordinates(data);
      final parsedCoords = DeliveryCoordinates.parse(locationCoordinates);
      latitude = (data['latitude'] as num?)?.toDouble() ??
          parsedCoords?.latitude;
      longitude = (data['longitude'] as num?)?.toDouble() ??
          parsedCoords?.longitude;
    }

    return DeliveryOrder(
      id: id.isNotEmpty ? id : (data['id']?.toString() ?? ''),
      restaurantId: _readString(data['restaurant_id'] ?? data['restaurantId']),
      slug: _readString(data['slug']),
      customerName: (data['customer_name'] ?? data['customerName'] ?? '')
          as String? ??
          '',
      customerPhone: (data['phone_number'] ?? data['customerPhone'] ?? '')
          as String? ??
          '',
      address: data['address'] as String? ?? '',
      locationCoordinates: locationCoordinates,
      latitude: latitude,
      longitude: longitude,
      deliveryDriverId: _readNullableString(
        data['delivery_driver_id'] ?? data['deliveryDriverId'],
      ),
      items: items,
      totalPrice: _readDouble(data['total_price'] ?? data['totalPrice']),
      status: _readStatus(data['status']),
      createdAt: parseModelDate(data['created_at'] ?? data['createdAt']),
      rejectionReason: _readNullableString(
        data['rejection_reason'] ?? data['rejectionReason'],
      ),
      businessDayId: _readNullableString(
        data['business_day_id'] ?? data['businessDayId'],
      ),
      businessDayOrderNumber: _readNullableInt(
        data['business_day_order_number'] ?? data['businessDayOrderNumber'],
      ),
    );
  }

  static void _validateMandatoryFields(
    Map<String, dynamic> data, {
    required String id,
  }) {
    final missing = ModelParseValidation.collectMissing(
      data,
      const {
        'customer_name': ['customer_name', 'customerName'],
        'phone_number': ['phone_number', 'customerPhone'],
        'address': ['address'],
        'status': ['status'],
        'created_at': ['created_at', 'createdAt'],
        'order_items': ['order_items', 'items'],
      },
    );
    final hasRestaurantScope = ModelParseValidation.hasAnyValue(data, [
          'restaurant_id',
          'restaurantId',
          'slug',
        ]);
    if (!hasRestaurantScope) {
      missing.insert(0, 'restaurant_id_or_slug');
    }
    if (ModelParseValidation.isMissing(id) &&
        ModelParseValidation.isMissing(data['id'])) {
      missing.insert(0, 'id');
    }
    ModelParseValidation.warnMissingFields(
      modelName: 'DeliveryOrder',
      source: data,
      missingFields: missing,
    );
  }
}

String? _readLocationCoordinates(Map<String, dynamic> data) {
  final raw = data['location_coordinates'] ?? data['locationCoordinates'];
  if (raw == null) return null;
  final value = raw.toString().trim();
  return value.isEmpty ? null : value;
}

String? _readNullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _readNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
}

String _readString(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

double _readDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

String _readStatus(dynamic raw) {
  if (raw == null) return DeliveryOrderStatus.pending;
  final normalized = raw.toString().trim().toLowerCase();
  return normalized.isEmpty ? DeliveryOrderStatus.pending : normalized;
}
