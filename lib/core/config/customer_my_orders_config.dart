/// إعدادات عرض طلبات الزبون في شاشة «طلباتي».
abstract final class CustomerMyOrdersConfig {
  CustomerMyOrdersConfig._();

  /// المدة الزمنية التي تظهر خلالها الطلبات للزبون (الأقدم يُخفى).
  static const Duration visibleOrdersWindow = Duration(hours: 6);

  /// رسالة عدم وجود طلبات ضمن نافذة العرض.
  static const String emptyOrdersMessage =
      'لا توجد طلبات خلال آخر 6 ساعة لهذا الرقم.\n'
      'الطلبات الأقدم لا تظهر هنا.';

  /// هل يُعرض الطلب للزبون وفق نافذة [visibleOrdersWindow]؟
  static bool isOrderVisibleToCustomer(
    DateTime createdAt, {
    DateTime? referenceTime,
  }) {
    final now = (referenceTime ?? DateTime.now()).toUtc();
    final created = createdAt.toUtc();
    return !created.isBefore(now.subtract(visibleOrdersWindow));
  }

  /// أقصى عدد صفوف يُجلب من Supabase قبل الفلترة المحلية.
  static const int fetchRowCap = 80;
}
