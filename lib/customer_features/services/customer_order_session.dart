import 'package:shared_preferences/shared_preferences.dart';

/// يحفظ جلسة الزبون محلياً (لكل مطعم): آخر طلب ورقم الهاتف لـ «طلباتي».
abstract final class CustomerOrderSession {
  static String _orderKey(String slug) =>
      'customer_last_order_${slug.trim().toLowerCase()}';

  static String _phoneKey(String slug) =>
      'customer_phone_${slug.trim().toLowerCase()}';

  static Future<String?> getLastOrderId(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_orderKey(slug))?.trim();
    return value != null && value.isNotEmpty ? value : null;
  }

  static Future<void> saveLastOrderId({
    required String slug,
    required String orderId,
  }) async {
    final normalized = orderId.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_orderKey(slug), normalized);
  }

  static Future<String?> getCustomerPhone(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_phoneKey(slug))?.trim();
    return value != null && value.isNotEmpty ? value : null;
  }

  static Future<void> saveCustomerPhone({
    required String slug,
    required String phoneNumber,
  }) async {
    final normalized = phoneNumber.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey(slug), normalized);
  }

  static Future<void> clearLastOrderId(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_orderKey(slug));
  }

  static Future<void> clearCustomerPhone(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_phoneKey(slug));
  }
}
