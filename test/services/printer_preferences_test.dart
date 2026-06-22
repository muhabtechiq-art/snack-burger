import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snack_burger/core/config/printer_config.dart';
import 'package:snack_burger/services/printer_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('PrinterPreferences.getWindowsPrinterName', () {
    test('returns legacy key when set', () async {
      SharedPreferences.setMockInitialValues({
        'windows_spooler_printer_name': 'Legacy Printer',
      });

      expect(
        await PrinterPreferences.getWindowsPrinterName(),
        'Legacy Printer',
      );
    });

    test('returns PrinterConfig default when legacy empty', () async {
      expect(
        await PrinterPreferences.getWindowsPrinterName(),
        PrinterConfig.windowsSpoolerPrinterName,
      );
    });
  });

  group('PrinterPreferences.getCashierPrinterName', () {
    test('returns cashier key when set', () async {
      SharedPreferences.setMockInitialValues({
        'windows_cashier_printer_name': 'Cashier POS',
        'windows_spooler_printer_name': 'Legacy Printer',
      });

      expect(
        await PrinterPreferences.getCashierPrinterName(),
        'Cashier POS',
      );
    });

    test('falls back to legacy key when cashier key empty', () async {
      SharedPreferences.setMockInitialValues({
        'windows_spooler_printer_name': 'Legacy Printer',
      });

      expect(
        await PrinterPreferences.getCashierPrinterName(),
        'Legacy Printer',
      );
    });

    test('falls back to PrinterConfig when all keys empty', () async {
      expect(
        await PrinterPreferences.getCashierPrinterName(),
        PrinterConfig.windowsSpoolerPrinterName,
      );
    });
  });

  group('PrinterPreferences.getKitchenPrinterName', () {
    test('returns kitchen key when set', () async {
      SharedPreferences.setMockInitialValues({
        'windows_kitchen_printer_name': 'Kitchen POS',
        'windows_spooler_printer_name': 'Legacy Printer',
      });

      expect(
        await PrinterPreferences.getKitchenPrinterName(),
        'Kitchen POS',
      );
    });

    test('falls back to legacy key when kitchen key empty', () async {
      SharedPreferences.setMockInitialValues({
        'windows_spooler_printer_name': 'Legacy Printer',
      });

      expect(
        await PrinterPreferences.getKitchenPrinterName(),
        'Legacy Printer',
      );
    });
  });

  group('PrinterPreferences setters', () {
    test('setCashierPrinterName persists role key', () async {
      await PrinterPreferences.setCashierPrinterName('  Cashier A  ');

      expect(
        await PrinterPreferences.getCashierPrinterName(),
        'Cashier A',
      );
    });

    test('setKitchenPrinterName persists role key', () async {
      await PrinterPreferences.setKitchenPrinterName('Kitchen B');

      expect(
        await PrinterPreferences.getKitchenPrinterName(),
        'Kitchen B',
      );
    });
  });
}
