import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../core/utils/price_utils.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';

import '../core/config/printer_config.dart';
import '../models/delivery_order_model.dart';
import '../models/end_of_day_report_model.dart';
import 'receipt_cashier_layout.dart';

/// يرسم الفاتورة كصورة نقطية (RTL) لطباعة عربية واضحة على الطابعات الحرارية.
abstract final class ReceiptRasterBuilder {
  static const double _width = 576;
  static const double _pad = 18;
  static const double _scale = 2;

  /// تكبير الخط والهوامش (~35%) — يبقى عرض الطباعة 576px.
  static const double _contentScale =
      (_width + PrinterConfig.receiptRasterBoostPx) / _width;

  static double _s(double value) => value * _contentScale;

  static Future<img.Image> buildTestImage() async {
    return _renderImage(const [
      _RasterLine(
        PrinterConfig.restaurantDisplayName,
        fontSize: 28,
        bold: true,
        align: TextAlign.center,
      ),
      _RasterLine('اختبار طباعة', fontSize: 22, bold: true, align: TextAlign.center),
      _RasterLine('Generic / Text Only', align: TextAlign.center),
      _RasterLine('برجر x2    5000 د.ع'),
      _RasterLine('العربية + English + 123', align: TextAlign.center),
    ]);
  }

  static Future<img.Image> buildCashierImage(
    DeliveryOrder order, {
    String? restaurantDisplayName,
  }) async {
    final plan = ReceiptCashierLayout.buildPrintPlan(
      order,
      restaurantDisplayName: restaurantDisplayName,
    );
    return _renderImage(
      _planLinesToRaster(plan.beforeQr),
      qrData: order.googleMapsUrl,
      qrSize: _s(140),
      trailingLines: _planLinesToRaster(plan.afterQr),
    );
  }

  static Future<img.Image> buildKitchenImage(
    DeliveryOrder order, {
    String? restaurantDisplayName,
  }) async {
    return _renderImage(
      _kitchenLines(order, restaurantDisplayName: restaurantDisplayName),
      qrData: order.googleMapsUrl,
    );
  }

  static Future<img.Image> buildEndOfDayImage(
    EndOfDayReport report, {
    String? restaurantDisplayName,
  }) async {
    return _renderImage(
      _endOfDayLines(report, restaurantDisplayName: restaurantDisplayName),
    );
  }

  static List<_RasterLine> _endOfDayLines(
    EndOfDayReport report, {
    String? restaurantDisplayName,
  }) {
    final trimmed = restaurantDisplayName?.trim();
    final headerName = (trimmed != null && trimmed.isNotEmpty)
        ? trimmed
        : PrinterConfig.restaurantDisplayName;

    final local = report.reportDate.toLocal();
    final dateStr =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';

    final lines = <_RasterLine>[
      _RasterLine(
        headerName,
        fontSize: 28,
        bold: true,
        align: TextAlign.center,
      ),
      _RasterLine(
        'تقرير إغلاق اليوم',
        fontSize: 24,
        bold: true,
        align: TextAlign.center,
      ),
      _RasterLine('التاريخ: $dateStr', align: TextAlign.center),
      _RasterLine('————————————————', align: TextAlign.center),
      _RasterLine(
        'عدد الطلبات: ${report.orderCount}',
        fontSize: 20,
        bold: true,
      ),
      _RasterLine(
        'إجمالي المبيعات: ${PriceUtils.formatPriceWithCurrency(report.totalSales)}',
        fontSize: 22,
        bold: true,
      ),
      _RasterLine('————————————————', align: TextAlign.center),
      _RasterLine(
        'الكميات المباعة لكل صنف',
        fontSize: 18,
        bold: true,
      ),
      _RasterLine('الصنف                    الكمية', bold: true),
    ];

    final quantityByProduct = <String, int>{};
    for (final line in report.productLines) {
      final name = line.productName.trim();
      if (name.isEmpty) continue;
      quantityByProduct[name] =
          (quantityByProduct[name] ?? 0) + line.quantitySold;
    }

    if (quantityByProduct.isEmpty) {
      lines.add(const _RasterLine('لا توجد مبيعات مسجّلة اليوم'));
    } else {
      final sortedNames = quantityByProduct.keys.toList()..sort();
      for (final name in sortedNames) {
        lines.add(_RasterLine('$name: ${quantityByProduct[name]}'));
      }
    }

    lines.add(
      const _RasterLine(
        '--- نهاية التقرير ---',
        align: TextAlign.center,
      ),
    );
    return lines;
  }

