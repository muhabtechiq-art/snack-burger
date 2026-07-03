import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/config/pos_code_table.dart';
import '../core/config/printer_config.dart';
import '../models/delivery_order_model.dart';
import '../models/end_of_day_report_model.dart';
import 'receipt_cashier_layout.dart';
import 'receipt_raster_builder.dart';
import 'receipt_text_encoder.dart';

/// يبني بايتات ESC/POS خام للفاتورة (كاشير + مطبخ) بترميز CP864.
abstract final class ReceiptEscPosBuilder {
  static const _logTag = 'ReceiptEscPosBuilder';

  static void _log(String message) {
    debugPrint('$_logTag: $message');
  }

  static void _logRaster(String label, dynamic image, List<int> bytes) {
    _log(
      '$label ${image.width}x${image.height} '
      '→ ${bytes.length} bytes (~${(bytes.length / 1024).toStringAsFixed(1)} KB)',
    );
  }

  static List<int> _rasterPageBytes(Generator generator, dynamic image) {
    return <int>[
      ...generator.reset(),
      ...generator.image(image, align: PosAlign.center),
      ...generator.feed(2),
      ...generator.cut(),
    ];
  }

  static Future<({CapabilityProfile profile, String arabicCodePage})>
      _loadPrintContext() async {
    for (final name in PrinterConfig.escPosProfileFallbacks) {
      try {
        final profile = await CapabilityProfile.load(name: name);
        final arabicCodePage = PosCodeTable.resolveArabicCodePage(profile);
        _log('profile="$name" arabicCodePage=$arabicCodePage');
        return (profile: profile, arabicCodePage: arabicCodePage);
      } catch (e, stack) {
        _log('skip profile "$name": $e\n$stack');
      }
    }

    throw StateError(
      'لم يُعثر على CapabilityProfile يدعم CP864/PC864. '
      'جرّب XP-N160I أو TP806L.',
    );
  }

  static Future<Generator> _newGenerator() async {
    final ctx = await _loadPrintContext();
    return Generator(PaperSize.mm80, ctx.profile);
  }

  /// reset + ESC t n — مرة واحدة قبل النص.
  static List<int> _selectCodePage(Generator generator, int codePageId) {
    _log('ESC t $codePageId');
    return generator.rawBytes(PosCodeTable.escSelectCodePageId(codePageId));
  }

  static List<int> _beginReceipt(Generator generator, int codePageId) {
    return <int>[
      ...generator.reset(),
      ..._selectCodePage(generator, codePageId),
    ];
  }

  static Future<List<int>> _lineRaw(
    Generator generator,
    String text, {
    ReceiptCharset charset = ReceiptCharset.cp864,
  }) async {
    final encoded = await ReceiptTextEncoder.encode(text, charset: charset);
    return <int>[...generator.rawBytes(encoded), 0x0A];
  }

  static Future<List<int>> buildOrderReceiptBytes(DeliveryOrder order) async {
    return <int>[
      ...await buildCashierReceiptBytes(order),
      ...await buildKitchenReceiptBytes(order),
    ];
  }

  static String _kitchenHeaderName(String? restaurantDisplayName) {
    final trimmed = restaurantDisplayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return PrinterConfig.restaurantDisplayName;
  }

  /// بايتات فاتورة الكاشير فقط — ESC/POS أو raster حسب [PrinterConfig.useRasterReceipt].
  static Future<List<int>> buildCashierReceiptBytes(
    DeliveryOrder order, {
    String? restaurantDisplayName,
  }) async {
    if (PrinterConfig.useRasterReceipt) {
      return buildCashierReceiptRasterBytes(order);
    }
    return buildCashierReceiptTextBytes(
      order,
      restaurantDisplayName: restaurantDisplayName,
    );
  }

  /// بايتات بون المطبخ فقط — ESC/POS أو raster حسب [PrinterConfig.useRasterReceipt].
  static Future<List<int>> buildKitchenReceiptBytes(
    DeliveryOrder order, {
    String? restaurantDisplayName,
  }) async {
    if (PrinterConfig.useRasterReceipt) {
      return buildKitchenReceiptRasterBytes(order);
    }
    return buildKitchenReceiptTextBytes(
      order,
      restaurantDisplayName: restaurantDisplayName,
    );
  }

