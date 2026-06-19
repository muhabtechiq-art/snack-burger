import '../../models/delivery_order_model.dart';
import '../config/business_day_runtime.dart';
import '../utils/business_day_scope.dart';

/// قواعد عرض الطلبات المرفوضة — يوم العمل المفتوح يدوياً.
abstract final class RejectedOrdersConfig {
  RejectedOrdersConfig._();

  /// هل يُعرض الطلب المرفوض ضمن يوم العمل المفتوح الحالي؟
  static bool isRejectedVisibleForCurrentBusinessDay(DeliveryOrder order) {
    final openId = BusinessDayRuntime.openBusinessDayId;
    if (openId == null || openId.isEmpty) return false;
    return BusinessDayScope.orderBelongsToBusinessDay(
      orderBusinessDayId: order.businessDayId,
      businessDayId: openId,
    );
  }

  /// للقوائم: غير المرفوض يمرّ. المرفوض يُعرض إن كان ضمن يوم العمل المفتوح.
  static bool isVisibleInOrdersList(DeliveryOrder order) {
    if (!order.isRejected) return true;
    return isRejectedVisibleForCurrentBusinessDay(order);
  }
}
