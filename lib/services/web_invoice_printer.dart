import 'package:flutter/foundation.dart';

import '../models/delivery_order_model.dart';
import 'web_invoice_printer_stub.dart'
    if (dart.library.html) 'web_invoice_printer_web.dart' as impl;

/// طباعة فاتورة HTML من Flutter Web (Generic / Text Only عبر نافذة المتصفح).
Future<void> printWebInvoice(DeliveryOrder order) async {
  if (!kIsWeb) {
    throw UnsupportedError(
      'printWebInvoice is only supported on Flutter Web',
    );
  }
  await impl.printWebInvoice(order);
}
