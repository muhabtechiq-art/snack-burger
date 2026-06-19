import '../core/config/printer_config.dart';
import '../models/delivery_order_model.dart';
import '../models/order_model.dart';
import 'receipt_cashier_layout.dart';

/// بناء فاتورة **نصية** لطابعات Generic / Text Only (مُجمّع Windows RAW).
///
/// عرض ~42 حرفاً لورق 80mm — مناسب لصفحة اختبار Windows.
abstract final class ReceiptTextBuilder {
  static int get lineWidth => ReceiptCashierLayout.lineWidth;

  static String buildCashierReceipt(DeliveryOrder order) {
    final plan = ReceiptCashierLayout.buildPrintPlan(order);
    final buffer = StringBuffer();

    for (final line in plan.beforeQr) {
      _writeLine(buffer, line);
      if (line.style == ReceiptLineStyle.customerTime &&
          order.latitude != null &&
          order.longitude != null) {
        buffer.writeln(
          'GPS: ${order.latitude!.toStringAsFixed(5)}, '
          '${order.longitude!.toStringAsFixed(5)}',
        );
      }
    }

    for (final line in plan.afterQr) {
      _writeLine(buffer, line);
    }

    return buffer.toString();
  }

  static void _writeLine(StringBuffer buffer, ReceiptCashierLine line) {
    if (line.isTable) {
      buffer.writeln(
        ReceiptCashierLayout.formatReceiptRow(
          product: line.product!,
          quantity: line.quantity!,
          price: line.price!,
        ),
      );
      return;
    }
    final text = line.text?.trim() ?? '';
    if (text.isEmpty) return;
    buffer.writeln(line.center ? ReceiptCashierLayout.centerText(text) : text);
  }

  static String buildKitchenReceipt(DeliveryOrder order) {
    final local = order.createdAt.toLocal();
    final buffer = StringBuffer()
      ..writeln(_center(PrinterConfig.restaurantDisplayName))
      ..writeln(_center('*** KITCHEN ***'))
      ..writeln(_separator())
      ..writeln('Customer: ${order.customerName}')
      ..writeln('Order:    ${order.displayOrderHeroLabel}')
      ..writeln('Date:     ${ReceiptCashierLayout.formatDate(local)}')
      ..writeln('Time:     ${ReceiptCashierLayout.formatTime12h(local)}')
      ..writeln(_separator());

    for (final item in order.items) {
      for (final line in ReceiptKitchenLayout.itemLines(
        quantity: item.quantity,
        name: item.displayName,
      )) {
        buffer.writeln(line);
      }
      for (final addon in item.selectedAddons) {
        for (final line in ReceiptKitchenLayout.addonLines(
          quantity: addon.quantity,
          name: addon.name,
        )) {
          buffer.writeln(line);
        }
      }
    }

    buffer
      ..writeln(_separator())
      ..writeln(_center('--- END ---'));

    return buffer.toString();
  }

  static String _separator() => ReceiptCashierLayout.separator(width: lineWidth);

  static String _center(String text) =>
      ReceiptCashierLayout.centerText(text, width: lineWidth);

  /// سطر تفاصيل المنتج — يفوّض إلى [ReceiptCashierLayout].
  static String formatCashierItemLine(CartItem item) =>
      ReceiptCashierLayout.itemLines(item).first;
}
