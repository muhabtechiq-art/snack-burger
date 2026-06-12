import 'package:flutter/material.dart';

import '../../models/restaurant_model.dart';
import '../theme/customer_menu_theme.dart';

/// شاشة البداية — خلفية خردلية، شعار نصي، زر Start Order.
class CustomerWelcomeScreen extends StatelessWidget {
  const CustomerWelcomeScreen({
    super.key,
    required this.restaurant,
    required this.onStartOrder,
  });

  final RestaurantModel restaurant;
  final VoidCallback onStartOrder;

  @override
  Widget build(BuildContext context) {
    final slugLabel = restaurant.slug
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: CustomerMenuTheme.mustard,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Text(
                  restaurant.name.trim().isNotEmpty
                      ? restaurant.name.trim()
                      : 'Snack Burger',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: CustomerMenuTheme.ink,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  slugLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: CustomerMenuTheme.ink.withValues(alpha: 0.65),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.35),
                    border: Border.all(
                      color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/menu_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.restaurant_rounded,
                        size: 40,
                        color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onStartOrder,
                    style: FilledButton.styleFrom(
                      backgroundColor: CustomerMenuTheme.mutedRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(CustomerMenuTheme.radiusLg),
                      ),
                      elevation: 4,
                      shadowColor:
                          CustomerMenuTheme.mutedRed.withValues(alpha: 0.35),
                    ),
                    child: const Text(
                      'Start Order',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
