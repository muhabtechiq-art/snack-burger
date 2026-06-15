import 'package:flutter/foundation.dart';

/// تطبيع وعرض أسعار المنيو — Supabase يخزن int فقط (مثل 6000).
abstract final class PriceUtils {
  PriceUtils._();

  static final RegExp _nonDigitPattern = RegExp(r'[^\d]');

  /// يحوّل أي قيمة إلى سعر صحيح بدون كسور.
  static int normalizePrice(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value < 0 ? 0 : value;
    }

    if (value is double) {
      final rounded = value.round();
      return rounded < 0 ? 0 : rounded;
    }

    if (value is num) {
      final rounded = value.round();
      return rounded < 0 ? 0 : rounded;
    }

    final raw = value.toString().trim();
    if (raw.isEmpty) return 0;

    final withoutCommas = raw.replaceAll(',', '');

    // فواصل آلاف للعرض: 6.000 أو 18.000
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(withoutCommas)) {
      final parsed = int.tryParse(withoutCommas.replaceAll('.', ''));
      if (parsed != null) {
        return parsed < 0 ? 0 : parsed;
      }
    }

    // صيغة عشرية: 7000.0
    if (RegExp(r'^\d+\.\d+$').hasMatch(withoutCommas)) {
      final parsed = double.tryParse(withoutCommas);
      if (parsed != null) {
        final rounded = parsed.round();
        return rounded < 0 ? 0 : rounded;
      }
    }

    final digitsOnly = raw.replaceAll(_nonDigitPattern, '');
    if (digitsOnly.isEmpty) return 0;

    final parsed = int.tryParse(digitsOnly);
    final result = parsed ?? 0;

    if (kDebugMode && _shouldLogNormalize(raw)) {
      debugPrint('[QA][PriceNormalize] input=$raw output=$result');
    }

    return result;
  }

  static double normalizePriceAsDouble(dynamic value) =>
      normalizePrice(value).toDouble();

  /// عرض فقط — 6000 => 6.000
  static String formatPrice(dynamic value) {
    final amount = normalizePrice(value);
    final text = amount.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      final positionFromEnd = text.length - i;
      buffer.write(text[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return buffer.toString();
  }

  static String formatPriceWithCurrency(
    dynamic value, {
    String currency = 'د.ع',
  }) {
    return '${formatPrice(value)} $currency';
  }

  /// يستخرج أرقاماً فقط من إدخال لوحة الإدارة.
  static String digitsOnly(String raw) => raw.replaceAll(_nonDigitPattern, '');

  static int? tryParsePriceInput(String? raw) {
    if (raw == null) return null;
    final digits = digitsOnly(raw.trim());
    if (digits.isEmpty) return null;

    final value = int.tryParse(digits);
    if (value == null || value <= 0) return null;
    return value;
  }

  /// مفتاح مقارنة موحّد — لا يعتمد على النص الخام.
  static String normalizedPriceKey(dynamic value) =>
      normalizePrice(value).toString();

  static String variantDuplicateKey({
    required String productId,
    required String name,
    required dynamic price,
  }) {
    return '${productId.trim()}|${name.trim().toLowerCase()}|'
        '${normalizedPriceKey(price)}';
  }

  /// اقتراح تصحيح عند إدخال أصفار زائدة (مثل 70000 بدل 7000).
  static String? suspiciousPriceSuggestion(int normalized) {
    if (normalized < 50000) return null;

    for (final factor in [10, 100]) {
      if (normalized % factor != 0) continue;
      final candidate = normalized ~/ factor;
      if (candidate >= 1000 && candidate <= 50000) {
        return formatPrice(candidate);
      }
    }

    return null;
  }

  static bool _shouldLogNormalize(String raw) {
    return raw.contains('.') || raw.contains(',') || raw.contains(RegExp(r'[A-Za-z]'));
  }

  @visibleForTesting
  static void logFormattedPrice(dynamic value) {
    if (!kDebugMode) return;
    final amount = normalizePrice(value);
    debugPrint(
      '[QA][PriceFormat] raw=$amount formatted=${formatPrice(amount)}',
    );
  }
}

/// تحذير سعر مشبوه قبل الحفظ في لوحة الإدارة.
class SuspiciousPriceWarning {
  const SuspiciousPriceWarning({
    required this.label,
    required this.enteredFormatted,
    required this.suggestedFormatted,
    required this.onApplySuggestion,
  });

  final String label;
  final String enteredFormatted;
  final String suggestedFormatted;
  final void Function() onApplySuggestion;
}