  static Future<List<int>> buildOrderReceiptTextBytes(
    DeliveryOrder order,
  ) async {
    return <int>[
      ...await buildCashierReceiptTextBytes(order),
      ...await buildKitchenReceiptTextBytes(order),
    ];
  }

  static Future<List<int>> buildCashierReceiptTextBytes(
    DeliveryOrder order, {
    String? restaurantDisplayName,
  }) async {
    final ctx = await _loadPrintContext();
    final generator = Generator(PaperSize.mm80, ctx.profile);
    const codePageId = PrinterConfig.arabicCodePageId;

    return <int>[
      ..._beginReceipt(generator, codePageId),
      ...await buildCashierTicket(
        generator,
        order,
        restaurantDisplayName: restaurantDisplayName,
      ),
      ...generator.feed(2),
      ...generator.cut(),
    ];
  }

  static Future<List<int>> buildKitchenReceiptTextBytes(
    DeliveryOrder order, {
    String? restaurantDisplayName,
  }) async {
    final ctx = await _loadPrintContext();
    final generator = Generator(PaperSize.mm80, ctx.profile);
    const codePageId = PrinterConfig.arabicCodePageId;

    return <int>[
      ..._beginReceipt(generator, codePageId),
      ...await buildKitchenTicket(
        generator,
        order,
        restaurantDisplayName: restaurantDisplayName,
      ),
      ...generator.feed(2),
      ...generator.cut(),
    ];
  }

  static Future<List<int>> buildOrderReceiptRasterBytes(
    DeliveryOrder order,
  ) async {
    final cashierBytes = await buildCashierReceiptRasterBytes(order);
    final kitchenBytes = await buildKitchenReceiptRasterBytes(order);
    final bytes = <int>[...cashierBytes, ...kitchenBytes];

    _log(
      'raster order → ${bytes.length} bytes '
      '(cashier ${cashierBytes.length} + kitchen ${kitchenBytes.length}, '
      '~${(bytes.length / 1024).toStringAsFixed(1)} KB)',
    );
    return bytes;
  }

  static Future<List<int>> buildCashierReceiptRasterBytes(
    DeliveryOrder order,
  ) async {
    final generator = await _newGenerator();
    final cashier = await ReceiptRasterBuilder.buildCashierImage(order);
    final bytes = _rasterPageBytes(generator, cashier);
    _logRaster('raster cashier', cashier, bytes);
    return bytes;
  }

  static Future<List<int>> buildKitchenReceiptRasterBytes(
    DeliveryOrder order,
  ) async {
    final generator = await _newGenerator();
    final kitchen = await ReceiptRasterBuilder.buildKitchenImage(order);
    final bytes = _rasterPageBytes(generator, kitchen);
    _logRaster('raster kitchen', kitchen, bytes);
    return bytes;
  }

  static Future<List<int>> buildEndOfDayReceiptBytes(EndOfDayReport report) async {
    if (PrinterConfig.useRasterReceipt) {
      return buildEndOfDayReceiptRasterBytes(report);
    }
    throw UnsupportedError(
      'تقرير الإغلاق يتطلب الطباعة كصورة (useRasterReceipt).',
    );
  }

  static Future<List<int>> buildEndOfDayReceiptRasterBytes(
    EndOfDayReport report,
  ) async {
    final generator = await _newGenerator();
    final image = await ReceiptRasterBuilder.buildEndOfDayImage(report);

    final bytes = _rasterPageBytes(generator, image);
    _logRaster('raster EOD', image, bytes);
    return bytes;
  }

  static Future<List<int>> buildTestReceiptBytes() async {
    if (PrinterConfig.useRasterReceipt) {
      return buildTestReceiptRasterBytes();
    }
    return buildTestReceiptTextBytes();
  }

  static Future<List<int>> buildTestReceiptTextBytes() async {
    final generator = Generator(
      PaperSize.mm80,
      (await _loadPrintContext()).profile,
    );
    const codePageId = PrinterConfig.arabicCodePageId;

    final bytes = <int>[];
    bytes
      ..addAll(_beginReceipt(generator, codePageId))
      ..addAll(await _lineRaw(generator, PrinterConfig.restaurantDisplayName))
      ..addAll(await _lineRaw(generator, 'اختبار طباعة'))
      ..addAll(await _lineRaw(generator, 'Generic / Text Only'))
      ..addAll(await _lineRaw(generator, 'برجر x2  5000'))
      ..addAll(generator.feed(2))
      ..addAll(generator.cut());

    return bytes;
  }

