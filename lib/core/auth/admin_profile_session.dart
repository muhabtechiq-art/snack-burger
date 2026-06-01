import 'package:shared_preferences/shared_preferences.dart';

/// جلسة المسؤول — `restaurant_id` و `role` للفلترة في واجهة الإدارة.
abstract final class AdminProfileSession {
  AdminProfileSession._();

  static const String _restaurantIdKey = 'admin_restaurant_id';
  static const String _roleKey = 'admin_role';

  /// قيمة في الذاكرة — تُستخدم فوراً بعد تسجيل الدخول.
  static String? restaurantId;

  static String? role;

  static Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    restaurantId = _readNullable(prefs.getString(_restaurantIdKey));
    role = _readNullable(prefs.getString(_roleKey));
  }

  static Future<void> save({
    required String restaurantId,
    required String role,
  }) async {
    final normalizedRestaurantId = restaurantId.trim();
    final normalizedRole = role.trim();

    AdminProfileSession.restaurantId =
        normalizedRestaurantId.isEmpty ? null : normalizedRestaurantId;
    AdminProfileSession.role =
        normalizedRole.isEmpty ? null : normalizedRole;

    final prefs = await SharedPreferences.getInstance();
    if (AdminProfileSession.restaurantId == null) {
      await prefs.remove(_restaurantIdKey);
    } else {
      await prefs.setString(_restaurantIdKey, AdminProfileSession.restaurantId!);
    }
    if (AdminProfileSession.role == null) {
      await prefs.remove(_roleKey);
    } else {
      await prefs.setString(_roleKey, AdminProfileSession.role!);
    }
  }

  static Future<void> clear() async {
    restaurantId = null;
    role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_restaurantIdKey);
    await prefs.remove(_roleKey);
  }

  static String? _readNullable(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
