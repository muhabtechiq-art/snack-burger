import 'package:flutter/material.dart';

import '../../models/restaurant_model.dart';

/// ألوان هوية Snack Burger المستوحاة من اللوجو.
abstract final class SnackBurgerBrandColors {
  /// أحمر الشعار الرئيسي.
  static const Color primary = Color(0xFFB31217);

  /// أصفر ذهبي لعناصر الإبراز.
  static const Color accent = Color(0xFFF6D21E);

  /// برتقالي داعم لعناصر ثانوية.
  static const Color warm = Color(0xFFF39A22);

  /// لون نص داكن متباين.
  static const Color ink = Color(0xFF1E1712);
}

/// ألوان المطعم المستخرجة من Firestore لاستخدامها في واجهة المنيو.
class TenantPalette {
  const TenantPalette({
    required this.primary,
    required this.accent,
  });

  final Color primary;
  final Color accent;

  factory TenantPalette.fromRestaurant(RestaurantModel? restaurant) {
    return TenantPalette(
      primary: parseFirestoreColor(restaurant?.primaryColorHex) ??
          SnackBurgerBrandColors.primary,
      accent: parseFirestoreColor(restaurant?.accentColorHex) ??
          SnackBurgerBrandColors.accent,
    );
  }

  LinearGradient get bannerGradient => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          primary,
          Color.lerp(primary, Colors.black, 0.42)!,
        ],
      );

  LinearGradient get bannerOverlay => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.08),
          Colors.black.withValues(alpha: 0.55),
        ],
      );

  LinearGradient get sectionGradient => LinearGradient(
        colors: [
          primary.withValues(alpha: 0.1),
          primary.withValues(alpha: 0.03),
        ],
      );

  Color get onPrimary => _contrastOn(primary);

  Color get onAccent => _contrastOn(accent);

  Color get surfaceTint => Color.lerp(Colors.white, SnackBurgerBrandColors.warm, 0.06)!;
}

/// يحوّل قيم Firestore (`#8B0000`, `8B0000`, `4287299584`, …) إلى [Color].
Color? parseFirestoreColor(dynamic raw) {
  if (raw == null) return null;

  if (raw is Color) return raw;

  if (raw is int) {
    if (raw <= 0xFFFFFF) return Color(0xFF000000 | raw);
    return Color(raw);
  }

  if (raw is num) {
    final value = raw.toInt();
    if (value <= 0xFFFFFF) return Color(0xFF000000 | value);
    return Color(value);
  }

  if (raw is! String) return null;

  final value = raw.trim();
  if (value.isEmpty) return null;

  final intValue = int.tryParse(value);
  if (intValue != null) {
    if (intValue <= 0xFFFFFF) return Color(0xFF000000 | intValue);
    return Color(intValue);
  }

  return parseHexColor(value);
}

Color? parseHexColor(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  var s = raw.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 3) {
    s = s.split('').map((c) => '$c$c').join();
  }
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  return Color(v);
}

Color _contrastOn(Color background) {
  return background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
}

/// يقرأ أول حقل لون متاح من خريطة Firestore.
String? readFirestoreColorField(
  Map<String, dynamic> map,
  List<String> keys,
) {
  for (final key in keys) {
    if (!map.containsKey(key) || map[key] == null) continue;
    final color = parseFirestoreColor(map[key]);
    if (color != null) {
      final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
      return '#${argb.substring(2)}';
    }
  }
  return null;
}

String? readFirestoreStringField(
  Map<String, dynamic> map,
  List<String> keys,
) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
