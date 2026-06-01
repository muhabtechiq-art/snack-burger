import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:windows_printer/windows_printer.dart';

import '../core/config/printer_config.dart';
import 'printer_preferences.dart';

/// طباعة RAW عبر WinSpooler — `WindowsPrinter.printRawData` (win32).
abstract final class Win32RawPrinter {
  /// يرسل بايتات ESC/POS إلى الطابعة الافتراضية في Windows (RAW datatype).
  static Future<void> printRawBytesToDefault(List<int> bytes) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('الطباعة الخام متاحة على Windows فقط.');
    }

    final defaultName = await getDefaultPrinterName();
    debugPrint(
      '[Win32RawPrinter] printRawData → default printer'
      '${defaultName != null ? ' ("$defaultName")' : ''} '
      'bytes=${bytes.length} useRawDatatype=true',
    );

    try {
      final success = await WindowsPrinter.printRawData(
        printerName: null,
        data: Uint8List.fromList(bytes),
        useRawDatatype: true,
      );

      if (!success) {
        const message =
            '[Win32RawPrinter] فشلت الطباعة: printRawData أرجع false '
            'للطابعة الافتراضية';
        debugPrint(message);
        throw StateError('فشل إرسال البيانات RAW إلى الطابعة الافتراضية');
      }

      debugPrint(
        '[Win32RawPrinter] نجحت الطباعة → default'
        '${defaultName != null ? ' ("$defaultName")' : ''}',
      );
    } catch (e, stack) {
      final message =
          '[Win32RawPrinter] خطأ طباعة RAW → default printer: $e\n$stack';
      debugPrint(message);
      rethrow;
    }
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
    if (!Platform.isWindows) {
      throw UnsupportedError('الطباعة الخام متاحة على Windows فقط.');
    }

    final name = (printerName ?? await PrinterPreferences.getWindowsPrinterName())
        .trim();
    if (name.isEmpty) {
      const message = '[Win32RawPrinter] اسم الطابعة فارغ';
      debugPrint(message);
      throw StateError('لم يُحدَّد اسم الطابعة في الإعدادات.');
    }

    debugPrint(
      '[Win32RawPrinter] printRawData → printer="$name" '
      'bytes=${bytes.length} useRawDatatype=true',
    );

    try {
      final success = await WindowsPrinter.printRawData(
        printerName: name,
        data: Uint8List.fromList(bytes),
        useRawDatatype: true,
      );

      if (!success) {
        final message =
            '[Win32RawPrinter] فشلت الطباعة: printRawData أرجع false '
            'للطابعة "$name" (${bytes.length} bytes)';
        debugPrint(message);
        throw StateError('فشل إرسال البيانات RAW إلى الطابعة "$name"');
      }

      debugPrint('[Win32RawPrinter] نجحت الطباعة → "$name"');
    } catch (e, stack) {
      final message =
          '[Win32RawPrinter] خطأ طباعة RAW → printer="$name": $e\n$stack';
      debugPrint(message);
      rethrow;
    }
  }

  static Future<List<String>> listPrinterNames() async {
    if (!Platform.isWindows) return const [];

    try {
      final names = await WindowsPrinter.getAvailablePrinters();
      debugPrint('[Win32RawPrinter] printers (${names.length}): $names');
      return names;
    } catch (e, stack) {
      final message = '[Win32RawPrinter] listPrinterNames failed: $e\n$stack';
      debugPrint(message);
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
