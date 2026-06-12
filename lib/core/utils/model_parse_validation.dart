import 'package:flutter/foundation.dart';

/// تحذيرات موحّدة عند نقص حقول إلزامية أثناء تحليل صفوف Supabase.
abstract final class ModelParseValidation {
  ModelParseValidation._();

  static String recordIdFromMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id == null) return '(no id)';
    final text = id.toString().trim();
    return text.isEmpty ? '(empty id)' : text;
  }

  static bool isMissing(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return false;
  }

  /// يتحقق من وجود قيمة غير فارغة في أي من [keys].
  static bool hasAnyValue(Map<String, dynamic> map, List<String> keys) {
    return keys.any((key) => !isMissing(map[key]));
  }

  /// يُرجع أسماء الحقول الإلزامية التي لم تُوجَد في [fieldKeys].
  static List<String> collectMissing(
    Map<String, dynamic> map,
    Map<String, List<String>> fieldKeys,
  ) {
    final missing = <String>[];
    for (final entry in fieldKeys.entries) {
      if (!hasAnyValue(map, entry.value)) {
        missing.add(entry.key);
      }
    }
    return missing;
  }

  static void warnMissingFields({
    required String modelName,
    required Map<String, dynamic> source,
    required List<String> missingFields,
  }) {
    if (missingFields.isEmpty) return;
    debugPrint(
      '[ModelParseValidation] $modelName id=${recordIdFromMap(source)} '
      'missing/null fields: ${missingFields.join(', ')}',
    );
  }
}
