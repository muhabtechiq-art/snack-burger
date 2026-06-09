import '../core/config/printer_config.dart';
import '../models/delivery_order_model.dart';
import '../models/order_model.dart';
import 'receipt_cashier_layout.dart';

/// بناء فاتورة **نصية** لطابعات Generic / Text Only (مُجمّع Windows RAW).
///
/// عرض ~42 حرفاً لورق 80mm — مناسب لصفحة اختبار Windows.
abstract final class ReceiptTextBuilder {
  static const int lineWidth = 42;

  static String buildCashierReceipt(DeliveryOrder order) {
    final local = order.createdAt.toLocal();
    final dateStr = _formatDateTime(local);
    final buffer = StringBuffer()
      ..writeln(_center(PrinterConfig.restaurantDisplayName))
      ..writeln(_center('CASHIER RECEIPT'))
      ..writeln(_separator())
      ..writeln('Customer: ${order.customerName}')
      ..writeln('Phone:    ${order.customerPhone}')
      ..writeln('Address:  ${_wrap(order.address)}')
      ..writeln('Time:     $dateStr');

    if (order.latitude != null && order.longitude != null) {
      buffer.writeln(
        'GPS: ${order.latitude!.toStringAsFixed(5)}, '
        '${order.longitude!.toStringAsFixed(5)}',
      );
    }

    buffer
      ..writeln(_separator())
      ..writeln(ReceiptCashierLayout.tableHeader())
      ..writeln(_separator());

    for (final item in order.items) {
      buffer.writeln(ReceiptCashierLayout.itemRow(item));
      for (final addon in item.selectedAddons) {
        buffer.writeln(
          ReceiptCashierLayout.addonRow(
            name: addon.name,
            quantity: addon.quantity,
            lineTotal: item.receiptAddonLineTotal(addon),
          ),
        );
      }
    }

    buffer
      ..writeln(_separator())
      ..writeln('TOTAL: ${order.totalPrice.toStringAsFixed(0)} IQD')
      ..writeln()
      ..writeln(_center('Thank you'));

    return buffer.toString();
  }

  static String buildKitchenReceipt(DeliveryOrder order) {
    final local = order.createdAt.toLocal();
    final dateStr = _formatDateTime(local);
    final buffer = StringBuffer()
      ..writeln(_center(PrinterConfig.restaurantDisplayName))
      ..writeln(_center('*** KITCHEN ***'))
      ..writeln(_separator())
      ..writeln('Customer: ${order.customerName}')
      ..writeln('Time:     $dateStr')
      ..writeln(_separator());

    for (final item in order.items) {
      buffer.writeln('x${item.quantity}  ${item.displayName}');
      for (final addon in item.selectedAddons) {
        buffer.writeln(
          '   + x${addon.quantity} ${addon.name}',
        );
      }
    }

    buffer
      ..writeln(_separator())
      ..writeln(_center('--- END ---'));

    return buffer.toString();
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
        '${_two(dt.hour)}:${_two(dt.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _separator() => List.filled(lineWidth, '-').join();

  static String _center(String text) {
    final trimmed = text.trim();
    if (trimmed.length >= lineWidth) return trimmed.substring(0, lineWidth);
    final pad = ((lineWidth - trimmed.length) / 2).floor();
    return '${' ' * pad}$trimmed'.padRight(lineWidth);
  }

  /// سطر تفاصيل المنتج — يفوّض إلى [ReceiptCashierLayout].
  static String formatCashierItemLine(CartItem item) =>
      ReceiptCashierLayout.itemRow(item);

  static String _wrap(String text) {
    if (text.length <= lineWidth) return text;
    return '${text.substring(0, lineWidth - 3)}...';
  }
}
