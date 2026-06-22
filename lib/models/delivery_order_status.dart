/// حالات طلب التوصيل — جاهزة لربط عامل التوصيل لاحقاً.
abstract final class DeliveryOrderStatus {
  DeliveryOrderStatus._();

  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String preparing = 'preparing';
  static const String rejected = 'rejected';
  static const String delivering = 'delivering';
  static const String delivered = 'delivered';

  /// حالات إضافية قد تُخزَّن في Supabase — تُعرض في «طلباتي».
  static const String ready = 'ready';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const List<String> all = [
    pending,
    accepted,
    preparing,
    ready,
    rejected,
    delivering,
    delivered,
    completed,
    cancelled,
  ];

  /// الحالات التي تُعرض في شاشة «طلباتي» (بدون فلترة إخفاء accepted).
  static const List<String> myOrdersTrackedStatuses = [
    pending,
    accepted,
    preparing,
    ready,
    delivering,
    delivered,
    completed,
    rejected,
    cancelled,
  ];
}
