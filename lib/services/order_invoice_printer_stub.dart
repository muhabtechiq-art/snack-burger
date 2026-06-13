import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/utils/safe_execute.dart';
import '../models/delivery_order_model.dart';
import 'receipt_escpos_printer.dart';
import 'thermal_printer_service.dart';

/// طباعة الفاتورة — Windows: ESC/POS CP864 | غير ذلك: مسار قديم.
Future<bool> printOrderInvoice(DeliveryOrder order) async {
  return safeExecuteVoid(
    () async {
      if (kIsWeb) {
        throw UnsupportedError('استخدم مسار الويب لطباعة الفاتورة');
      }

      if (Platform.isWindows) {
        await ReceiptEscPosPrinter.printOrderReceipt(order);
        return;
      }

      await ThermalPrinterService().printOrderReceipt(order);
    },
    tag: 'printOrderInvoice',
  );
}
