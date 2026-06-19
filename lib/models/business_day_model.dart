/// حالة يوم العمل اليدوي.
abstract final class BusinessDayStatus {
  BusinessDayStatus._();

  static const String open = 'open';
  static const String closed = 'closed';
}

/// سجل يوم عمل — جدول `business_days` في Supabase.
class BusinessDayModel {
  const BusinessDayModel({
    required this.id,
    required this.restaurantId,
    required this.slug,
    required this.status,
    required this.openedAt,
    this.closedAt,
    this.openedBy,
    this.closedBy,
    this.notes,
    this.closedOrderCount,
    this.closedTotalSales,
  });

  final String id;
  final String restaurantId;
  final String slug;
  final String status;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? openedBy;
  final String? closedBy;
  final String? notes;
  final int? closedOrderCount;
  final double? closedTotalSales;

  bool get isOpen => status == BusinessDayStatus.open;
  bool get isClosed => status == BusinessDayStatus.closed;

  factory BusinessDayModel.fromMap(Map<String, dynamic> map) {
    return BusinessDayModel(
      id: map['id']?.toString() ?? '',
      restaurantId: map['restaurant_id']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      status: map['status']?.toString() ?? BusinessDayStatus.closed,
      openedAt: DateTime.parse(map['opened_at'].toString()).toLocal(),
      closedAt: map['closed_at'] == null
          ? null
          : DateTime.parse(map['closed_at'].toString()).toLocal(),
      openedBy: map['opened_by']?.toString(),
      closedBy: map['closed_by']?.toString(),
      notes: map['notes']?.toString(),
      closedOrderCount: _readInt(map['closed_order_count']),
      closedTotalSales: _readDouble(map['closed_total_sales']),
    );
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
