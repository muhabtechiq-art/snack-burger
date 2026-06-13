import '../models/delivery_order_model.dart';
import 'order_invoice_printer_stub.dart'
    if (dart.library.html) 'order_invoice_printer_web.dart' as impl;

/// واجهة موحّدة للطباعة — ويب أو أندroid حسب المنصة.
/// يُرجع `true` عند نجاح الإرسال للطباعة.
Future<bool> printOrderInvoice(DeliveryOrder order) =>
    impl.printOrderInvoice(order);
