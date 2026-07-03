import 'package:flutter/foundation.dart';

import '../core/config/printer_config.dart';
import '../models/delivery_order_model.dart';
import '../models/end_of_day_report_model.dart';
import 'printer_preferences.dart';
import 'receipt_escpos_builder.dart';
import 'win32_raw_printer.dart';

/// أهداف طباعة الطلب — كاشير ثم مطبخ.
@visibleForTesting
class OrderPrintTargets {
  const OrderPrintTargets({
    required this.cashier,
    required this.kitchen,
  });

  final String cashier;
  final String kitchen;

  bool get samePrinter =>
      cashier.trim().toLowerCase() == kitchen.trim().toLowerCase();
}

/// ما يُطبع من فاتورة الطلب — إعادة الطباعة أو قبول الطلب.
enum OrderReceiptPrintScope {
  cashierOnly,
  kitchenOnly,
  both,
}

/// طباعة ESC/POS خام (CP864) → WinSpooler RAW على Windows.
abstract final class ReceiptEscPosPrinter {
  static const _logTag = 'ReceiptEscPosPrinter';

  @visibleForTesting
  static bool printsCashier(OrderReceiptPrintScope scope) =>
      scope == OrderReceiptPrintScope.cashierOnly ||
      scope == OrderReceiptPrintScope.both;

  @visibleForTesting
  static bool printsKitchen(OrderReceiptPrintScope scope) =>
      scope == OrderReceiptPrintScope.kitchenOnly ||
      scope == OrderReceiptPrintScope.both;

  static Future<void> _printBuiltBytes(
    Future<List<int>> Function() buildBytes, {
    bool useDefaultPrinter = false,
    String? printerName,
  }) async {
    final bytes = await buildBytes();
    if (useDefaultPrinter) {
      await Win32RawPrinter.printRawBytesToDefault(bytes);
      return;
    }
    await Win32RawPrinter.printRawBytes(bytes, printerName: printerName);
  }

  /// يحلّ أسماء الطابعات من التفضيلات — fallback آمن بدون رمي أثناء الحل.
  @visibleForTesting
  static Future<OrderPrintTargets> resolveOrderPrinterTargets({
    Future<String> Function()? getWindowsPrinterName,
    Future<String> Function()? getCashierPrinterName,
    Future<String> Function()? getKitchenPrinterName,
    Future<List<String>> Function()? listPrinterNames,
  }) async {
    final readLegacy =
        getWindowsPrinterName ?? PrinterPreferences.getWindowsPrinterName;
    final readCashier =
        getCashierPrinterName ?? PrinterPreferences.getCashierPrinterName;
    final readKitchen =
        getKitchenPrinterName ?? PrinterPreferences.getKitchenPrinterName;

    final legacyPrinter = (await readLegacy()).trim();
    final cashierPrinter = (await readCashier()).trim();
    final kitchenPrinter = (await readKitchen()).trim();

    final installed = await _safeListInstalled(listPrinterNames);

    final resolvedCashier = _resolvePrinterTarget(
      label: 'cashier',
      preferred: cashierPrinter,
      fallbacks: <String>[
        legacyPrinter,
        PrinterConfig.windowsSpoolerPrinterName,
      ],
      installed: installed,
    );

    final resolvedKitchen = _resolvePrinterTarget(
      label: 'kitchen',
      preferred: kitchenPrinter,
      fallbacks: <String>[
        resolvedCashier,
        legacyPrinter,
        PrinterConfig.windowsSpoolerPrinterName,
      ],
      installed: installed,
    );

    debugPrint('$_logTag: legacy printer: ${_displayName(legacyPrinter)}');
    debugPrint('$_logTag: cashier printer: ${_displayName(cashierPrinter)}');
    debugPrint('$_logTag: kitchen printer: ${_displayName(kitchenPrinter)}');
    debugPrint('$_logTag: resolved cashier: $resolvedCashier');
    debugPrint('$_logTag: resolved kitchen: $resolvedKitchen');

    return OrderPrintTargets(
      cashier: resolvedCashier,
      kitchen: resolvedKitchen,
    );
  }

