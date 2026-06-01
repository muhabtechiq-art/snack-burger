import '../models/delivery_order_model.dart';
import '../models/end_of_day_report_model.dart';
import 'receipt_escpos_builder.dart';
import 'win32_raw_printer.dart';

/// طباعة ESC/POS خام (CP864) → WinSpooler RAW على Windows.
abstract final class ReceiptEscPosPrinter {
  static Future<void> printOrderReceipt(DeliveryOrder order) async {
    final bytes = await ReceiptEscPosBuilder.buildOrderReceiptBytes(order);
    await Win32RawPrinter.printRawBytes(bytes);
  }

  static Future<void> printTestReceipt() async {
    final bytes = await ReceiptEscPosBuilder.buildTestReceiptBytes();
    await Win32RawPrinter.printRawBytesToDefault(bytes);
  }

  static Future<void> printEndOfDayReport(EndOfDayReport report) async {
    final bytes = await ReceiptEscPosBuilder.buildEndOfDayReceiptBytes(report);
    await Win32RawPrinter.printRawBytes(bytes);
  }
}
