import '../../core/utils/price_utils.dart';

/// قواعد التحقق المشتركة لنموذج المنتج (UI + Controller).
abstract final class ProductFormValidators {
  static final RegExp _digitsOnlyPattern = RegExp(r'^\d+$');

  static String? validateRequiredName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'اسم الوجبة مطلوب';
    }
    return null;
  }

  static String? validateRequiredCategory(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'التصنيف مطلوب';
    }
    return null;
  }

  static String? validatePositivePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'السعر مطلوب';
    }

    final digits = PriceUtils.digitsOnly(value);
    if (!_digitsOnlyPattern.hasMatch(digits)) {
      return 'أدخل أرقاماً فقط';
    }

    final price = PriceUtils.tryParsePriceInput(digits);
    if (price == null) {
      return 'يجب أن يكون السعر أكبر من 0';
    }

    return null;
  }

  static double? parsePositivePrice(String raw) {
    final price = PriceUtils.tryParsePriceInput(raw);
    if (price == null) return null;
    return price.toDouble();
  }
}
