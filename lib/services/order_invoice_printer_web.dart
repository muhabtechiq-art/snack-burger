import '../core/utils/safe_execute.dart';
import '../models/delivery_order_model.dart';
import 'web_invoice_printer.dart';

/// طباعة الفاتورة من Flutter Web.
Future<bool> printOrderInvoice(
  DeliveryOrder order, {
  String? restaurantDisplayName,
}) async {
  return safeExecuteVoid(
    () => printWebInvoice(
      order,
      restaurantDisplayName: restaurantDisplayName,
    ),
    tag: 'printOrderInvoice',
  );
}
