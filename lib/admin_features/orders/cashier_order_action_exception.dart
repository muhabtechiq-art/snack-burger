/// استثناء قبول/رفض الطلب برسالة مفهومة للمستخدم.
class CashierOrderActionException implements Exception {
  const CashierOrderActionException(this.userMessage, {this.cause});

  final String userMessage;
  final Object? cause;

  @override
  String toString() => userMessage;
}
