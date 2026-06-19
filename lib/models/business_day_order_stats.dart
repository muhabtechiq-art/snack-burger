import 'delivery_order_model.dart';

/// إحصائيات طلبات يوم عمل واحد — مصدر موحّد للوحة التحكم وشاشة يوم العمل.
class BusinessDayOrderStats {
  const BusinessDayOrderStats({
    required this.allOrdersCount,
    required this.pendingOrdersCount,
    required this.closingCountableOrders,
    required this.closingCountableSales,
    required this.pendingOrders,
    required this.closingOrders,
  });

  /// كل الطلبات المرتبطة بـ `business_day_id` (كل الحالات).
  final int allOrdersCount;

  /// الطلبات ذات الحالة `pending` لنفس يوم العمل.
  final int pendingOrdersCount;

  /// الطلبات المحتسبة في المبيعات (`accepted` / `preparing` / `delivering` / `delivered`).
  final int closingCountableOrders;

  /// مجموع `total_price` للطلبات المحتسبة فقط.
  final double closingCountableSales;

  final List<DeliveryOrder> pendingOrders;
  final List<DeliveryOrder> closingOrders;
}
