import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Telemetry خفيف قابل للترحيل لاحقاً إلى Sentry/Crashlytics.
abstract final class AppTelemetry {
  AppTelemetry._();

  static final Random _random = Random();

  static String newCorrelationId({required String scope}) {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final entropy = _random.nextInt(0x7fffffff).toRadixString(16);
    return '$scope-$now-$entropy';
  }

  static void logEvent(
    String name, {
    String? correlationId,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    final payload = <String, Object?>{
      'event': name,
      'ts': DateTime.now().toIso8601String(),
      ...?correlationId != null
          ? <String, Object?>{'correlation_id': correlationId}
          : null,
      ...fields,
    };
    debugPrint('[telemetry] ${jsonEncode(payload)}');
  }

  static void logError(
    String name, {
    required Object error,
    StackTrace? stackTrace,
    String? correlationId,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    logEvent(
      name,
      correlationId: correlationId,
      fields: <String, Object?>{
        ...fields,
        'error': error.toString(),
        if (stackTrace != null) 'stack': stackTrace.toString(),
      },
    );
  }
}
