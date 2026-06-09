import '../models/delivery_order_model.dart';
import '../models/end_of_day_report_model.dart';
import 'receipt_escpos_builder.dart';
import 'win32_raw_printer.dart';

/// طباعة ESC/POS خام (CP864) → WinSpooler RAW على Windows.
abstract final class ReceiptEscPosPrinter {
  static Future<void> _printBuiltBytes(
    Future<List<int>> Function() buildBytes, {
    bool useDefaultPrinter = false,
  }) async {
    final bytes = await buildBytes();
    if (useDefaultPrinter) {
      await Win32RawPrinter.printRawBytesToDefault(bytes);
      return;
    }
    await Win32RawPrinter.printRawBytes(bytes);
  }

  static Future<void> printOrderReceipt(DeliveryOrder order) async {
    await _printBuiltBytes(
      () => ReceiptEscPosBuilder.buildOrderReceiptBytes(order),
    );
  }

  static Future<void> printTestReceipt() async {
    await _printBuiltBytes(
      ReceiptEscPosBuilder.buildTestReceiptBytes,
      useDefaultPrinter: true,
    );
  }

  static Future<void> printEndOfDayReport(EndOfDayReport report) async {
    await _printBuiltBytes(
      () => ReceiptEscPosBuilder.buildEndOfDayReceiptBytes(report),
    );
  }
}
