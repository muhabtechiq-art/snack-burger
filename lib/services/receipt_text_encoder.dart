import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:flutter/foundation.dart';

import 'cp1256_table.dart';
import 'cp864_table.dart';

enum ReceiptCharset { cp864, cp1256 }

/// ترميز نص الفاتورة لطابعات ESC/POS (CP864 أو Windows-1256).
abstract final class ReceiptTextEncoder {
  static Future<Uint8List> encode(
    String text, {
    ReceiptCharset charset = ReceiptCharset.cp864,
  }) async {
    final prepared = _prepareForThermalRtl(text);
    final runes = prepared.runes.toList();
    final bytes = Uint8List(runes.length);
    for (var i = 0; i < runes.length; i++) {
      bytes[i] = _encodeRune(runes[i], charset);
    }
    debugPrint(
      '[ReceiptTextEncoder] $charset "$text" → '
      '${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    return bytes;
  }

  /// 1) تشكيل عربي متصل (arabic_reshaper)
  /// 2) عكس ترتيب المقاطع فقط — الأرقام/الإنجليزي تبقى LTR
  /// 3) عكس حروف المقطع العربي للطابعة الحرارية LTR
  static String _prepareForThermalRtl(String text) {
    if (!ArabicReshaper.isArabic(text)) return text;

    final runs = _splitRuns(text);
    final processed = runs.map((run) {
      if (run.isArabic) {
        final shaped = ArabicReshaper.instance.reshape(run.text);
        // أشكال العرض → حروف منطقية صحيحة (ج ≠ ش) ثم عكس للـ RTL
        final logical = shaped.runes
            .map((r) => Cp864Table.toLogicalRune(r) ?? r)
            .toList();
        return String.fromCharCodes(logical.reversed);
      }
      return run.text;
    }).toList();

    return processed.reversed.join();
  }

  static List<_TextRun> _splitRuns(String text) {
    final runes = text.runes.toList();
    if (runes.isEmpty) return const [];

    final runs = <_TextRun>[];
    var start = 0;
    var isArabic = _isArabicRune(runes[0]);

    for (var i = 1; i < runes.length; i++) {
      final ar = _isArabicRune(runes[i]);
      if (ar != isArabic) {
        runs.add(
          _TextRun(
            String.fromCharCodes(runes.sublist(start, i)),
            isArabic,
          ),
        );
        start = i;
        isArabic = ar;
      }
    }
    runs.add(
      _TextRun(
        String.fromCharCodes(runes.sublist(start)),
        isArabic,
      ),
    );
    return runs;
  }

  static bool _isArabicRune(int rune) {
    return (rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x0750 && rune <= 0x077F) ||
        (rune >= 0xFE70 && rune <= 0xFEFF);
  }

  static int _encodeRune(int rune, ReceiptCharset charset) {
    return switch (charset) {
      ReceiptCharset.cp864 => Cp864Table.encodeRune(rune),
      ReceiptCharset.cp1256 => Cp1256Table.encodeRune(rune),
    };
  }
}

class _TextRun {
  const _TextRun(this.text, this.isArabic);
  final String text;
  final bool isArabic;
}

/// ترميز CP864 — للتوافق مع الاستدعاءات القديمة.
abstract final class Cp864Encoder {
  static Future<Uint8List> encode(String text) =>
      ReceiptTextEncoder.encode(text, charset: ReceiptCharset.cp864);
}
