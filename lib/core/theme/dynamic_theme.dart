import 'package:flutter/material.dart';

import '../../models/restaurant_model.dart';
import 'tenant_palette.dart';

/// بناء سمة Material من ألوان المطعم فقط — بدون ألوان ثابتة للعلامة.
ThemeData buildDynamicTheme(RestaurantModel? restaurant) {
  final palette = TenantPalette.fromRestaurant(restaurant);

  final scheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    primary: palette.primary,
    secondary: palette.accent,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: scheme.surface,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.accent,
      foregroundColor: palette.onAccent,
    ),
  );
}
