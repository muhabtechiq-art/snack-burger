/// إعدادات عرض طلبات الزبون في شاشة «طلباتي».
abstract final class CustomerMyOrdersConfig {
  CustomerMyOrdersConfig._();

  /// المدة الزمنية التي تظهر خلالها الطلبات للزبون (الأقدم يُخفى).
  static const Duration visibleOrdersWindow = Duration(hours: 6);

  /// هل يُعرض الطلب للزبون وفق نافذة [visibleOrdersWindow]؟
  static bool isOrderVisibleToCustomer(
    DateTime createdAt, {
    DateTime? referenceTime,
  }) {
    final now = (referenceTime ?? DateTime.now()).toUtc();
    final created = createdAt.toUtc();
    return !created.isBefore(now.subtract(visibleOrdersWindow));
  }
}
