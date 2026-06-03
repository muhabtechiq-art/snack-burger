import 'package:shared_preferences/shared_preferences.dart';

/// يحفظ آخر طلب للزبون محلياً (لكل مطعم) لعرض «طلباتي».
abstract final class CustomerOrderSession {
  static String _key(String slug) => 'customer_last_order_${slug.trim().toLowerCase()}';

  static Future<String?> getLastOrderId(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key(slug))?.trim();
    return value != null && value.isNotEmpty ? value : null;
  }

  static Future<void> saveLastOrderId({
    required String slug,
    required String orderId,
  }) async {
    final normalized = orderId.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(slug), normalized);
  }

  static Future<void> clearLastOrderId(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(slug));
  }
}
