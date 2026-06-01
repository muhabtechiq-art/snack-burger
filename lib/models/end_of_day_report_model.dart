/// ملخص تقرير إغلاق اليوم للمطعم.
class EndOfDayReport {
  const EndOfDayReport({
    required this.reportDate,
    required this.orderCount,
    required this.totalSales,
    required this.topProducts,
  });

  final DateTime reportDate;
  final int orderCount;
  final double totalSales;

  /// الأكثر طلباً — حتى 5 منتجات.
  final List<TopProductStat> topProducts;
}

/// إحصائية منتج ضمن تقرير الإغلاق.
class TopProductStat {
  const TopProductStat({
    required this.name,
    required this.quantity,
  });

  final String name;
  final int quantity;
}
