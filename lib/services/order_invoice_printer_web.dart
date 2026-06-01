import '../models/delivery_order_model.dart';
import 'web_invoice_printer.dart';

/// طباعة الفاتورة من Flutter Web.
Future<void> printOrderInvoice(DeliveryOrder order) async {
  await printWebInvoice(order);
}
