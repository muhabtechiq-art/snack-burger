import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../core/config/printer_config.dart';
import '../models/delivery_order_model.dart';

/// عرض منطقي 80mm (~576px) — يُرسم على Canvas ثم يُصدَّر PNG.
const double _receiptWidth = 576;
const double _pad = 18;
const double _scale = 2;

/// يرسم الفاتورة كرسوميات نقطية ويعيد data:image/png;base64,...
String renderReceiptPngDataUrl(DeliveryOrder order) {
  final local = order.createdAt.toLocal();
  final dateStr =
      '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final timeStr =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';

  final measureCanvas =
      web.document.createElement('canvas') as web.HTMLCanvasElement;
  final measureCtx =
      measureCanvas.getContext('2d') as web.CanvasRenderingContext2D;
  measureCtx.font = 'bold 16px Arial';

  final addressLines = _wrapText(
    measureCtx,
    order.address,
    _receiptWidth - _pad * 2,
  );

  final itemBlockHeight = order.items.length * 28.0;
  final height = 420 + addressLines.length * 24 + itemBlockHeight;

  final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
  canvas.width = (_receiptWidth * _scale).toInt();
  canvas.height = (height * _scale).toInt();

  final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
  ctx.scale(_scale, _scale);

  ctx.fillStyle = '#ffffff'.toJS;
  ctx.fillRect(0, 0, _receiptWidth, height);

  ctx.fillStyle = '#000000'.toJS;
  ctx.direction = 'rtl';
  ctx.textBaseline = 'alphabetic';

  var y = 40.0;

  ctx.font = 'bold 32px Arial';
  ctx.textAlign = 'center';
  ctx.fillText(PrinterConfig.restaurantDisplayName, _receiptWidth / 2, y);
  y += 34;

  ctx.font = 'bold 18px Arial';
  ctx.fillText('فاتورة كاشير — توصيل', _receiptWidth / 2, y);
  y += 28;

  _strokeLine(ctx, y);
  y += 26;

  ctx.textAlign = 'right';
  ctx.font = 'bold 16px Arial';

  y = _drawLine(ctx, 'الاسم:', order.customerName, y);
  y = _drawLine(ctx, 'الهاتف:', order.customerPhone, y);
  y = _drawWrappedBlock(ctx, 'العنوان:', addressLines, y);
  y = _drawLine(ctx, 'التاريخ:', dateStr, y);
  y = _drawLine(ctx, 'الوقت:', timeStr, y);
  y += 8;

  _strokeLine(ctx, y);
  y += 28;

  ctx.font = 'bold 17px Arial';
  ctx.textAlign = 'right';
  ctx.fillText('المادة', _receiptWidth - _pad, y);
  ctx.textAlign = 'center';
  ctx.fillText('الكمية', _receiptWidth * 0.55, y);
  ctx.textAlign = 'left';
  ctx.fillText('السعر', _pad + 70, y);
  y += 10;
  _strokeLine(ctx, y, thin: true);
  y += 22;

  ctx.font = 'bold 16px Arial';
  for (final item in order.items) {
    ctx.textAlign = 'right';
    final nameLines = _wrapText(
      ctx,
      item.displayName,
      _receiptWidth * 0.48,
    );
    ctx.fillText(nameLines.first, _receiptWidth - _pad, y);
    ctx.textAlign = 'center';
    ctx.fillText('${item.quantity}', _receiptWidth * 0.55, y);
    ctx.textAlign = 'left';
    ctx.fillText(
      item.baseLineTotal.toStringAsFixed(0),
      _pad + 70,
      y,
    );
    y += 26;

    for (final addon in item.selectedAddons) {
      ctx.textAlign = 'right';
      ctx.fillText(
        '+ ${addon.name}',
        _receiptWidth - _pad,
        y,
      );
      ctx.textAlign = 'center';
      ctx.fillText('${addon.quantity}', _receiptWidth * 0.55, y);
      ctx.textAlign = 'left';
      ctx.fillText(
        item.receiptAddonLineTotal(addon).toStringAsFixed(0),
        _pad + 70,
        y,
      );
      y += 22;
    }
  }

  y += 6;
  _strokeDotted(ctx, y);
  y += 34;

  ctx.font = 'bold 28px Arial';
  ctx.textAlign = 'center';
  ctx.fillText(
    'الإجمالي: ${order.totalPrice.toStringAsFixed(0)} د.ع',
    _receiptWidth / 2,
    y,
  );
  y += 40;

  ctx.font = 'bold 18px Arial';
  ctx.fillText('شكراً لزيارتكم .. ألف عافية', _receiptWidth / 2, y);

  return canvas.toDataURL('image/png');
}

double _drawLine(
  web.CanvasRenderingContext2D ctx,
  String label,
  String value,
  double y,
) {
  ctx.textAlign = 'right';
  ctx.font = 'bold 16px Arial';
  ctx.fillText('$label $value', _receiptWidth - _pad, y);
  return y + 24;
}

double _drawWrappedBlock(
  web.CanvasRenderingContext2D ctx,
  String label,
  List<String> lines,
  double y,
) {
  ctx.textAlign = 'right';
  ctx.font = 'bold 16px Arial';
  if (lines.isEmpty) {
    ctx.fillText('$label —', _receiptWidth - _pad, y);
    return y + 24;
  }
  ctx.fillText('$label ${lines.first}', _receiptWidth - _pad, y);
  y += 24;
  for (var i = 1; i < lines.length; i++) {
    ctx.fillText(lines[i], _receiptWidth - _pad, y);
    y += 22;
  }
  return y;
}

void _strokeLine(web.CanvasRenderingContext2D ctx, double y, {bool thin = false}) {
  ctx.strokeStyle = '#000000'.toJS;
  ctx.lineWidth = thin ? 1 : 2;
  ctx.beginPath();
  ctx.moveTo(_pad, y);
  ctx.lineTo(_receiptWidth - _pad, y);
  ctx.stroke();
}

void _strokeDotted(web.CanvasRenderingContext2D ctx, double y) {
  ctx.strokeStyle = '#000000'.toJS;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(_pad, y);
  ctx.lineTo(_receiptWidth - _pad, y);
  ctx.stroke();
}

List<String> _wrapText(
  web.CanvasRenderingContext2D ctx,
  String text,
  double maxWidth,
) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const ['—'];

  final lines = <String>[];
  var current = '';

  for (final rune in trimmed.runes) {
    final ch = String.fromCharCode(rune);
    final candidate = current + ch;
    if (ctx.measureText(candidate).width > maxWidth && current.isNotEmpty) {
      lines.add(current);
      current = ch.trim().isEmpty ? '' : ch;
    } else {
      current = candidate;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines.isEmpty ? const ['—'] : lines;
}

/// هيكل HTML فارغ للطباعة — تُضاف الصورة برمجياً بعد اكتمال التحميل.
String buildPrintShellHtml() {
  return '''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <style>
    @page { size: 80mm auto; margin: 0; }
    html, body { margin: 0; padding: 0; background: #fff; }
    img {
      width: 100%;
      max-width: 80mm;
      display: block;
      margin: 0 auto;
      image-rendering: -webkit-optimize-contrast;
      image-rendering: crisp-edges;
    }
  </style>
</head>
<body></body>
</html>''';
}
