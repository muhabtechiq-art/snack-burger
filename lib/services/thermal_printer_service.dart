import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/delivery_order_model.dart';
import 'receipt_escpos_printer.dart';

/// طباعة الفواتير — Windows: ESC/POS خام (CP864).
class ThermalPrinterService {
  static const _logTag = 'ThermalPrinterService';

  Future<void> printOrderReceipt(DeliveryOrder order) async {
    if (_shouldSkipOnWeb()) return;

    _requireWindowsPlatform();
    await ReceiptEscPosPrinter.printOrderReceipt(order);
  }

  bool _shouldSkipOnWeb() {
    if (!kIsWeb) return false;
    debugPrint('$_logTag: استخدم order_invoice_printer على الويب');
    return true;
  }

  void _requireWindowsPlatform() {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'الطباعة متاحة على Windows 11 فقط (ESC/POS RAW).',
      );
    }
  }
}
