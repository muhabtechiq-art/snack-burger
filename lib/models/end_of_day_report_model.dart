import 'delivery_order_model.dart';

/// ملخص تقرير إغلاق اليوم للمطعم.
class EndOfDayReport {  const EndOfDayReport({
    required this.reportDate,
    required this.orderCount,
    required this.totalSales,
    required this.productLines,
    required this.orders,
  });

  final DateTime reportDate;
  final int orderCount;
  final double totalSales;

  /// كل المنتجات المباعة خلال اليوم (بدون حد أقصى).
  final List<ClosingProductLine> productLines;

  /// الطلبات الكاملة لليوم — للأرشيف والعرض التفصيلي.
  final List<DeliveryOrder> orders;
}

/// صف منتج في تقرير الإغلاق.
class ClosingProductLine {
  const ClosingProductLine({
    required this.productName,
    required this.quantitySold,
    required this.unitPrice,
  });

  final String productName;
  final int quantitySold;
  final double unitPrice;

  double get lineTotal => quantitySold * unitPrice;
}
