import 'dart:math';

/// توليد معرّفات منتجات متوافقة مع عمود `integer` في PostgreSQL.
abstract final class ProductIdGenerator {
  ProductIdGenerator._();

  static const int _maxPostgresInt = 2147483647;
  static final Random _random = Random();

  /// معرّف جديد يقع ضمن نطاق `integer` (32-bit).
  static String newId() {
    final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final suffix = _random.nextInt(10_000);
    var candidate = seconds + suffix;
    if (candidate > _maxPostgresInt) {
      candidate = _maxPostgresInt - _random.nextInt(1_000_000) - 1;
    }
    return candidate.toString();
  }

  /// يحوّل المعرّف لإرسال Supabase — رقم إن أمكن.
  static dynamic serializeForSupabase(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return asInt;
    return trimmed;
  }
}
