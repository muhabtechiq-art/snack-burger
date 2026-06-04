import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/config/printer_config.dart';
import '../models/delivery_order_model.dart';
import '../models/order_model.dart';

/// طباعة الفاتورة كـ PDF مع خط عربي + لاتيني (أرقام، GPS، ×) — حوار طباعة Windows.
abstract final class ReceiptPdfPrinter {
  static const _arabicFontAsset = 'assets/fonts/NotoSansArabic-Regular.ttf';
  static const _latinFontAsset = 'assets/fonts/NotoSans-Regular.ttf';
  static final _pageFormat = PdfPageFormat.roll80.copyWith(
    marginTop: 4 * PdfPageFormat.mm,
    marginBottom: 4 * PdfPageFormat.mm,
    marginLeft: 4 * PdfPageFormat.mm,
    marginRight: 4 * PdfPageFormat.mm,
  );

  static _ReceiptFonts? _cachedFonts;

  static Future<Uint8List> buildReceiptPdf(DeliveryOrder order) async {
    final fonts = await _loadFonts();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fonts.arabic,
        fontFallback: [fonts.latin],
      ),
    );

    doc.addPage(
      _page(
        fonts: fonts,
        title: 'فاتورة الكاشير',
        children: _cashierContent(order, fonts),
      ),
    );

    doc.addPage(
      _page(
        fonts: fonts,
        title: 'بون المطبخ',
        children: _kitchenContent(order, fonts),
      ),
    );

    return doc.save();
  }

  static Future<void> printOrderReceipt(
    DeliveryOrder order, {
    bool showDialog = false,
  }) async {
    final info = await Printing.info();
    if (!info.canPrint) {
      throw StateError('منصة الطباعة غير جاهزة (canPrint=false).');
    }

    // Gives Windows spooler/printer driver a moment before dispatching the job.
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final documentName = 'Snack Burger — ${order.id}';

    if (!showDialog && info.directPrint && info.canListPrinters) {
      final printers = await Printing.listPrinters();
      final target = _findGenericTextOnlyPrinter(printers);
      if (target != null) {
        final sent = await Printing.directPrintPdf(
          printer: target,
          name: documentName,
          format: _pageFormat,
          usePrinterSettings: true,
          dynamicLayout: false,
          onLayout: (_) => buildReceiptPdf(order),
        );
        if (!sent) {
          throw StateError('تم إلغاء الطباعة أو فشل إرسال المهمة للطابعة.');
        }
        return;
      }
    }

    final sent = await Printing.layoutPdf(
      name: documentName,
      format: _pageFormat,
      dynamicLayout: false,
      onLayout: (_) => buildReceiptPdf(order),
    );
    if (!sent) {
      throw StateError('تم إلغاء الطباعة من حوار النظام.');
    }
  }

  static Future<void> printTestReceipt() async {
    await printOrderReceipt(_sampleOrder());
  }

  static DeliveryOrder _sampleOrder() {
    final now = DateTime.now();
    return DeliveryOrder(
      id: 'TEST-${now.millisecondsSinceEpoch}',
      restaurantId: 'test',
      slug: 'test',
      customerName: 'زبون تجريبي',
      customerPhone: '07700000000',
      address: 'بغداد — اختبار الطباعة',
      latitude: 33.3152,
      longitude: 44.3661,
      items: const [
        CartItem(
          lineId: 'p1',
          productId: 'p1',
          name: 'برجر لحم',
          quantity: 2,
          baseUnitPrice: 5000,
          unitPrice: 5000,
        ),
        CartItem(
          lineId: 'p2',
          productId: 'p2',
          name: 'بطاطا مقلية',
          quantity: 1,
          baseUnitPrice: 2000,
          unitPrice: 2000,
        ),
      ],
      totalPrice: 12000,
      status: 'pending',
      createdAt: now,
    );
  }

  static Future<_ReceiptFonts> _loadFonts() async {
    if (_cachedFonts != null) return _cachedFonts!;

    try {
      final arabicBytes = await rootBundle.load(_arabicFontAsset);
      final latinBytes = await rootBundle.load(_latinFontAsset);
      _cachedFonts = _ReceiptFonts(
        arabic: pw.Font.ttf(arabicBytes),
        latin: pw.Font.ttf(latinBytes),
      );
      return _cachedFonts!;
    } catch (e) {
      throw StateError(
        'تعذّر تحميل الخطوط من assets/fonts/ — '
        'يلزم NotoSansArabic-Regular.ttf و NotoSans-Regular.ttf: $e',
      );
    }
  }

  static pw.TextStyle _style(
    _ReceiptFonts fonts, {
    double fontSize = 11,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
  }) {
    return pw.TextStyle(
      font: fonts.arabic,
      fontFallback: [fonts.latin],
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  static pw.Page _page({
    required _ReceiptFonts fonts,
    required String title,
    required List<pw.Widget> children,
  }) {
    return pw.Page(
      pageFormat: _pageFormat,
      textDirection: pw.TextDirection.rtl,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              PrinterConfig.restaurantDisplayName,
              style: _style(fonts, fontSize: 16),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              title,
              style: _style(
                fonts,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.Divider(),
            ...children,
          ],
        );
      },
    );
  }

  static List<pw.Widget> _cashierContent(
    DeliveryOrder order,
    _ReceiptFonts fonts,
  ) {
    final local = order.createdAt.toLocal();
    final dateStr = _formatDateTime(local);

    final widgets = <pw.Widget>[
      _line(fonts, 'الزبون: ${order.customerName}'),
      _line(fonts, 'الهاتف: ${order.customerPhone}'),
      _line(fonts, 'العنوان: ${order.address}'),
      if (order.latitude != null && order.longitude != null)
        _line(
          fonts,
          'GPS: ${order.latitude!.toStringAsFixed(5)}, '
          '${order.longitude!.toStringAsFixed(5)}',
        ),
      _line(fonts, 'الوقت: $dateStr'),
      pw.Divider(),
      _line(fonts, 'الوجبات', bold: true),
    ];

    for (final item in order.items) {
      widgets.add(
        _line(
          fonts,
          '${item.name}  x${item.quantity}  '
          '${item.baseLineTotal.toStringAsFixed(0)} د.ع',
        ),
      );
      for (final addon in item.selectedAddons) {
        widgets.add(
          _line(
            fonts,
            '  + ${addon.name}  x${addon.quantity}  '
            '${item.receiptAddonLineTotal(addon).toStringAsFixed(0)} د.ع',
          ),
        );
      }
    }

    widgets
      ..add(pw.Divider())
      ..add(
        pw.Text(
          'الإجمالي: ${order.totalPrice.toStringAsFixed(0)} د.ع',
          style: _style(fonts, fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
      )
      ..add(pw.SizedBox(height: 8))
      ..add(
        pw.Text(
          'شكراً لطلبكم',
          style: _style(fonts, fontSize: 12),
          textAlign: pw.TextAlign.center,
        ),
      );

    return widgets;
  }

  static List<pw.Widget> _kitchenContent(
    DeliveryOrder order,
    _ReceiptFonts fonts,
  ) {
    final local = order.createdAt.toLocal();
    final dateStr = _formatDateTime(local);

    final widgets = <pw.Widget>[
      _line(fonts, 'الزبون: ${order.customerName}'),
      _line(fonts, 'الوقت: $dateStr'),
      pw.Divider(),
    ];

    for (final item in order.items) {
      widgets.add(
        pw.Text(
          'x${item.quantity}  ${item.name}',
          style: _style(fonts, fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      );
      for (final addon in item.selectedAddons) {
        widgets.add(
          pw.Text(
            '  + x${addon.quantity}  ${addon.name}',
            style: _style(fonts, fontSize: 11),
          ),
        );
      }
    }

    widgets
      ..add(pw.Divider())
      ..add(
        pw.Text(
          '--- نهاية البون ---',
          style: _style(fonts, fontSize: 11),
          textAlign: pw.TextAlign.center,
        ),
      );

    return widgets;
  }

  static pw.Widget _line(
    _ReceiptFonts fonts,
    String text, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(
        text,
        style: _style(
          fonts,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
        '${_two(dt.hour)}:${_two(dt.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static Printer? _findGenericTextOnlyPrinter(List<Printer> printers) {
    final target = PrinterConfig.windowsSpoolerPrinterName.toLowerCase().trim();
    for (final printer in printers) {
      final name = printer.name.toLowerCase();
      final model = (printer.model ?? '').toLowerCase();
      final url = printer.url.toLowerCase();
      if (name.contains(target) || model.contains(target) || url.contains(target)) {
        return printer;
      }
    }
    return null;
  }
}

final class _ReceiptFonts {
  const _ReceiptFonts({required this.arabic, required this.latin});

  final pw.Font arabic;
  final pw.Font latin;
}
