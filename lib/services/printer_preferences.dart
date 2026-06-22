import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/printer_config.dart';

/// يحفظ أسماء الطابعات في مُجمّع Windows — legacy + كاشير/مطبخ منفصلان.
abstract final class PrinterPreferences {
  static const _windowsPrinterKey = 'windows_spooler_printer_name';
  static const _cashierPrinterKey = 'windows_cashier_printer_name';
  static const _kitchenPrinterKey = 'windows_kitchen_printer_name';

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

  static Future<String> getCashierPrinterName() async {
    return _resolveRolePrinterName(_cashierPrinterKey);
  }

  static Future<void> setCashierPrinterName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cashierPrinterKey, name.trim());
  }

  static Future<String> getKitchenPrinterName() async {
    return _resolveRolePrinterName(_kitchenPrinterKey);
  }

  static Future<void> setKitchenPrinterName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kitchenPrinterKey, name.trim());
  }

  /// مفتاح الدور → legacy → [PrinterConfig.windowsSpoolerPrinterName].
  static Future<String> _resolveRolePrinterName(String roleKey) async {
    final prefs = await SharedPreferences.getInstance();
    final roleSaved = prefs.getString(roleKey)?.trim();
    if (roleSaved != null && roleSaved.isNotEmpty) return roleSaved;

    final legacy = prefs.getString(_windowsPrinterKey)?.trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;

    return PrinterConfig.windowsSpoolerPrinterName;
  }
}
