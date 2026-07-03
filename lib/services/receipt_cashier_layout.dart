import '../core/config/printer_config.dart';
import '../core/utils/price_utils.dart';
import '../models/delivery_order_model.dart';
import '../models/order_model.dart';

/// أنماط سطور فاتورة الكاشير — للطباعة الحرارية 80mm.
enum ReceiptLineStyle {
  brandTitle,
  brandSubtitle,
  separatorThin,
  separatorHeavy,
  orderHero,
  customerInfo,
  customerTime,
  dateTimeMeta,
  tableHeader,
  tableRow,
  grandTotalLabel,
  grandTotalValue,
  footer,
}

/// سطر واحد في خطة طباعة الفاتورة (نص أو صف جدول).
final class ReceiptCashierLine {
  const ReceiptCashierLine.text(
    this.text, {
    required this.style,
    this.center = false,
    this.bold = false,
  })  : product = null,
        quantity = null,
        price = null;

  const ReceiptCashierLine.table({
    required this.product,
    required this.quantity,
    required this.price,
    this.style = ReceiptLineStyle.tableRow,
    this.bold = false,
  })  : text = null,
        center = false;

  final String? text;
  final String? product;
  final String? quantity;
  final String? price;
  final ReceiptLineStyle style;
  final bool center;
  final bool bold;

  bool get isTable => product != null && quantity != null && price != null;
}

/// خطة طباعة — قبل QR وبعده (الشكر يأتي أسفل QR في وضع Raster).
final class ReceiptCashierPrintPlan {
  const ReceiptCashierPrintPlan({
    required this.beforeQr,
    required this.afterQr,
  });

  final List<ReceiptCashierLine> beforeQr;
  final List<ReceiptCashierLine> afterQr;

  List<String> get beforeQrText =>
      ReceiptCashierLayout.serializeLines(beforeQr);

  List<String> get afterQrText => ReceiptCashierLayout.serializeLines(afterQr);
}

/// تنسيق فاتورة الكاشير — POS عالمي، 80mm، RTL، أبيض وأسود.
abstract final class ReceiptCashierLayout {
  ReceiptCashierLayout._();

  static const int lineWidth = 42;

  /// المنتج (يمين) | كم (وسط) | السعر (يسار) — 80mm ≈ 42 حرفاً.
  static const int nameCol = 26;
  static const int qtyCol = 4;
  static const int priceCol = 10;

  static final String headerTitle =
      PrinterConfig.restaurantDisplayName.toUpperCase();
  static const String subtitle = 'فاتورة كاشير • توصيل';
  static const String thanksLine1 = 'شكراً لزيارتكم';
  static const String thanksLine2 = 'صحتين وعافية';
  static const String qtyHeader = 'كم';

  // ── Helpers ─────────────────────────────────────────────────────────────

  static String separator({int width = lineWidth}) => separatorThin(width: width);

  static String separatorThin({int width = lineWidth}) =>
      List.filled(width, '-').join();

  static String separatorHeavy({int width = lineWidth}) =>
      List.filled(width, '=').join();

  static String centerText(String text, {int width = lineWidth}) =>
      centerTitle(text, width: width);

