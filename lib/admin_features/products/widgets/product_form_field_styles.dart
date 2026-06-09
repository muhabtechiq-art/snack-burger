import 'package:flutter/material.dart';

import '../../../core/theme/tenant_palette.dart';

/// نمط حقول نموذج المنتج — خردلي الشعار مع نص داكن للتباين.
abstract final class ProductFormFieldStyles {
  ProductFormFieldStyles._();

  /// خلفية الحقول — ذهبي/خردلي الشعار.
  static const Color fillColor = SnackBurgerBrandColors.accent;

  static const Color textColor = Colors.black87;

  static const BorderRadius borderRadius = BorderRadius.all(Radius.circular(12));

  static InputDecoration decoration({
    String? labelText,
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: fillColor,
      labelText: labelText,
      hintText: hintText,
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(color: textColor),
      hintStyle: TextStyle(color: textColor.withValues(alpha: 0.55)),
      border: const OutlineInputBorder(borderRadius: borderRadius),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: textColor.withValues(alpha: 0.25)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: textColor, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  static InputDecorationTheme inputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      labelStyle: const TextStyle(color: textColor),
      hintStyle: TextStyle(color: textColor.withValues(alpha: 0.55)),
      border: const OutlineInputBorder(borderRadius: borderRadius),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: textColor.withValues(alpha: 0.25)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: textColor, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  static ThemeData wrap(BuildContext context) {
    return Theme.of(context).copyWith(
      inputDecorationTheme: inputDecorationTheme(),
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: textColor,
            displayColor: textColor,
          ),
    );
  }
}
