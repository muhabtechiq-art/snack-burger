import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/core/config/printer_config.dart';
import 'package:snack_burger/services/receipt_escpos_printer.dart';

void main() {
  group('OrderPrintTargets.samePrinter', () {
    test('true when names match ignoring case', () {
      const targets = OrderPrintTargets(
        cashier: 'Generic / Text Only',
        kitchen: 'generic / text only',
      );

      expect(targets.samePrinter, isTrue);
    });

    test('false when names differ', () {
      const targets = OrderPrintTargets(
        cashier: 'Cashier POS',
        kitchen: 'Kitchen POS',
      );

      expect(targets.samePrinter, isFalse);
    });
  });

  group('OrderReceiptPrintScope', () {
    test('both prints cashier and kitchen', () {
      expect(
        ReceiptEscPosPrinter.printsCashier(OrderReceiptPrintScope.both),
        isTrue,
      );
      expect(
        ReceiptEscPosPrinter.printsKitchen(OrderReceiptPrintScope.both),
        isTrue,
      );
    });

    test('cashierOnly prints cashier only', () {
      expect(
        ReceiptEscPosPrinter.printsCashier(OrderReceiptPrintScope.cashierOnly),
        isTrue,
      );
      expect(
        ReceiptEscPosPrinter.printsKitchen(OrderReceiptPrintScope.cashierOnly),
        isFalse,
      );
    });

    test('kitchenOnly prints kitchen only', () {
      expect(
        ReceiptEscPosPrinter.printsCashier(OrderReceiptPrintScope.kitchenOnly),
        isFalse,
      );
      expect(
        ReceiptEscPosPrinter.printsKitchen(OrderReceiptPrintScope.kitchenOnly),
        isTrue,
      );
    });
  });

  group('ReceiptEscPosPrinter.resolvePrinterTarget', () {
    test('cashier falls back to legacy when preferred not installed', () {
      final resolved = ReceiptEscPosPrinter.resolvePrinterTarget(
        label: 'cashier',
        preferred: 'Missing Cashier',
        fallbacks: const ['Legacy POS', PrinterConfig.windowsSpoolerPrinterName],
        installed: const ['Legacy POS'],
      );

      expect(resolved, 'Legacy POS');
    });

    test('kitchen falls back to resolved cashier when preferred not installed',
        () {
      final resolved = ReceiptEscPosPrinter.resolvePrinterTarget(
        label: 'kitchen',
        preferred: 'Missing Kitchen',
        fallbacks: const ['Cashier POS', 'Legacy POS'],
        installed: const ['Cashier POS', 'Legacy POS'],
      );

      expect(resolved, 'Cashier POS');
    });

    test('uses preference as-is when installed list unavailable', () {
      final resolved = ReceiptEscPosPrinter.resolvePrinterTarget(
        label: 'cashier',
        preferred: 'Generic / Text Only',
        fallbacks: const [],
        installed: const [],
      );

      expect(resolved, 'Generic / Text Only');
    });
  });

  group('ReceiptEscPosPrinter.resolveOrderPrinterTargets', () {
    test('resolves cashier and kitchen from installed printers', () async {
      final targets = await ReceiptEscPosPrinter.resolveOrderPrinterTargets(
        getWindowsPrinterName: () async => 'Legacy POS',
        getCashierPrinterName: () async => 'Cashier A',
        getKitchenPrinterName: () async => 'Kitchen B',
        listPrinterNames: () async => ['Cashier A', 'Kitchen B', 'Legacy POS'],
      );

      expect(targets.cashier, 'Cashier A');
      expect(targets.kitchen, 'Kitchen B');
      expect(targets.samePrinter, isFalse);
    });

    test('kitchen uses cashier when kitchen name not installed', () async {
      final targets = await ReceiptEscPosPrinter.resolveOrderPrinterTargets(
        getWindowsPrinterName: () async => 'Legacy POS',
        getCashierPrinterName: () async => 'Legacy POS',
        getKitchenPrinterName: () async => 'Missing Kitchen',
        listPrinterNames: () async => ['Legacy POS'],
      );

      expect(targets.cashier, 'Legacy POS');
      expect(targets.kitchen, 'Legacy POS');
      expect(targets.samePrinter, isTrue);
    });

    test('continues when listPrinterNames fails', () async {
      final targets = await ReceiptEscPosPrinter.resolveOrderPrinterTargets(
        getWindowsPrinterName: () async => 'Legacy POS',
        getCashierPrinterName: () async => 'Legacy POS',
        getKitchenPrinterName: () async => 'Legacy POS',
        listPrinterNames: () async {
          throw StateError('spooler unavailable');
        },
      );

      expect(targets.cashier, 'Legacy POS');
      expect(targets.kitchen, 'Legacy POS');
    });
  });
}