  static Future<List<int>> buildTestReceiptRasterBytes() async {
    final generator = await _newGenerator();
    final image = await ReceiptRasterBuilder.buildTestImage();

    final bytes = _rasterPageBytes(generator, image);
    _logRaster('raster test', image, bytes);
    return bytes;
  }

  /// اختبار ASCII فقط — لعزل مشكلة CP864 عن Win32 RAW.
  static Future<List<int>> buildEnglishSmokeTestBytes() async {
    final generator = await _newGenerator();
    final bytes = <int>[];
    bytes
      ..addAll(generator.reset())
      ..addAll(
        generator.text(
          'TEST PRINT SUCCESS',
          styles: const PosStyles(
            bold: true,
            align: PosAlign.center,
          ),
        ),
      )
      ..addAll(
        generator.text(
          'Win32 RAW / ESC/POS smoke test',
          styles: const PosStyles(align: PosAlign.center),
        ),
      )
      ..addAll(generator.feed(2))
      ..addAll(generator.cut());
    return bytes;
  }

  static Future<List<int>> buildCashierTicket(
    Generator generator,
    DeliveryOrder order, {
    String? restaurantDisplayName,
  }) async {
    final plan = ReceiptCashierLayout.buildPrintPlan(
      order,
      restaurantDisplayName: restaurantDisplayName,
    );
    final bytes = <int>[];

    for (final line in plan.beforeQr) {
      bytes.addAll(await _emitCashierLine(generator, line));
      if (line.style == ReceiptLineStyle.customerTime &&
          order.latitude != null &&
          order.longitude != null) {
        bytes.addAll(
          await _lineRaw(
            generator,
            'GPS: ${order.latitude!.toStringAsFixed(5)}, '
            '${order.longitude!.toStringAsFixed(5)}',
          ),
        );
      }
    }

    for (final line in plan.afterQr) {
      bytes.addAll(await _emitCashierLine(generator, line));
    }

    return bytes;
  }

  static Future<List<int>> _emitCashierLine(
    Generator generator,
    ReceiptCashierLine line,
  ) async {
    if (line.isTable) {
      return _lineRaw(
        generator,
        ReceiptCashierLayout.formatReceiptRow(
          product: line.product!,
          quantity: line.quantity!,
          price: line.price!,
        ),
      );
    }

    final text = line.text?.trim() ?? '';
    if (text.isEmpty) return const <int>[];
    return _lineRaw(
      generator,
      line.center ? ReceiptCashierLayout.centerText(text) : text,
    );
  }

  static Future<List<int>> buildKitchenTicket(
    Generator generator,
    DeliveryOrder order, {
    String? restaurantDisplayName,
  }) async {
    final local = order.createdAt.toLocal();
    final bytes = <int>[];
    final headerName = _kitchenHeaderName(restaurantDisplayName);

    bytes
      ..addAll(await _lineRaw(generator, headerName))
      ..addAll(await _lineRaw(generator, 'بون المطبخ'))
      ..addAll(await _lineRaw(generator, ReceiptCashierLayout.separator()))
      ..addAll(
        await _lineRaw(
          generator,
          ReceiptCashierLayout.orderHeroText(order),
        ),
      )
      ..addAll(await _lineRaw(generator, 'الزبون: ${order.customerName}'))
      ..addAll(
        await _lineRaw(generator, ReceiptKitchenLayout.formatDateLine(local)),
      )
      ..addAll(
        await _lineRaw(generator, ReceiptKitchenLayout.formatTimeLine(local)),
      )
      ..addAll(await _lineRaw(generator, ReceiptCashierLayout.separator()));

    for (final item in order.items) {
      for (final line in ReceiptKitchenLayout.itemLines(
        quantity: item.quantity,
        name: item.displayName,
      )) {
        bytes.addAll(await _lineRaw(generator, line));
      }
      for (final addon in item.selectedAddons) {
        for (final line in ReceiptKitchenLayout.addonLines(
          quantity: addon.quantity,
          name: addon.name,
        )) {
          bytes.addAll(await _lineRaw(generator, line));
        }
      }
    }

    bytes.addAll(await _lineRaw(generator, '--- نهاية البون ---'));

    return bytes;
  }
}
