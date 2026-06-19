import '../../models/business_day_order_stats.dart';
import '../../models/delivery_order_model.dart';
import '../../models/delivery_order_status.dart';

/// الحالات التي تُحتسب في مبيعات الإغلاق — لا تشمل `pending`.
const Set<String> closingCountableOrderStatuses = {
  DeliveryOrderStatus.accepted,
  DeliveryOrderStatus.preparing,
  DeliveryOrderStatus.delivering,
  DeliveryOrderStatus.delivered,
};

BusinessDayOrderStats aggregateBusinessDayOrders(List<DeliveryOrder> allOrders) {
  final pendingOrders = <DeliveryOrder>[];
  final closingOrders = <DeliveryOrder>[];

  for (final order in allOrders) {
    final status = order.status.trim().toLowerCase();
    if (status == DeliveryOrderStatus.pending) {
      pendingOrders.add(order);
    } else if (closingCountableOrderStatuses.contains(status)) {
      closingOrders.add(order);
    }
  }

  pendingOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  closingOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  var closingSales = 0.0;
  for (final order in closingOrders) {
    closingSales += order.totalPrice;
  }

  return BusinessDayOrderStats(
    allOrdersCount: allOrders.length,
    pendingOrdersCount: pendingOrders.length,
    closingCountableOrders: closingOrders.length,
    closingCountableSales: closingSales,
    pendingOrders: pendingOrders,
    closingOrders: closingOrders,
  );
}
