import '../models/order_model.dart';

/// تنسيق فاتورة الكاشير — 3 أعمدة ثابتة (مادة | كمية | سعر) لورق 80mm.
abstract final class ReceiptCashierLayout {
  ReceiptCashierLayout._();

  /// عرض أعمدة الأحرف — ~42 حرفاً على 80mm.
  static const int nameCol = 22;
  static const int qtyCol = 5;
  static const int priceCol = 8;

  static const String subtitle = 'فاتورة كاشير – توصيل';
  static const String thanksMessage = 'شكراً لزيارتكم .. ألف عافية';

  static String formatDate(DateTime local) =>
      '${_two(local.day)}-${_two(local.month)}-${local.year}';

  static String formatTime(DateTime local) =>
      '${_two(local.hour)}:${_two(local.minute)}';

  static String tableHeader() => _row('المادة', 'الكمية', 'السعر');

  static String itemRow(CartItem item) => _row(
        item.displayName,
        '${item.quantity}',
        item.baseLineTotal.toStringAsFixed(0),
      );

  static String addonRow({
    required String name,
    required int quantity,
    required double lineTotal,
  }) =>
      _row(
        '+ $name',
        '$quantity',
        lineTotal.toStringAsFixed(0),
      );

  static String _row(String name, String qty, String price) {
    final fittedName = _clip(name, nameCol);
    return '${fittedName.padRight(nameCol)} '
        '${qty.padRight(qtyCol)} '
        '${price.padLeft(priceCol)}';
  }

  static String _clip(String text, int max) {
    if (text.length <= max) return text;
    return text.substring(0, max);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
