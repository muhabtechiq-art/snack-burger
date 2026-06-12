import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../observability/app_telemetry.dart';

/// معالج أخطاء عام — تسجيل + Snackbar عبر [scaffoldMessengerKey].
abstract final class AppErrorHandler {
  AppErrorHandler._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// يسجّل الخطأ ويعرض Snackbar (إن وُجد ScaffoldMessenger).
  static void handle(
    Object error,
    StackTrace stackTrace, {
    String? operation,
    bool showSnackBar = true,
  }) {
    AppTelemetry.logError(
      'app_error',
      error: error,
      stackTrace: stackTrace,
      fields: <String, Object?>{
        if (operation != null) 'operation': operation,
      },
    );
    debugPrint(
      '[AppErrorHandler]${operation != null ? ' $operation' : ''}: '
      '$error\n$stackTrace',
    );

    if (!showSnackBar) return;
    showMessage(formatError(error, operation: operation));
  }

  /// يعرض رسالة في Snackbar دون تسجيل إضافي.
  static void showMessage(String message) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      debugPrint('[AppErrorHandler] لا يوجد ScaffoldMessenger — $message');
      return;
    }

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB71C1C),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static String formatError(Object error, {String? operation}) {
    final prefix = operation != null ? '$operation: ' : '';
    if (error is PostgrestException) {
      final message = error.message.trim();
      return message.isEmpty ? '$prefixخطأ في Supabase' : '$prefix$message';
    }
    if (error is AuthException) {
      return '$prefix${error.message}';
    }
    if (error is RealtimeSubscribeException) {
      return '$prefixانقطع اتصال Realtime — إعادة المحاولة…';
    }
    return '$prefix$error';
  }
}
