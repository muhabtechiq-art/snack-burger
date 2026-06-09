import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:windows_printer/windows_printer.dart';

import '../core/config/printer_config.dart';
import 'printer_preferences.dart';

/// طباعة RAW عبر WinSpooler — `WindowsPrinter.printRawData` (win32).
abstract final class Win32RawPrinter {
  static const _logTag = 'Win32RawPrinter';

  static void _log(String message, {Object? error, StackTrace? stack}) {
    if (error == null) {
      debugPrint('$_logTag: $message');
      return;
    }
    debugPrint('$_logTag: $message\n$error${stack != null ? '\n$stack' : ''}');
  }

  static void _requireWindows() {
    if (!Platform.isWindows) {
      throw UnsupportedError('الطباعة الخام متاحة على Windows فقط.');
    }
  }

  static Future<void> _sendRawData({
    required List<int> bytes,
    required String targetDescription,
    String? printerName,
  }) async {
    _requireWindows();

    _log(
      'printRawData → $targetDescription '
      'bytes=${bytes.length} useRawDatatype=true',
    );

    try {
      final success = await WindowsPrinter.printRawData(
        printerName: printerName,
        data: Uint8List.fromList(bytes),
        useRawDatatype: true,
      );

      if (!success) {
        _log('فشلت الطباعة: printRawData أرجع false → $targetDescription');
        throw StateError(
          printerName == null
              ? 'فشل إرسال البيانات RAW إلى الطابعة الافتراضية'
              : 'فشل إرسال البيانات RAW إلى الطابعة "$printerName"',
        );
      }

      _log('نجحت الطباعة → $targetDescription');
    } catch (e, stack) {
      _log('خطأ طباعة RAW → $targetDescription', error: e, stack: stack);
      rethrow;
    }
  }

  /// يرسل بايتات ESC/POS إلى الطابعة الافتراضية في Windows (RAW datatype).
  static Future<void> printRawBytesToDefault(List<int> bytes) async {
    final defaultName = await getDefaultPrinterName();
    final description = defaultName == null
        ? 'default printer'
        : 'default printer ("$defaultName")';

    await _sendRawData(
      bytes: bytes,
      targetDescription: description,
    );
  }

  /// اسم الطابعة الافتراضية في Windows (إن وُجدت).
  static Future<String?> getDefaultPrinterName() async {
    if (!Platform.isWindows) return null;

    final names = await listPrinterNames();
    for (final name in names) {
      final props = await WindowsPrinter.getPrinterProperties(name);
      if (props['isDefault'] == true) return name;
    }
    return null;
  }

  /// يرسل بايتات ESC/POS إلى اسم الطابعة في Windows (RAW datatype).
  static Future<void> printRawBytes(List<int> bytes, {String? printerName}) async {
    final name = (printerName ?? await PrinterPreferences.getWindowsPrinterName())
        .trim();
    if (name.isEmpty) {
      _log('اسم الطابعة فارغ');
      throw StateError('لم يُحدَّد اسم الطابعة في الإعدادات.');
    }

    await _sendRawData(
      bytes: bytes,
      printerName: name,
      targetDescription: 'printer="$name"',
    );
  }

  static Future<List<String>> listPrinterNames() async {
    if (!Platform.isWindows) return const [];

    try {
      final names = await WindowsPrinter.getAvailablePrinters();
      _log('printers (${names.length}): $names');
      return names;
    } catch (e, stack) {
      _log('listPrinterNames failed', error: e, stack: stack);
      rethrow;
    }
  }

  /// يطابق الاسم المفضّل مع قائمة النظام أو يُرجع الافتراضي.
  static Future<String> resolvePrinterName({String? preferred}) async {
    final target = (preferred ?? await PrinterPreferences.getWindowsPrinterName())
        .trim();
    if (target.isEmpty) {
      return PrinterConfig.windowsSpoolerPrinterName;
    }

    final installed = await listPrinterNames();
    for (final name in installed) {
      if (name == target) return name;
    }
    final lower = target.toLowerCase();
    for (final name in installed) {
      if (name.toLowerCase().contains(lower)) return name;
    }

    if (installed.isNotEmpty) return installed.first;
    return target;
  }
}
