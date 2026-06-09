import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/printer_config.dart';

/// يحفظ اسم الطابعة في مُجمّع Windows (إن اختلف عن الاسم الافتراضي).
abstract final class PrinterPreferences {
  static const _windowsPrinterKey = 'windows_spooler_printer_name';

  static Future<String> getWindowsPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_windowsPrinterKey)?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    return PrinterConfig.windowsSpoolerPrinterName;
  }

  static Future<void> setWindowsPrinterName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_windowsPrinterKey, name.trim());
  }
}
