import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';

import '../core/config/printer_config.dart';
import '../models/delivery_order_model.dart';
import '../models/end_of_day_report_model.dart';

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
      _RasterLine('الأكثر طلباً', fontSize: 18, bold: true),
    ];

    if (report.topProducts.isEmpty) {
      lines.add(const _RasterLine('لا توجد مبيعات مسجّلة اليوم'));
    } else {
      for (var i = 0; i < report.topProducts.length; i++) {
        final stat = report.topProducts[i];
        lines.add(
          _RasterLine(
            '${i + 1}. ${stat.name}    x${stat.quantity}',
          ),
        );
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
      _RasterLine('فاتورة الكاشير', fontSize: 20, bold: true, align: TextAlign.center),
      _RasterLine('————————————————', align: TextAlign.center),
      _RasterLine('الزبون: ${order.customerName}'),
      _RasterLine('الهاتف: ${order.customerPhone}'),
      _RasterLine('العنوان: ${order.address}'),
    ];

    if (order.googleMapsUrl != null) {
      lines.addAll([
        _RasterLine('————————————————', align: TextAlign.center),
        _RasterLine(
          'موقع التوصيل — امسح QR',
          fontSize: 18,
          bold: true,
          align: TextAlign.center,
        ),
        _RasterLine(
          'يفتح Google Maps مباشرة',
          align: TextAlign.center,
          fontSize: 14,
        ),
      ]);
    }

    lines
      ..add(_RasterLine('الوقت: $dateStr'))
      ..add(_RasterLine('————————————————', align: TextAlign.center))
      ..add(_RasterLine('الوجبات', bold: true))
      ..add(_RasterLine('الصنف                    الكمية    السعر', bold: true));

    for (final item in order.items) {
      lines.add(
        _RasterLine(
          '${item.name}    x${item.quantity}    '
          '${item.lineTotal.toStringAsFixed(0)} د.ع',
        ),
      );
      for (final addon in item.selectedAddons) {
        lines.add(
          _RasterLine(
            '  + ${addon.name}    x${addon.quantity}    '
            '${addon.lineTotal.toStringAsFixed(0)} د.ع',
          ),
        );
      }
    }

    lines
      ..add(_RasterLine('————————————————', align: TextAlign.center))
      ..add(
        _RasterLine(
          'الإجمالي: ${order.totalPrice.toStringAsFixed(0)} د.ع',
          fontSize: 22,
          bold: true,
        ),
      )
      ..add(_RasterLine('شكراً لطلبكم', align: TextAlign.center, fontSize: 18));

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
          'x${item.quantity}    ${item.name}',
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
    final painters = <TextPainter>[];
    var contentHeight = pad;

    for (final line in lines) {
      final painter = TextPainter(
        text: TextSpan(
          text: line.text,
          style: TextStyle(
            color: Colors.black,
            fontSize: _s(line.fontSize),
            fontWeight: line.bold ? FontWeight.bold : FontWeight.w600,
            fontFamily: 'NotoSansArabic',
            height: 1.25,
          ),
        ),
        textDirection: _textDirectionFor(line.text),
        textAlign: line.align,
        maxLines: null,
      )..layout(maxWidth: maxTextWidth);
      painters.add(painter);
      contentHeight += painter.height + lineGap;
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

    for (var i = 0; i < painters.length; i++) {
      final painter = painters[i];
      final line = lines[i];
      final dx = switch (line.align) {
        TextAlign.center => pad + (maxTextWidth - painter.width) / 2,
        TextAlign.left => pad,
        _ => pad + maxTextWidth - painter.width,
      };
      painter.paint(
        canvas,
        Offset(dx, pad + _lineYOffset(painters, i, lineGap)),
      );
    }

    if (qrData != null) {
      final textBottom = pad + _lineYOffset(painters, painters.length, lineGap);
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
      canvas.translate(qrLeft, textBottom + lineGap);
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

    // الطابعة 80mm تتوقع 576px — الرسم بـ 2x للجودة ثم تصغير.
    if (decoded.width != _width.round()) {
      return img.copyResize(
        decoded,
        width: _width.round(),
        interpolation: img.Interpolation.average,
      );
    }
    return decoded;
  }

  static double _lineYOffset(
    List<TextPainter> painters,
    int index,
    double lineGap,
  ) {
    var y = 0.0;
    for (var i = 0; i < index; i++) {
      y += painters[i].height + lineGap;
    }
    return y;
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
  });

  final String text;
  final double fontSize;
  final bool bold;
  final TextAlign align;
}