  static List<_RasterLine> _planLinesToRaster(List<ReceiptCashierLine> lines) {
    return lines.map(_fromPlanLine).toList();
  }

  static _RasterLine _fromPlanLine(ReceiptCashierLine line) {
    if (line.isTable) {
      return _RasterLine.table(
        name: line.product!,
        qty: line.quantity!,
        price: line.price!,
        bold: line.bold || line.style == ReceiptLineStyle.tableHeader,
        fontSize: line.style == ReceiptLineStyle.tableHeader ? 17 : 16,
      );
    }

    final text = line.text ?? '';
    final (fontSize, bold, align) = switch (line.style) {
      ReceiptLineStyle.brandTitle => (34.0, true, TextAlign.center),
      ReceiptLineStyle.brandSubtitle => (17.0, false, TextAlign.center),
      ReceiptLineStyle.separatorThin => (14.0, false, TextAlign.center),
      ReceiptLineStyle.separatorHeavy => (14.0, true, TextAlign.center),
      ReceiptLineStyle.orderHero => (26.0, true, TextAlign.center),
      ReceiptLineStyle.customerInfo => (16.0, false, TextAlign.right),
      ReceiptLineStyle.customerTime => (16.0, false, TextAlign.right),
      ReceiptLineStyle.dateTimeMeta => (15.0, false, TextAlign.center),
      ReceiptLineStyle.grandTotalLabel => (18.0, true, TextAlign.center),
      ReceiptLineStyle.grandTotalValue => (30.0, true, TextAlign.center),
      ReceiptLineStyle.footer => (15.0, false, TextAlign.center),
      _ => (
          16.0,
          line.bold,
          line.center ? TextAlign.center : TextAlign.right,
        ),
    };

    return _RasterLine(
      text,
      fontSize: fontSize,
      bold: bold,
      align: align,
    );
  }

  static List<_RasterLine> _kitchenLines(
    DeliveryOrder order, {
    String? restaurantDisplayName,
  }) {
    final local = order.createdAt.toLocal();
    final trimmed = restaurantDisplayName?.trim();
    final headerName = (trimmed != null && trimmed.isNotEmpty)
        ? trimmed
        : PrinterConfig.restaurantDisplayName;

    final lines = <_RasterLine>[
      _RasterLine(
        headerName,
        fontSize: 28,
        bold: true,
        align: TextAlign.center,
      ),
      _RasterLine('*** بون المطبخ ***', fontSize: 22, bold: true, align: TextAlign.center),
      _RasterLine(
        ReceiptCashierLayout.separatorThin(),
        align: TextAlign.center,
      ),
      _RasterLine(
        ReceiptCashierLayout.orderHeroText(order),
        fontSize: 24,
        bold: true,
        align: TextAlign.center,
      ),
      _RasterLine('الزبون: ${order.customerName}'),
      _RasterLine(ReceiptKitchenLayout.formatDateLine(local)),
      _RasterLine(ReceiptKitchenLayout.formatTimeLine(local)),
      _RasterLine(
        ReceiptCashierLayout.separatorThin(),
        align: TextAlign.center,
      ),
    ];

    for (final item in order.items) {
      for (final line in ReceiptKitchenLayout.itemLines(
        quantity: item.quantity,
        name: item.displayName,
      )) {
        lines.add(_RasterLine(line, fontSize: 24, bold: true));
      }
      for (final addon in item.selectedAddons) {
        for (final line in ReceiptKitchenLayout.addonLines(
          quantity: addon.quantity,
          name: addon.name,
        )) {
          lines.add(_RasterLine(line, fontSize: 18));
        }
      }
    }

    if (order.googleMapsUrl != null) {
      lines.addAll([
        _RasterLine(
          ReceiptCashierLayout.separatorThin(),
          align: TextAlign.center,
        ),
        _RasterLine(
          'موقع التوصيل — QR',
          align: TextAlign.center,
          bold: true,
        ),
      ]);
    }

    lines.add(_RasterLine('--- نهاية البون ---', align: TextAlign.center));
    return lines;
  }

