/// حالات طلب التوصيل — جاهزة لربط عامل التوصيل لاحقاً.
abstract final class DeliveryOrderStatus {
  DeliveryOrderStatus._();

  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
  static const String delivering = 'delivering';
  static const String delivered = 'delivered';

  static const List<String> all = [
    pending,
    accepted,
    rejected,
    delivering,
    delivered,
  ];
}
