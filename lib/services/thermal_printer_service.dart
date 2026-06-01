import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/delivery_order_model.dart';
import 'receipt_escpos_printer.dart';

/// طباعة الفواتير — Windows: ESC/POS خام (CP864).
class ThermalPrinterService {
  Future<void> printOrderReceipt(DeliveryOrder order) async {
    if (kIsWeb) {
      debugPrint(
        'ThermalPrinterService: استخدم order_invoice_printer على الويب',
      );
      return;
    }

    if (!Platform.isWindows) {
      throw UnsupportedError(
        'الطباعة متاحة على Windows 11 فقط (ESC/POS RAW).',
      );
    }

    await ReceiptEscPosPrinter.printOrderReceipt(order);
  }
}
