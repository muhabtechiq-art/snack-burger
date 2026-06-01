import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

/// رموز جداول الأحرف ESC/POS — تُطابق أسماء capabilities.json.
abstract final class PosCodeTable {
  /// IBM code page 864 — عربي (الاسم في أغلب البروفايلات: CP864).
  static const String cp864 = 'CP864';

  /// بعض الطابعات (مثل TP806L) تستخدم PC864 بدلاً من CP864.
  static const String pc864 = 'PC864';

  static const List<String> arabicCandidates = [pc864, cp864];

  /// ESC t n — اختيار جدول الرموز (n = id من capabilities أو [PrinterConfig.arabicCodePageId]).
  static List<int> escSelectCodePageId(int id) => [27, 116, id];

  /// يختار CP864 أو PC864 حسب ما يدعمه [profile].
  static String resolveArabicCodePage(CapabilityProfile profile) {
    for (final name in arabicCandidates) {
      try {
        profile.getCodePageId(name);
        return name;
      } catch (_) {
        // جرّب الاسم التالي
      }
    }
    throw StateError(
      "Arabic code page (CP864/PC864) isn't defined for profile '${profile.name}'",
    );
  }
}
