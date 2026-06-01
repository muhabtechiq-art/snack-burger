import '../core/config/printer_config.dart';
import '../models/delivery_order_model.dart';

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
      ..writeln(_padLine('Item', 'Qty', 'Price'))
      ..writeln(_separator());

    for (final item in order.items) {
      buffer.writeln(_itemLine(item.name, item.quantity, item.lineTotal));
      for (final addon in item.selectedAddons) {
        buffer.writeln(
          _addonLine(addon.name, addon.quantity, addon.lineTotal),
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
      buffer.writeln('x${item.quantity}  ${item.name}');
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

  static String _padLine(String a, String b, String c) {
    const w1 = 22;
    const w2 = 5;
    const w3 = lineWidth - w1 - w2;
    return '${a.padRight(w1)}${b.padLeft(w2)}${c.padLeft(w3)}';
  }

  static String _itemLine(String name, int qty, double price) {
    final priceStr = price.toStringAsFixed(0);
    final maxName = lineWidth - 8 - priceStr.length;
    final shortName =
        name.length > maxName ? '${name.substring(0, maxName - 1)}.' : name;
    return 'x$qty $shortName'.padRight(lineWidth - priceStr.length) + priceStr;
  }

  static String _addonLine(String name, int qty, double price) {
    final priceStr = price.toStringAsFixed(0);
    final prefix = '  + x$qty ';
    final maxName = lineWidth - prefix.length - priceStr.length;
    final shortName =
        name.length > maxName ? '${name.substring(0, maxName - 1)}.' : name;
    return '$prefix$shortName'.padRight(lineWidth - priceStr.length) + priceStr;
  }

  static String _wrap(String text) {
    if (text.length <= lineWidth) return text;
    return '${text.substring(0, lineWidth - 3)}...';
  }
}