  static Future<img.Image> _renderImage(
    List<_RasterLine> lines, {
    String? qrData,
    double? qrSize,
    List<_RasterLine> trailingLines = const [],
  }) async {
    final pad = _s(_pad);
    final lineGap = _s(6);
    final maxTextWidth = _width - pad * 2;
    final rowHeights = <double>[];
    var contentHeight = pad;

    for (final line in lines) {
      if (line.isTable) {
        rowHeights.add(_tableRowHeight(line, maxTextWidth));
      } else {
        rowHeights.add(_textLineHeight(line, maxTextWidth));
      }
      contentHeight += rowHeights.last + lineGap;
    }

    final trailingHeights = <double>[];
    for (final line in trailingLines) {
      if (line.isTable) {
        trailingHeights.add(_tableRowHeight(line, maxTextWidth));
      } else {
        trailingHeights.add(_textLineHeight(line, maxTextWidth));
      }
    }

    final resolvedQrSize = qrData != null ? (qrSize ?? _s(200)) : 0.0;
    if (qrData != null) {
      contentHeight += lineGap + resolvedQrSize + lineGap;
      for (final h in trailingHeights) {
        contentHeight += h + lineGap;
      }
      contentHeight += pad;
    } else {
      for (final h in trailingHeights) {
        contentHeight += h + lineGap;
      }
      contentHeight += pad;
    }

    final pixelWidth = (_width * _scale).round();
    final pixelHeight = (contentHeight * _scale).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble()),
    );
    canvas.scale(_scale);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _width, contentHeight),
      Paint()..color = Colors.white,
    );

    var y = pad;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isTable) {
        _paintTableRow(
          canvas: canvas,
          line: line,
          y: y,
          maxTextWidth: maxTextWidth,
        );
      } else {
        _paintTextLine(
          canvas: canvas,
          line: line,
          y: y,
          maxTextWidth: maxTextWidth,
        );
      }
      y += rowHeights[i] + lineGap;
    }

    if (qrData != null) {
      y += lineGap;
      final qrPainter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );
      final qrLeft = (_width - resolvedQrSize) / 2;
      canvas.save();
      canvas.translate(qrLeft, y);
      qrPainter.paint(canvas, Size.square(resolvedQrSize));
      canvas.restore();
      y += resolvedQrSize + lineGap;
    }

    for (var i = 0; i < trailingLines.length; i++) {
      final line = trailingLines[i];
      if (line.isTable) {
        _paintTableRow(
          canvas: canvas,
          line: line,
          y: y,
          maxTextWidth: maxTextWidth,
        );
      } else {
        _paintTextLine(
          canvas: canvas,
          line: line,
          y: y,
          maxTextWidth: maxTextWidth,
        );
      }
      y += trailingHeights[i] + lineGap;
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(pixelWidth, pixelHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('تعذّر تصدير PNG للفاتورة');
    }

    final decoded = img.decodeImage(byteData.buffer.asUint8List());
    if (decoded == null) {
      throw StateError('تعذّر تحويل الفاتورة إلى صورة');
    }

    if (decoded.width != _width.round()) {
      return img.copyResize(
        decoded,
        width: _width.round(),
        interpolation: img.Interpolation.average,
      );
    }
    return decoded;
  }

  static TextStyle _textStyle(_RasterLine line) => TextStyle(
        color: Colors.black,
        fontSize: _s(line.fontSize),
        fontWeight: line.bold ? FontWeight.bold : FontWeight.w600,
        fontFamily: 'NotoSansArabic',
        height: 1.25,
      );

  static double _textLineHeight(_RasterLine line, double maxTextWidth) {
    final painter = TextPainter(
      text: TextSpan(text: line.text, style: _textStyle(line)),
      textDirection: _textDirectionFor(line.text),
      textAlign: line.align,
      maxLines: null,
    )..layout(maxWidth: maxTextWidth);
    return painter.height;
  }

  static void _paintTextLine({
    required Canvas canvas,
    required _RasterLine line,
    required double y,
    required double maxTextWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: line.text, style: _textStyle(line)),
      textDirection: _textDirectionFor(line.text),
      textAlign: line.align,
      maxLines: null,
    )..layout(maxWidth: maxTextWidth);

    final pad = _s(_pad);
    final dx = switch (line.align) {
      TextAlign.center => pad + (maxTextWidth - painter.width) / 2,
      TextAlign.left => pad,
      _ => pad + maxTextWidth - painter.width,
    };
    painter.paint(canvas, Offset(dx, y));
  }

  static const double _tablePriceWidth = 96;
  static const double _tableQtyWidth = 40;

  static double _tableRowHeight(_RasterLine line, double maxTextWidth) {
    final nameWidth = maxTextWidth - _s(_tablePriceWidth + _tableQtyWidth + 12);
    final heights = <double>[
      _cellHeight(line.price!, line.fontSize, line.bold, _s(_tablePriceWidth),
          TextAlign.left),
      _cellHeight(line.qty!, line.fontSize, line.bold, _s(_tableQtyWidth),
          TextAlign.center),
      _cellHeight(
        line.name!,
        line.fontSize,
        line.bold,
        nameWidth,
        TextAlign.right,
        maxLines: 4,
      ),
    ];
    return heights.reduce((a, b) => a > b ? a : b);
  }

  static double _cellHeight(
    String text,
    double fontSize,
    bool bold,
    double width,
    TextAlign align, {
    int maxLines = 2,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: _s(fontSize),
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          fontFamily: 'NotoSansArabic',
          height: 1.25,
        ),
      ),
      textDirection: _textDirectionFor(text),
      textAlign: align,
      maxLines: maxLines,
    )..layout(maxWidth: width);
    return painter.height;
  }

  static void _paintTableRow({
    required Canvas canvas,
    required _RasterLine line,
    required double y,
    required double maxTextWidth,
  }) {
    final pad = _s(_pad);
    final priceW = _s(_tablePriceWidth);
    final qtyW = _s(_tableQtyWidth);
    final gap = _s(6);
    final nameLeft = pad + priceW + qtyW + gap * 2;
    final nameWidth = maxTextWidth - priceW - qtyW - gap * 2;
    final qtyLeft = pad + priceW + gap;

    _paintCell(
      canvas: canvas,
      text: line.price!,
      x: pad,
      y: y,
      width: priceW,
      align: TextAlign.left,
      line: line,
    );
    _paintCell(
      canvas: canvas,
      text: line.qty!,
      x: qtyLeft,
      y: y,
      width: qtyW,
      align: TextAlign.center,
      line: line,
    );
    _paintCell(
      canvas: canvas,
      text: line.name!,
      x: nameLeft,
      y: y,
      width: nameWidth,
      align: TextAlign.right,
      line: line,
      maxLines: 4,
    );
  }

  static void _paintCell({
    required Canvas canvas,
    required String text,
    required double x,
    required double y,
    required double width,
    required TextAlign align,
    required _RasterLine line,
    int maxLines = 2,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _textStyle(line)),
      textDirection: _textDirectionFor(text),
      textAlign: align,
      maxLines: maxLines,
    )..layout(maxWidth: width);
    painter.paint(canvas, Offset(x, y));
  }

  static TextDirection _textDirectionFor(String text) {
    final rtl = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');
    return rtl.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;
  }
}

final class _RasterLine {
  const _RasterLine(
    this.text, {
    this.fontSize = 16,
    this.bold = false,
    this.align = TextAlign.right,
  })  : name = null,
        qty = null,
        price = null;

  const _RasterLine.table({
    required this.name,
    required this.qty,
    required this.price,
    this.bold = false,
    this.fontSize = 16,
  })  : text = '',
        align = TextAlign.right;

  final String text;
  final String? name;
  final String? qty;
  final String? price;
  final double fontSize;
  final bool bold;
  final TextAlign align;

  bool get isTable => name != null && qty != null && price != null;
}
