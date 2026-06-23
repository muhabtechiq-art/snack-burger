import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/restaurant_slug_utils.dart';

/// يحفظ جلسة الزبون محلياً (لكل مطعم): آخر طلب ورقم الهاتف لـ «طلباتي».
abstract final class CustomerOrderSession {
  static String _orderKey(String slug) =>
      'customer_last_order_${normalizeRestaurantSlug(slug)}';

  static String _phoneKey(String slug) =>
      'customer_phone_${normalizeRestaurantSlug(slug)}';

  static String _legacyPhoneKey(String slug) =>
      'customer_phone_${slug.trim().toLowerCase()}';

  static String _legacyOrderKey(String slug) =>
      'customer_last_order_${slug.trim().toLowerCase()}';

  static Future<String?> getLastOrderId(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _orderKey(slug);
    var value = prefs.getString(key)?.trim();
    if (value == null || value.isEmpty) {
      final legacyKey = _legacyOrderKey(slug);
      if (legacyKey != key) {
        value = prefs.getString(legacyKey)?.trim();
      }
    }
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
    final key = _phoneKey(slug);
    var value = prefs.getString(key)?.trim();
    if (value == null || value.isEmpty) {
      final legacyKey = _legacyPhoneKey(slug);
      if (legacyKey != key) {
        value = prefs.getString(legacyKey)?.trim();
      }
    }
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

  static Future<void> logStoredPhoneDiagnostic(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _phoneKey(slug);
    final stored = prefs.getString(key);
    final legacyKey = _legacyPhoneKey(slug);
    final legacy = legacyKey != key ? prefs.getString(legacyKey) : null;
    // ignore: avoid_print
    print(
      '[MY_ORDERS_PHONE] prefsKey=$key storedPhone=$stored '
      'legacyKey=$legacyKey legacyPhone=$legacy',
    );
  }

  static Future<void> clearCustomerPhone(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_phoneKey(slug));
  }
}
