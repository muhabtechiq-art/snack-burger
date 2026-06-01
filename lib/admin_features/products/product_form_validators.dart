/// قواعد التحقق المشتركة لنموذج المنتج (UI + Controller).
abstract final class ProductFormValidators {
  static final RegExp _positiveNumberPattern = RegExp(r'^\d+(\.\d+)?$');

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

    final normalized = value.trim().replaceAll(',', '');
    if (!_positiveNumberPattern.hasMatch(normalized)) {
      return 'أدخل رقماً صالحاً';
    }

    final price = double.tryParse(normalized);
    if (price == null || price <= 0) {
      return 'يجب أن يكون السعر أكبر من 0';
    }

    return null;
  }

  static double? parsePositivePrice(String raw) {
    final normalized = raw.trim().replaceAll(',', '');
    if (!_positiveNumberPattern.hasMatch(normalized)) return null;

    final price = double.tryParse(normalized);
    if (price == null || price <= 0) return null;

    return price;
  }
}
