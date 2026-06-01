import 'win32_raw_printer.dart';

/// @deprecated استخدم [Win32RawPrinter] — يُحافظ على التوافق مع الاستدعاءات القديمة.
abstract final class UsbRawPrinter {
  static Future<void> sendEscPosBytes(List<int> bytes) {
    return Win32RawPrinter.printRawBytes(bytes);
  }
}