  static String centerTitle(String text, {int width = lineWidth}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length >= width) return trimmed.substring(0, width);
    final pad = ((width - trimmed.length) / 2).floor();
    return '${' ' * pad}$trimmed'.padRight(width);
  }

  static String formatDate(DateTime local) =>
      '${local.year}-${_two(local.month)}-${_two(local.day)}';

  static String formatTime12h(DateTime local) {
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final hour12 = local.hour % 12;
    final displayHour = hour12 == 0 ? 12 : hour12;
    return '${displayHour.toString().padLeft(2, '0')}:${_two(local.minute)} $period';
  }

  static String formatOrderNumber(String orderId) {
    final digits = orderId.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '#000000';
    return '#${digits.padLeft(6, '0')}';
  }

  static String displayOrderNumber(DeliveryOrder order) =>
      order.displayOrderNumber;

  static String orderHeroText(DeliveryOrder order) =>
      order.displayOrderHeroLabel;

  static String orderHeroTextFromId(String orderId) =>
      'طلب رقم ${formatOrderNumber(orderId)}';

  static String labelValue(String label, String value) {
    final cleanLabel = label.trim();
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) return '$cleanLabel:';
    return '$cleanLabel: $cleanValue';
  }

  // ── Section builders ────────────────────────────────────────────────────

  static List<ReceiptCashierLine> buildHeader({String? restaurantDisplayName}) {
    final title = restaurantDisplayName?.trim().isNotEmpty == true
        ? restaurantDisplayName!.trim().toUpperCase()
        : headerTitle;
    return [
      ReceiptCashierLine.text(
        title,
        style: ReceiptLineStyle.brandTitle,
        center: true,
      ),
      ReceiptCashierLine.text(
        subtitle,
        style: ReceiptLineStyle.brandSubtitle,
        center: true,
      ),
      ReceiptCashierLine.text(
        separatorThin(),
        style: ReceiptLineStyle.separatorThin,
        center: true,
      ),
    ];
  }

  static List<ReceiptCashierLine> buildOrderHero(DeliveryOrder order) {
    return [
      ReceiptCashierLine.text(
        orderHeroText(order),
        style: ReceiptLineStyle.orderHero,
        center: true,
      ),
    ];
  }

  static List<ReceiptCashierLine> buildCustomerSection(DeliveryOrder order) {
    final local = order.createdAt.toLocal();
    final lines = <ReceiptCashierLine>[
      ReceiptCashierLine.text(
        labelValue('الاسم', order.customerName),
        style: ReceiptLineStyle.customerInfo,
      ),
      ReceiptCashierLine.text(
        labelValue('الهاتف', order.customerPhone),
        style: ReceiptLineStyle.customerInfo,
      ),
    ];

    final addressParts = wrapProductName(order.address.trim(), lineWidth - 10);
    if (addressParts.isEmpty || addressParts.first.isEmpty) {
      lines.add(
        ReceiptCashierLine.text(
          labelValue('العنوان', order.address.trim()),
          style: ReceiptLineStyle.customerInfo,
        ),
      );
    } else {
      lines.add(
        ReceiptCashierLine.text(
          labelValue('العنوان', addressParts.first),
          style: ReceiptLineStyle.customerInfo,
        ),
      );
      for (var i = 1; i < addressParts.length; i++) {
        lines.add(
          ReceiptCashierLine.text(
            '          ${addressParts[i]}',
            style: ReceiptLineStyle.customerInfo,
          ),
        );
      }
    }

    lines.add(
      ReceiptCashierLine.text(
        labelValue('التاريخ', formatDate(local)),
        style: ReceiptLineStyle.customerInfo,
      ),
    );
    lines.add(
      ReceiptCashierLine.text(
        labelValue('الوقت', formatTime12h(local)),
        style: ReceiptLineStyle.customerTime,
      ),
    );

    return lines;
  }

  static List<ReceiptCashierLine> buildItemsTable(DeliveryOrder order) {
    final lines = <ReceiptCashierLine>[
      ReceiptCashierLine.table(
        product: 'المنتج',
        quantity: qtyHeader,
        price: 'السعر',
        style: ReceiptLineStyle.tableHeader,
        bold: true,
      ),
    ];

    for (final item in order.items) {
      lines.addAll(_tableLinesForProduct(
        product: item.displayName,
        quantity: '${item.quantity}',
        price: PriceUtils.formatPrice(item.baseLineTotal),
      ));
      for (final addon in item.selectedAddons) {
        lines.addAll(_tableLinesForProduct(
          product: '+ ${addon.name}',
          quantity: '${addon.quantity}',
          price: PriceUtils.formatPrice(item.receiptAddonLineTotal(addon)),
        ));
      }
    }

    return lines;
  }

  static List<ReceiptCashierLine> buildGrandTotal(double total) {
    final amount = PriceUtils.formatPriceWithCurrency(total);
    return [
      ReceiptCashierLine.text(
        'الإجمالي',
        style: ReceiptLineStyle.grandTotalLabel,
        center: true,
      ),
      ReceiptCashierLine.text(
        amount,
        style: ReceiptLineStyle.grandTotalValue,
        center: true,
      ),
    ];
  }

  static List<ReceiptCashierLine> buildFooter() {
    return [
      ReceiptCashierLine.text(
        thanksLine1,
        style: ReceiptLineStyle.footer,
        center: true,
      ),
      ReceiptCashierLine.text(
        thanksLine2,
        style: ReceiptLineStyle.footer,
        center: true,
      ),
    ];
  }

  /// خطة الطباعة الكاملة — QR يُدرج بين beforeQr و afterQr في Raster.
  static ReceiptCashierPrintPlan buildPrintPlan(
    DeliveryOrder order, {
    String? restaurantDisplayName,
  }) {
    final beforeQr = <ReceiptCashierLine>[
      ...buildHeader(restaurantDisplayName: restaurantDisplayName),
      ...buildOrderHero(order),
      ...buildCustomerSection(order),
      ReceiptCashierLine.text(
        separatorThin(),
        style: ReceiptLineStyle.separatorThin,
        center: true,
      ),
      ...buildItemsTable(order),
      ReceiptCashierLine.text(
        separatorThin(),
        style: ReceiptLineStyle.separatorThin,
        center: true,
      ),
      ...buildGrandTotal(order.totalPrice),
    ];

    return ReceiptCashierPrintPlan(
      beforeQr: beforeQr,
      afterQr: buildFooter(),
    );
  }

  static List<String> serializeLines(List<ReceiptCashierLine> lines) {
    final output = <String>[];
    for (final line in lines) {
      if (line.isTable) {
        output.add(
          formatReceiptRow(
            product: line.product!,
            quantity: line.quantity!,
            price: line.price!,
          ),
        );
        continue;
      }
      final text = line.text?.trim() ?? '';
      if (text.isEmpty) continue;
      output.add(line.center ? centerText(text) : text);
    }
    return output;
  }

  static String formatReceiptRow({
    required String product,
    required String quantity,
    required String price,
  }) {
    final productCell = _fitCell(product, nameCol);
    final qtyCell = _fitCell(quantity, qtyCol, align: _CellAlign.center);
    final priceCell = _fitCell(price, priceCol, align: _CellAlign.left);
    return '$priceCell $qtyCell $productCell';
  }

  static List<String> wrapProductName(String name, int maxWidth) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const [''];
    if (trimmed.length <= maxWidth) return [trimmed];

    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length == 1) return _hardWrap(trimmed, maxWidth);

    final lines = <String>[];
    var current = StringBuffer();
    for (final word in words) {
      if (word.isEmpty) continue;
      if (current.isEmpty) {
        current.write(word);
        continue;
      }
      if ('$current $word'.length <= maxWidth) {
        current.write(' $word');
      } else {
        lines.add(current.toString());
        current = StringBuffer(word);
      }
    }
    if (current.isNotEmpty) {
      final last = current.toString();
      if (last.length <= maxWidth) {
        lines.add(last);
      } else {
        lines.addAll(_hardWrap(last, maxWidth));
      }
    }
    return lines.isEmpty ? [trimmed.substring(0, maxWidth)] : lines;
  }

  static List<ReceiptCashierLine> _tableLinesForProduct({
    required String product,
    required String quantity,
    required String price,
  }) {
    final wrapped = wrapProductName(product, nameCol);
    if (wrapped.isEmpty) return const [];

    final lines = <ReceiptCashierLine>[
      ReceiptCashierLine.table(
        product: wrapped.first,
        quantity: quantity,
        price: price,
      ),
    ];

    for (var i = 1; i < wrapped.length; i++) {
      lines.add(
        ReceiptCashierLine.table(
          product: wrapped[i],
          quantity: '',
          price: '',
        ),
      );
    }
    return lines;
  }

  // ── Legacy shims (PDF + استدعاءات قديمة) ────────────────────────────────

  static List<String> orderInfoLines(DeliveryOrder order) {
    return buildCustomerSection(order)
        .map((line) => line.text ?? '')
        .where((text) => text.isNotEmpty)
        .toList();
  }

  static String tableHeader() => formatReceiptRow(
        product: 'المنتج',
        quantity: qtyHeader,
        price: 'السعر',
      );

  static List<String> itemLines(CartItem item) => serializeLines(
        _tableLinesForProduct(
          product: item.displayName,
          quantity: '${item.quantity}',
          price: PriceUtils.formatPrice(item.baseLineTotal),
        ),
      );

  static List<String> addonLines({
    required String name,
    required int quantity,
    required double lineTotal,
  }) =>
      serializeLines(
        _tableLinesForProduct(
          product: '+ $name',
          quantity: '$quantity',
          price: PriceUtils.formatPrice(lineTotal),
        ),
      );

  static String continuationRow(String productContinuation) {
    final text = productContinuation.trim();
    if (text.isEmpty) return '';
    final indent = ' ' * (priceCol + 1 + qtyCol + 1);
    return '$indent${_fitCell(text, nameCol)}';
  }

  static String totalLine(double total) =>
      PriceUtils.formatPriceWithCurrency(total);

  static String itemRow(CartItem item) => itemLines(item).first;

  static String addonRow({
    required String name,
    required int quantity,
    required double lineTotal,
  }) =>
      addonLines(name: name, quantity: quantity, lineTotal: lineTotal).first;

  static String formatTime(DateTime local) => formatTime12h(local);

  static String get thanksMessage => thanksLine1;

  static String _fitCell(
    String text,
    int width, {
    _CellAlign align = _CellAlign.right,
  }) {
    final trimmed = text.trim();
    final clipped =
        trimmed.length <= width ? trimmed : trimmed.substring(0, width);
    return switch (align) {
      _CellAlign.left => clipped.padRight(width),
      _CellAlign.center => _centerInWidth(clipped, width),
      _CellAlign.right => clipped.padLeft(width),
    };
  }

  static String _centerInWidth(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    final left = ((width - text.length) / 2).floor();
    return '${' ' * left}$text'.padRight(width);
  }

  static List<String> _hardWrap(String text, int maxWidth) {
    final lines = <String>[];
    var start = 0;
    while (start < text.length) {
      final end = (start + maxWidth).clamp(0, text.length);
      lines.add(text.substring(start, end));
      start = end;
    }
    return lines;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

enum _CellAlign { left, center, right }

/// تنسيق بون المطبخ — بدون أسعار، وقت 12 ساعة.
abstract final class ReceiptKitchenLayout {
  ReceiptKitchenLayout._();

  static String formatDateLine(DateTime local) =>
      ReceiptCashierLayout.labelValue(
        'التاريخ',
        ReceiptCashierLayout.formatDate(local),
      );

  static String formatTimeLine(DateTime local) =>
      ReceiptCashierLayout.labelValue(
        'الوقت',
        ReceiptCashierLayout.formatTime12h(local),
      );

  static String orderHeroLine(DeliveryOrder order) =>
      ReceiptCashierLayout.orderHeroText(order);

  /// x1   اسم المنتج — مع التفاف داخل مساحة الاسم فقط.
  static List<String> itemLines({
    required int quantity,
    required String name,
  }) =>
      _qtyNameLines(
        tag: 'x$quantity  ',
        name: name,
      );

  static List<String> addonLines({
    required int quantity,
    required String name,
  }) =>
      _qtyNameLines(
        tag: '  + x$quantity  ',
        name: name,
      );

  static List<String> _qtyNameLines({
    required String tag,
    required String name,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return [tag.trimRight()];

    final nameWidth = ReceiptCashierLayout.lineWidth - tag.length;
    final parts = ReceiptCashierLayout.wrapProductName(trimmed, nameWidth);
    if (parts.isEmpty) return ['$tag$trimmed'];

    final lines = <String>['$tag${parts.first}'];
    final indent = ' ' * tag.length;
    for (var i = 1; i < parts.length; i++) {
      lines.add('$indent${parts[i]}');
    }
    return lines;
  }
}
