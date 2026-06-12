import '../core/config/location_feature_flags.dart';
import '../core/utils/delivery_coordinates.dart';
import '../core/utils/model_parse_validation.dart';
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

  factory DeliveryOrder.fromSupabase(Map<String, dynamic> row) {
    return DeliveryOrder.fromMap(
      row,
      id: row['id']?.toString() ?? '',
    );
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
      restaurantId: (data['restaurant_id'] ?? data['restaurantId'] ?? '')
          as String? ??
          '',
      slug: data['slug'] as String? ?? '',
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
    );
  }

  static void _validateMandatoryFields(
    Map<String, dynamic> data, {
    required String id,
  }) {
    final missing = ModelParseValidation.collectMissing(
      data,
      const {
        'restaurant_id': ['restaurant_id', 'restaurantId'],
        'customer_name': ['customer_name', 'customerName'],
        'phone_number': ['phone_number', 'customerPhone'],
        'address': ['address'],
        'status': ['status'],
        'created_at': ['created_at', 'createdAt'],
        'order_items': ['order_items', 'items'],
      },
    );
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
