import 'dart:async';

/// مهلة موحّدة لعمليات الشبكة — 8–10 ثوانٍ.
abstract final class NetworkTimeouts {
  NetworkTimeouts._();

  static const Duration standard = Duration(seconds: 9);
  static const Duration orderSubmit = Duration(seconds: 10);

  static Future<T> run<T>(
    Future<T> Function() action, {
    Duration timeout = standard,
    String? timeoutMessage,
  }) async {
    try {
      return await action().timeout(timeout);
    } on TimeoutException {
      throw NetworkTimeoutException(
        timeoutMessage ??
            'انتهت مهلة الاتصال. تحقق من الإنترنت وحاول مرة أخرى',
      );
    }
  }
}

/// يُرمى عند تجاوز مهلة الشبكة.
final class NetworkTimeoutException implements Exception {
  const NetworkTimeoutException([this.message = 'انتهت مهلة الاتصال']);

  final String message;

  @override
  String toString() => message;
}

bool isLikelyNetworkFailure(Object error) {
  if (error is NetworkTimeoutException) return true;
  if (error is TimeoutException) return true;
  final raw = error.toString().toLowerCase();
  return raw.contains('socket') ||
      raw.contains('network') ||
      raw.contains('connection') ||
      raw.contains('timeout') ||
      raw.contains('failed host lookup') ||
      raw.contains('internet');
}
