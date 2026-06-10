import '../../models/delivery_order_model.dart';

/// قواعد عرض وحذف الطلبات المرفوضة — اليوم المحلي فقط.
abstract final class RejectedOrdersConfig {
  RejectedOrdersConfig._();

  /// بداية اليوم المحلي (منتصف الليل).
  static DateTime localDayStart({DateTime? referenceTime}) {
    final local = (referenceTime ?? DateTime.now()).toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// هل أُنشئ الطلب في اليوم المحلي الحالي؟
  static bool isCreatedOnLocalDay(
    DateTime createdAt, {
    DateTime? referenceTime,
  }) {
    final created = createdAt.toLocal();
    final dayStart = localDayStart(referenceTime: referenceTime);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return !created.isBefore(dayStart) && created.isBefore(dayEnd);
  }

  /// للقوائم: غير المرفوض يمرّ. المرفوض يُعرض إن كان من اليوم فقط.
  static bool isVisibleInOrdersList(
    DeliveryOrder order, {
    DateTime? referenceTime,
  }) {
    if (!order.isRejected) return true;
    return isCreatedOnLocalDay(order.createdAt, referenceTime: referenceTime);
  }
}
