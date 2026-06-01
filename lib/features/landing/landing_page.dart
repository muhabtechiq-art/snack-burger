import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// صفحة ترحيب مبسّطة — توجيه مباشر للمنيو الموحّد.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Al-Mahab Menu',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'جميع وظائف الإدارة متاحة من القائمة الجانبية داخل المنيو.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => context.go('/snack_burger'),
                  icon: const Icon(Icons.restaurant_menu_rounded),
                  label: const Text('فتح Snack Burger'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
