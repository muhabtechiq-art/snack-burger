import 'package:flutter/foundation.dart';

/// غلاف وقائي للعمليات async — يسجّل الخطأ ولا يُسقط التطبيق.
Future<T?> safeExecute<T>(
  Future<T> Function() action, {
  String tag = 'safeExecute',
}) async {
  try {
    return await action();
  } catch (e, stack) {
    debugPrint('[$tag] $e\n$stack');
    return null;
  }
}

/// نسخة void — تُرجع `true` عند النجاح و`false` عند أي خطأ.
Future<bool> safeExecuteVoid(
  Future<void> Function() action, {
  String tag = 'safeExecute',
}) async {
  try {
    await action();
    return true;
  } catch (e, stack) {
    debugPrint('[$tag] $e\n$stack');
    return false;
  }
}
