import '../core/config/printer_config.dart';
import '../models/delivery_order_model.dart';

/// HTML فاتورة 80mm — تُحوَّل إلى صورة PNG قبل الطباعة لضمان العربية على الطابعات الحرارية.
String buildWebInvoiceHtml(DeliveryOrder order) {
  final local = order.createdAt.toLocal();
  final dateStr =
      '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final timeStr =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';

  final rows = StringBuffer();
  for (final item in order.items) {
    rows.writeln('''
      <tr>
        <td class="item-name">${_escapeHtml(item.displayName)}</td>
        <td class="item-qty">${item.quantity}</td>
        <td class="item-price">${item.baseLineTotal.toStringAsFixed(0)}</td>
      </tr>''');
    for (final addon in item.selectedAddons) {
      rows.writeln('''
      <tr class="addon-row">
        <td class="item-name addon-name">+ ${_escapeHtml(addon.name)}</td>
        <td class="item-qty">${addon.quantity}</td>
        <td class="item-price">${item.receiptAddonLineTotal(addon).toStringAsFixed(0)}</td>
      </tr>''');
    }
  }

  return '''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <title>فاتورة ${PrinterConfig.restaurantDisplayName}</title>
  <style>
    @page {
      size: 80mm auto;
      margin: 0;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: Arial, sans-serif !important;
      font-weight: bold !important;
      color: #000 !important;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
      color-adjust: exact !important;
      text-rendering: geometricPrecision !important;
      -webkit-font-smoothing: antialiased !important;
    }
    html, body {
      direction: rtl;
      unicode-bidi: embed;
      background: #fff !important;
    }
    body {
      width: 72mm;
      max-width: 72mm;
      margin: 0 auto;
      font-size: 13px;
      line-height: 1.5;
    }
    #receipt {
      width: 72mm;
      max-width: 72mm;
      padding: 4mm 3mm;
      background: #fff;
      transform: translateZ(0);
      -webkit-transform: translateZ(0);
      backface-visibility: hidden;
      image-rendering: -webkit-optimize-contrast;
      image-rendering: crisp-edges;
    }
    .header {
      text-align: center;
      padding: 6px 0 10px;
      border-bottom: 2px solid #000;
      margin-bottom: 10px;
    }
    .header h1 {
      font-size: 22px;
      font-weight: bold !important;
      letter-spacing: 0.3px;
    }
    .header p {
      font-size: 12px;
      margin-top: 4px;
    }
    .section-title {
      font-size: 12px;
      margin: 8px 0 4px;
    }
    .info-row {
      display: flex;
      justify-content: space-between;
      gap: 8px;
      margin-bottom: 4px;
      font-size: 12px;
    }
    .info-label { white-space: nowrap; }
    .info-value { text-align: left; flex: 1; word-break: break-word; }
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 10px 0;
      font-size: 12px;
    }
    thead th {
      border-bottom: 2px solid #000;
      padding: 5px 2px;
      text-align: center;
    }
    tbody td {
      padding: 5px 2px;
      vertical-align: top;
      border-bottom: 1px dashed #666;
    }
    .item-name { text-align: right; width: 50%; }
    .item-qty { text-align: center; width: 20%; }
    .item-price { text-align: left; width: 30%; }
    .divider {
      border: none;
      border-top: 2px dotted #000;
      margin: 12px 0 8px;
    }
    .total {
      text-align: center;
      font-size: 20px;
      font-weight: bold !important;
      padding: 8px 0;
    }
    .footer {
      text-align: center;
      margin-top: 14px;
      padding-top: 10px;
      border-top: 1px dashed #000;
      font-size: 13px;
    }
    #print-image {
      display: none;
      width: 80mm;
      max-width: 80mm;
      height: auto;
      image-rendering: -webkit-optimize-contrast;
      image-rendering: crisp-edges;
    }
    @media print {
      html, body, #receipt, #receipt * {
        -webkit-print-color-adjust: exact !important;
        print-color-adjust: exact !important;
        color-adjust: exact !important;
      }
      body.raster-mode #receipt { display: none !important; }
      body.raster-mode #print-image {
        display: block !important;
        width: 80mm !important;
        max-width: 80mm !important;
      }
    }
  </style>
</head>
<body>
  <div id="receipt">
    <div class="header">
      <h1>${_escapeHtml(PrinterConfig.restaurantDisplayName)}</h1>
      <p>فاتورة كاشير — توصيل</p>
    </div>

    <div class="section-title">بيانات الزبون</div>
    <div class="info-row">
      <span class="info-label">الاسم:</span>
      <span class="info-value">${_escapeHtml(order.customerName)}</span>
    </div>
    <div class="info-row">
      <span class="info-label">الهاتف:</span>
      <span class="info-value">${_escapeHtml(order.customerPhone)}</span>
    </div>
    <div class="info-row">
      <span class="info-label">العنوان:</span>
      <span class="info-value">${_escapeHtml(order.address)}</span>
    </div>
    <div class="info-row">
      <span class="info-label">التاريخ:</span>
      <span class="info-value">$dateStr</span>
    </div>
    <div class="info-row">
      <span class="info-label">الوقت:</span>
      <span class="info-value">$timeStr</span>
    </div>

    <table>
      <thead>
        <tr>
          <th>المادة</th>
          <th>الكمية</th>
          <th>السعر</th>
        </tr>
      </thead>
      <tbody>
        $rows
      </tbody>
    </table>

    <hr class="divider">
    <div class="total">الإجمالي: ${order.totalPrice.toStringAsFixed(0)} د.ع</div>
    <div class="footer">شكراً لزيارتكم .. ألف عافية</div>
  </div>
  <img id="print-image" alt="receipt">

  <script>
  (function () {
    var SCALE = 2;

    function rasterizeReceiptThenPrint() {
      var receipt = document.getElementById('receipt');
      var printImg = document.getElementById('print-image');
      if (!receipt || !printImg) {
        window.print();
        return;
      }

      var width = Math.max(receipt.offsetWidth, receipt.scrollWidth, 272);
      var height = Math.max(receipt.offsetHeight, receipt.scrollHeight, 200);

      var svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="' + width + '" height="' + height + '">' +
        '<foreignObject width="100%" height="100%">' +
        '<div xmlns="http://www.w3.org/1999/xhtml" dir="rtl" style="font-family:Arial,sans-serif;font-weight:bold;background:#fff;color:#000;width:' + width + 'px;">' +
        receipt.innerHTML +
        '</div></foreignObject></svg>';

      var blob = new Blob([svg], { type: 'image/svg+xml;charset=utf-8' });
      var url = URL.createObjectURL(blob);
      var img = new Image();

      img.onload = function () {
        try {
          var canvas = document.createElement('canvas');
          canvas.width = width * SCALE;
          canvas.height = height * SCALE;
          var ctx = canvas.getContext('2d');
          ctx.fillStyle = '#ffffff';
          ctx.fillRect(0, 0, canvas.width, canvas.height);
          ctx.scale(SCALE, SCALE);
          ctx.drawImage(img, 0, 0);
          printImg.src = canvas.toDataURL('image/png');
          document.body.classList.add('raster-mode');
          setTimeout(function () { window.print(); }, 250);
        } catch (err) {
          console.error('rasterize failed', err);
          window.print();
        } finally {
          URL.revokeObjectURL(url);
        }
      };

      img.onerror = function () {
        URL.revokeObjectURL(url);
        window.print();
      };

      img.src = url;
    }

    function start() {
      setTimeout(rasterizeReceiptThenPrint, 120);
    }

    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(start).catch(start);
    } else {
      start();
    }
  })();
  </script>
</body>
</html>''';
}

String _escapeHtml(String raw) {
  return raw
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