  static String _displayName(String name) =>
      name.isEmpty ? '(empty)' : name;

  static Future<List<String>> _safeListInstalled(
    Future<List<String>> Function()? listPrinterNames,
  ) async {
    try {
      return await (listPrinterNames ?? Win32RawPrinter.listPrinterNames)();
    } catch (error, stack) {
      debugPrint(
        '$_logTag: WARNING listPrinterNames failed during resolve: '
        '$error\n$stack',
      );
      return const [];
    }
  }

  @visibleForTesting
  static String resolvePrinterTarget({
    required String preferred,
    required List<String> fallbacks,
    required List<String> installed,
    String label = 'printer',
  }) {
    return _resolvePrinterTarget(
      label: label,
      preferred: preferred,
      fallbacks: fallbacks,
      installed: installed,
    );
  }

  static String _resolvePrinterTarget({
    required String label,
    required String preferred,
    required List<String> fallbacks,
    required List<String> installed,
  }) {
    final candidates = <String>[
      preferred,
      ...fallbacks,
    ].map((name) => name.trim()).where((name) => name.isNotEmpty).toList();

    if (candidates.isEmpty) {
      throw StateError(
        '$_logTag: no usable $label printer — all preferences are empty',
      );
    }

    if (installed.isNotEmpty) {
      for (final candidate in candidates) {
        final matched = _matchInstalledName(candidate, installed);
        if (matched != null) {
          if (matched != candidate) {
            debugPrint(
              '$_logTag: $label matched "$candidate" → installed "$matched"',
            );
          }
          return matched;
        }
      }
      debugPrint(
        '$_logTag: WARNING $label candidates not in installed list '
        '$installed — using ${installed.first}',
      );
      return installed.first;
    }

    debugPrint(
      '$_logTag: WARNING installed printer list unavailable — '
      'using $label preference "${candidates.first}" as-is',
    );
    return candidates.first;
  }

  static String? _matchInstalledName(String preferred, List<String> installed) {
    for (final name in installed) {
      if (name == preferred) return name;
    }
    final lower = preferred.toLowerCase();
    for (final name in installed) {
      if (name.toLowerCase().contains(lower)) return name;
    }
    return null;
  }

  static Future<void> printOrderReceipt(
    DeliveryOrder order, {
    OrderReceiptPrintScope scope = OrderReceiptPrintScope.both,
    String? restaurantDisplayName,
  }) async {
    final printCashier = printsCashier(scope);
    final printKitchen = printsKitchen(scope);
    if (!printCashier && !printKitchen) return;

    final targets = await resolveOrderPrinterTargets();

    if (printCashier && printKitchen && targets.samePrinter) {
      debugPrint(
        '$_logTag: Cashier and kitchen use same printer temporarily',
      );
    }

    if (printCashier) {
      debugPrint('$_logTag: Printing cashier to: ${targets.cashier}');
      await _printBuiltBytes(
        () => ReceiptEscPosBuilder.buildCashierReceiptBytes(
          order,
          restaurantDisplayName: restaurantDisplayName,
        ),
        printerName: targets.cashier,
      );
    }

    if (printKitchen) {
      debugPrint('$_logTag: Printing kitchen to: ${targets.kitchen}');
      try {
        await _printBuiltBytes(
          () => ReceiptEscPosBuilder.buildKitchenReceiptBytes(
            order,
            restaurantDisplayName: restaurantDisplayName,
          ),
          printerName: targets.kitchen,
        );
      } catch (error, stack) {
        debugPrint(
          '$_logTag: WARNING kitchen print failed (order not affected): '
          '$error\n$stack',
        );
        if (!printCashier) rethrow;
      }
    }
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
