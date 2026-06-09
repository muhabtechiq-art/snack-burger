import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/config/printer_config.dart';
import 'win32_raw_printer.dart';

/// جسر طباعة Windows — قائمة الطابعات + RAW عبر Win32RawPrinter.
class WindowsPrinterBridge {
  WindowsPrinterBridge._();

  static final WindowsPrinterBridge instance = WindowsPrinterBridge._();
  static const _logTag = 'WindowsPrinterBridge';

  static final _utf8 = utf8;

  static void _requireWindows() {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows spooler only');
    }
  }

  static Future<List<WindowsPrinterInfo>> logInstalledPrintersToConsole() async {
    final printers = await instance.listInstalledPrinters();
    debugPrint('');
    debugPrint(
      '========== Windows spooler printers (${printers.length}) ==========',
    );
    for (var i = 0; i < printers.length; i++) {
      final p = printers[i];
      debugPrint('[$i] name="${p.name}" | driver="${p.driverModel}"');
    }
    debugPrint('================================================================');
    debugPrint('');
    return printers;
  }

  Future<WindowsPrinterInfo> detectGenericTextOnlyPrinter() async {
    final target = PrinterConfig.windowsSpoolerPrinterName;
    final match = await findPrinterBySystemName(target);
    if (match == null) {
      throw StateError(
        'Printer "$target" not found. '
        'Run logInstalledPrintersToConsole() and verify the exact system name.',
      );
    }
    return match;
  }

  Future<WindowsPrinterInfo?> findPrinterBySystemName(String systemName) async {
    final printers = await listInstalledPrinters();
    if (printers.isEmpty) return null;

    final exact = systemName.trim();
    for (final p in printers) {
      if (p.name == exact) return p;
    }

    final lower = exact.toLowerCase();
    return printers
        .where((p) => p.name.toLowerCase().contains(lower))
        .firstOrNull;
  }

  Future<List<WindowsPrinterInfo>> listInstalledPrinters() async {
    if (!Platform.isWindows) return [];

    final names = await Win32RawPrinter.listPrinterNames();
    return names
        .map(
          (name) => WindowsPrinterInfo(
            name: name,
            driverModel: '',
            isDefault: false,
          ),
        )
        .toList();
  }

  Future<void> printReceiptText(String receiptText) async {
    final name = await _resolvedPrinterSystemName();
    await directPrintRaw(
      printerSystemName: name,
      bytes: _encodeReceiptText(receiptText),
    );
  }

  Future<void> directPrintRaw({
    required String printerSystemName,
    required List<int> bytes,
  }) async {
    _requireWindows();

    final name = printerSystemName.trim();
    if (name.isEmpty) throw ArgumentError('printerSystemName is empty');

    debugPrint('$_logTag: delegating RAW → Win32RawPrinter ("$name")');
    await Win32RawPrinter.printRawBytes(bytes, printerName: name);
  }

  static Future<void> printTestReceiptToGeneric() async {
    await logInstalledPrintersToConsole();
    final printer = await instance.detectGenericTextOnlyPrinter();
    debugPrint('Printing to: "${printer.name}"');
    debugPrint('Use ReceiptEscPosPrinter.printTestReceipt() for ESC/POS bytes.');
  }

  List<int> _encodeReceiptText(String receiptText) {
    final normalized =
        receiptText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final withCrlf =
        normalized.split('\n').map((line) => '$line\r\n').join();

    return <int>[
      0x1B, 0x40,
      ..._utf8.encode(withCrlf),
      0x0A,
      0x0A,
      0x1D, 0x56, 0x00,
    ];
  }

  Future<String> _resolvedPrinterSystemName() async {
    return Win32RawPrinter.resolvePrinterName();
  }
}

class WindowsPrinterInfo {
  const WindowsPrinterInfo({
    required this.name,
    required this.driverModel,
    required this.isDefault,
  });

  final String name;
  final String driverModel;
  final bool isDefault;
}
