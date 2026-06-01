/// تحقق من أرقام الهاتف العراقية: 11 رقماً تبدأ بـ 0.
abstract final class IraqiPhoneValidator {
  IraqiPhoneValidator._();

  static const int requiredLength = 11;

  static final RegExp _pattern = RegExp(r'^0\d{10}$');

  static String normalize(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  static String? validate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'مطلوب';
    }

    final digits = normalize(raw);
    if (!digits.startsWith('0')) {
      return 'يجب أن يبدأ الرقم بـ 0';
    }
    if (digits.length != requiredLength) {
      return 'يجب أن يتكون من 11 رقماً بالضبط';
    }
    if (!_pattern.hasMatch(digits)) {
      return 'رقم غير صالح';
    }
    return null;
  }
}
