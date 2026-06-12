import '../core/errors/app_error_handler.dart';

/// تسجيل أخطاء عمليات Supabase — يُستدعى من كتل catch الموجودة.
void reportSupabaseError(
  Object error,
  StackTrace stackTrace, {
  required String operation,
  bool showSnackBar = true,
}) {
  AppErrorHandler.handle(
    error,
    stackTrace,
    operation: operation,
    showSnackBar: showSnackBar,
  );
}
