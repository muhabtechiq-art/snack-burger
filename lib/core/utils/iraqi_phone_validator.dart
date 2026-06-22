/// تحقق من أرقام الهاتف العراقية: 11 رقماً تبدأ بـ 0.
abstract final class IraqiPhoneValidator {
  IraqiPhoneValidator._();

  static const int requiredLength = 11;

  static final RegExp _pattern = RegExp(r'^0\d{10}$');

  static String normalize(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('964') && digits.length > 10) {
      digits = digits.substring(3);
    }
    if (digits.length == 10 && !digits.startsWith('0')) {
      digits = '0$digits';
    }
    return digits;
  }

  /// مطابقة أرقام بعد [normalize] — لطلبات «طلباتي».
  static bool phonesMatch(String a, String b) {
    final left = normalize(a);
    final right = normalize(b);
    if (left.isEmpty || right.isEmpty) return false;
    return left == right;
  }

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
