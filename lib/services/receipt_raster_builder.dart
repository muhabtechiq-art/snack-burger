import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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

  static Future<img.Image> buildCashierImage(DeliveryOrder order) async {
    return _renderImage(
      _cashierLines(order),
      qrData: order.googleMapsUrl,
    );
  }

  static Future<img.Image> buildKitchenImage(DeliveryOrder order) async {
    return _renderImage(
      _kitchenLines(order),
      qrData: order.googleMapsUrl,
    );
  }

  static Future<img.Image> buildEndOfDayImage(EndOfDayReport report) async {
    return _renderImage(_endOfDayLines(report));
  }

  static List<_RasterLine> _endOfDayLines(EndOfDayReport report) {
    final local = report.reportDate.toLocal();
    final dateStr =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';

    final lines = <_RasterLine>[
      _RasterLine(
        PrinterConfig.restaurantDisplayName,
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
        'إجمالي المبيعات: ${report.totalSales.toStringAsFixed(0)} د.ع',
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

  static List<_RasterLine> _cashierLines(DeliveryOrder order) {
    final local = order.createdAt.toLocal();

    final lines = <_RasterLine>[
      _RasterLine(
        PrinterConfig.restaurantDisplayName,
        fontSize: 28,
        bold: true,
        align: TextAlign.center,
      ),
      _RasterLine(
        ReceiptCashierLayout.subtitle,
        fontSize: 18,
        bold: true,
        align: TextAlign.center,
      ),
      _RasterLine('————————————————', align: TextAlign.center),
      _RasterLine('الاسم: ${order.customerName}'),
      _RasterLine('الهاتف: ${order.customerPhone}'),
      _RasterLine('العنوان: ${order.address}'),
      _RasterLine('التاريخ: ${ReceiptCashierLayout.formatDate(local)}'),
      _RasterLine('الوقت: ${ReceiptCashierLayout.formatTime(local)}'),
      _RasterLine('————————————————', align: TextAlign.center),
      _RasterLine.table(
        name: 'المادة',
        qty: 'الكمية',
        price: 'السعر',
        bold: true,
      ),
      _RasterLine('————————————————', align: TextAlign.center),
    ];

    for (final item in order.items) {
      lines.add(
        _RasterLine.table(
          name: item.displayName,
          qty: '${item.quantity}',
          price: item.baseLineTotal.toStringAsFixed(0),
        ),
      );
      for (final addon in item.selectedAddons) {
        lines.add(
          _RasterLine.table(
            name: '+ ${addon.name}',
            qty: '${addon.quantity}',
            price: item.receiptAddonLineTotal(addon).toStringAsFixed(0),
          ),
        );
      }
    }

    lines
      ..add(_RasterLine('————————————————', align: TextAlign.center))
      ..add(
        _RasterLine(
          'الإجمالي: ${order.totalPrice.toStringAsFixed(0)} د.ع',
          fontSize: 26,
          bold: true,
          align: TextAlign.center,
        ),
      )
      ..add(
        _RasterLine(
          ReceiptCashierLayout.thanksMessage,
          align: TextAlign.center,
          fontSize: 16,
        ),
      );

    return lines;
  }

  static List<_RasterLine> _kitchenLines(DeliveryOrder order) {
    final local = order.createdAt.toLocal();
    final dateStr =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    final lines = <_RasterLine>[
      _RasterLine(
        PrinterConfig.restaurantDisplayName,
        fontSize: 28,
        bold: true,
        align: TextAlign.center,
      ),
      _RasterLine('*** بون المطبخ ***', fontSize: 22, bold: true, align: TextAlign.center),
      _RasterLine('————————————————', align: TextAlign.center),
      _RasterLine('الزبون: ${order.customerName}'),
      _RasterLine('الوقت: $dateStr'),
      _RasterLine('————————————————', align: TextAlign.center),
    ];

    for (final item in order.items) {
      lines.add(
        _RasterLine(
          'x${item.quantity}    ${item.displayName}',
          fontSize: 24,
          bold: true,
        ),
      );
      for (final addon in item.selectedAddons) {
        lines.add(
          _RasterLine(
            '  + x${addon.quantity}    ${addon.name}',
            fontSize: 18,
          ),
        );
      }
    }

    if (order.googleMapsUrl != null) {
      lines.addAll([
        _RasterLine('————————————————', align: TextAlign.center),
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

    final qrSize = qrData != null ? _s(200) : 0.0;
    if (qrData != null) {
      contentHeight += lineGap + qrSize + pad;
    } else {
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
      final qrLeft = (_width - qrSize) / 2;
      canvas.save();
      canvas.translate(qrLeft, y + lineGap);
      qrPainter.paint(canvas, Size.square(qrSize));
      canvas.restore();
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

  static const double _tablePriceWidth = 72;
  static const double _tableQtyWidth = 48;

  static double _tableRowHeight(_RasterLine line, double maxTextWidth) {
    final nameWidth = maxTextWidth - _s(_tablePriceWidth + _tableQtyWidth + 12);
    final heights = <double>[
      _cellHeight(line.price!, line.fontSize, line.bold, _s(_tablePriceWidth),
          TextAlign.left),
      _cellHeight(line.qty!, line.fontSize, line.bold, _s(_tableQtyWidth),
          TextAlign.center),
      _cellHeight(line.name!, line.fontSize, line.bold, nameWidth,
          TextAlign.right),
    ];
    return heights.reduce((a, b) => a > b ? a : b);
  }

  static double _cellHeight(
    String text,
    double fontSize,
    bool bold,
    double width,
    TextAlign align,
  ) {
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
      maxLines: 2,
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
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _textStyle(line)),
      textDirection: _textDirectionFor(text),
      textAlign: align,
      maxLines: 2,
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
  })  : text = '',
        fontSize = 16,
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
