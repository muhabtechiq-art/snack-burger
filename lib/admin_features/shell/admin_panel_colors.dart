import 'package:flutter/material.dart';

import '../../core/theme/tenant_palette.dart';

/// ألوان لوحة التحكم الإدارية (فحمي + ذهبي).
abstract final class AdminPanelColors {
  static const charcoal = SnackBurgerBrandColors.primary;
  static const charcoalLight = SnackBurgerBrandColors.warm;
  static const gold = SnackBurgerBrandColors.accent;
  static const goldMuted = Color(0xFFFFE082);
  static const textLight = Colors.white;
  static const textMuted = Color(0xFFFFF3D1);
  static const cardCream = Color(0xFFFFFBF2);
  static const cardLight = Color(0xFFFFF8E7);

  static LinearGradient get loginGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          charcoal,
          Color.lerp(charcoal, const Color(0xFF7A1C2A), 0.35)!,
          Color.lerp(charcoalLight, charcoal, 0.2)!,
        ],
      );

  static LinearGradient get panelGradient => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          charcoal,
          Color.lerp(charcoalLight, charcoal, 0.35)!,
        ],
      );
}
