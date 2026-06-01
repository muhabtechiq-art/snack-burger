import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/config/pos_code_table.dart';
import '../core/config/printer_config.dart';
import '../models/delivery_order_model.dart';
import '../models/end_of_day_report_model.dart';
import 'receipt_raster_builder.dart';
import 'receipt_text_encoder.dart';

/// يبني بايتات ESC/POS خام للفاتورة (كاشير + مطبخ) بترميز CP864.
abstract final class ReceiptEscPosBuilder {
  static Future<({CapabilityProfile profile, String arabicCodePage})>
      _loadPrintContext() async {
    for (final name in PrinterConfig.escPosProfileFallbacks) {
      try {
        final profile = await CapabilityProfile.load(name: name);
        final arabicCodePage = PosCodeTable.resolveArabicCodePage(profile);
        debugPrint(
          '[ReceiptEscPosBuilder] profile="$name" arabicCodePage=$arabicCodePage',
        );
        return (profile: profile, arabicCodePage: arabicCodePage);
      } catch (e, stack) {
        debugPrint(
          '[ReceiptEscPosBuilder] skip profile "$name": $e\n$stack',
        );
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

  static Future<({CapabilityProfile profile, String arabicCodePage})>
      _printContext() async {
    return _loadPrintContext();
  }

  /// reset + ESC t n — مرة واحدة قبل النص.
  static List<int> _selectCodePage(Generator generator, int codePageId) {
    debugPrint('[ReceiptEscPosBuilder] ESC t $codePageId');
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
    if (PrinterConfig.useRasterReceipt) {
      return buildOrderReceiptRasterBytes(order);
    }
    return buildOrderReceiptTextBytes(order);
  }

  static Future<List<int>> buildOrderReceiptTextBytes(
    DeliveryOrder order,
  ) async {
    final ctx = await _printContext();
    final generator = Generator(PaperSize.mm80, ctx.profile);
    const codePageId = PrinterConfig.arabicCodePageId;

    final bytes = <int>[];
    bytes
      ..addAll(_beginReceipt(generator, codePageId))
      ..addAll(await buildCashierTicket(generator, order))
      ..addAll(generator.feed(2))
      ..addAll(generator.cut())
      ..addAll(_beginReceipt(generator, codePageId))
      ..addAll(await buildKitchenTicket(generator, order))
      ..addAll(generator.feed(2))
      ..addAll(generator.cut());

    return bytes;
  }

  static Future<List<int>> buildOrderReceiptRasterBytes(
    DeliveryOrder order,
  ) async {
    final generator = await _newGenerator();
    final cashier = await ReceiptRasterBuilder.buildCashierImage(order);
    final kitchen = await ReceiptRasterBuilder.buildKitchenImage(order);

    final bytes = <int>[
      ...generator.reset(),
      ...generator.image(cashier, align: PosAlign.center),
      ...generator.feed(2),
      ...generator.cut(),
      ...generator.reset(),
      ...generator.image(kitchen, align: PosAlign.center),
      ...generator.feed(2),
      ...generator.cut(),
    ];

    debugPrint(
      '[ReceiptEscPosBuilder] raster order '
      '${cashier.width}x${cashier.height}+${kitchen.width}x${kitchen.height} '
      '→ ${bytes.length} bytes (~${(bytes.length / 1024).toStringAsFixed(1)} KB)',
    );
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

    final bytes = <int>[
      ...generator.reset(),
      ...generator.image(image, align: PosAlign.center),
      ...generator.feed(2),
      ...generator.cut(),
    ];

    debugPrint(
      '[ReceiptEscPosBuilder] raster EOD ${image.width}x${image.height} '
      '→ ${bytes.length} bytes (~${(bytes.length / 1024).toStringAsFixed(1)} KB)',
    );
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
      (await _printContext()).profile,
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

    final bytes = <int>[
      ...generator.reset(),
      ...generator.image(image, align: PosAlign.center),
      ...generator.feed(2),
      ...generator.cut(),
    ];

    debugPrint(
      '[ReceiptEscPosBuilder] raster test ${image.width}x${image.height} '
      '→ ${bytes.length} bytes (~${(bytes.length / 1024).toStringAsFixed(1)} KB)',
    );
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
    DeliveryOrder order,
  ) async {
    final local = order.createdAt.toLocal();
    final dateStr = _formatDateTime(local);
    final bytes = <int>[];

    bytes
      ..addAll(await _lineRaw(generator, PrinterConfig.restaurantDisplayName))
      ..addAll(await _lineRaw(generator, 'فاتورة الكاشير'))
      ..addAll(await _lineRaw(generator, '------------------------------'))
      ..addAll(await _lineRaw(generator, 'الزبون: ${order.customerName}'))
      ..addAll(await _lineRaw(generator, 'الهاتف: ${order.customerPhone}'))
      ..addAll(await _lineRaw(generator, 'العنوان: ${order.address}'));

    if (order.latitude != null && order.longitude != null) {
      bytes.addAll(
        await _lineRaw(
          generator,
          'GPS: ${order.latitude!.toStringAsFixed(5)}, '
          '${order.longitude!.toStringAsFixed(5)}',
        ),
      );
    }

    bytes
      ..addAll(await _lineRaw(generator, 'الوقت: $dateStr'))
      ..addAll(await _lineRaw(generator, '------------------------------'))
      ..addAll(await _lineRaw(generator, 'الوجبات'));

    for (final item in order.items) {
      bytes.addAll(
        await _lineRaw(
          generator,
          '${item.name}  x${item.quantity}  '
          '${item.lineTotal.toStringAsFixed(0)} د.ع',
        ),
      );
      for (final addon in item.selectedAddons) {
        bytes.addAll(
          await _lineRaw(
            generator,
            '  + ${addon.name}  x${addon.quantity}  '
            '${addon.lineTotal.toStringAsFixed(0)} د.ع',
          ),
        );
      }
    }

    bytes
      ..addAll(await _lineRaw(generator, '------------------------------'))
      ..addAll(
        await _lineRaw(
          generator,
          'الإجمالي: ${order.totalPrice.toStringAsFixed(0)} د.ع',
        ),
      )
      ..addAll(await _lineRaw(generator, 'شكراً لطلبكم'));

    return bytes;
  }

  static Future<List<int>> buildKitchenTicket(
    Generator generator,
    DeliveryOrder order,
  ) async {
    final local = order.createdAt.toLocal();
    final dateStr = _formatDateTime(local);
    final bytes = <int>[];

    bytes
      ..addAll(await _lineRaw(generator, PrinterConfig.restaurantDisplayName))
      ..addAll(await _lineRaw(generator, 'بون المطبخ'))
      ..addAll(await _lineRaw(generator, '------------------------------'))
      ..addAll(await _lineRaw(generator, 'الزبون: ${order.customerName}'))
      ..addAll(await _lineRaw(generator, 'الوقت: $dateStr'))
      ..addAll(await _lineRaw(generator, '------------------------------'));

    for (final item in order.items) {
      bytes.addAll(
        await _lineRaw(
          generator,
          'x${item.quantity}  ${item.name}',
        ),
      );
      for (final addon in item.selectedAddons) {
        bytes.addAll(
          await _lineRaw(
            generator,
            '  + x${addon.quantity}  ${addon.name}',
          ),
        );
      }
    }

    bytes.addAll(await _lineRaw(generator, '--- نهاية البون ---'));

    return bytes;
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
        '${_two(dt.hour)}:${_two(dt.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
