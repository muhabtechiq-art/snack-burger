import 'dart:io';

import 'windows_printer_bridge.dart';

/// يرسل نص الفاتورة إلى مُجمّع Windows (RAW).
Future<void> sendReceiptText(String receiptText) async {
  if (!Platform.isWindows) {
    throw UnsupportedError(
      'الطباعة متاحة على Windows 11 فقط (Generic / Text Only).',
    );
  }
  await WindowsPrinterBridge.instance.printReceiptText(receiptText);
}
