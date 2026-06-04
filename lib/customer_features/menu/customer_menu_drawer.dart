import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tenant_palette.dart';
import '../../models/restaurant_model.dart';

/// عنصر واحد في القائمة الجانبية — أضف عناصر جديدة في [buildDestinations].
class CustomerMenuDrawerDestination {
  const CustomerMenuDrawerDestination({
    required this.id,
    required this.title,
    required this.icon,
    required this.onSelected,
    this.subtitle,
    this.enabled = true,
  });

  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onSelected;
  final bool enabled;
}

/// مصدر عناصر القائمة — وسّع هذه القائمة لميزات مستقبلية (إعدادات، اتصل بنا، …).
List<CustomerMenuDrawerDestination> buildCustomerMenuDrawerDestinations({
  required BuildContext context,
  required String slug,
}) {
  return [
    CustomerMenuDrawerDestination(
      id: 'my_orders',
      title: 'طلباتي',
      subtitle: 'عرض طلباتك الأخيرة',
      icon: Icons.receipt_long_rounded,
      onSelected: () {
        Navigator.of(context).pop();
        context.pushNamed(
          'my-orders',
          pathParameters: {'slug': slug},
        );
      },
    ),
    // أضف عناصراً جديدة هنا، مثال:
    // CustomerMenuDrawerDestination(
    //   id: 'settings',
    //   title: 'إعدادات',
    //   icon: Icons.settings_outlined,
    //   onSelected: () { ... },
    // ),
  ];
}

/// القائمة الجانبية للمنيو — خفيفة ولا تعيد تحميل المنتجات أو السلة.
class CustomerMenuDrawer extends StatelessWidget {
  const CustomerMenuDrawer({
    super.key,
    required this.restaurant,
    required this.palette,
  });

  final RestaurantModel restaurant;
  final TenantPalette palette;

  @override
  Widget build(BuildContext context) {
    final destinations = buildCustomerMenuDrawerDestinations(
      context: context,
      slug: restaurant.slug,
    );

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DrawerHeaderSection(
              restaurant: restaurant,
              palette: palette,
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: destinations.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 72,
                  color: palette.primary.withValues(alpha: 0.08),
                ),
                itemBuilder: (context, index) {
                  final item = destinations[index];
                  return _DrawerDestinationTile(
                    destination: item,
                    palette: palette,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeaderSection extends StatelessWidget {
  const _DrawerHeaderSection({
    required this.restaurant,
    required this.palette,
  });

  final RestaurantModel restaurant;
  final TenantPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            palette.primary,
            Color.lerp(palette.primary, SnackBurgerBrandColors.ink, 0.35)!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            restaurant.name.trim().isNotEmpty ? restaurant.name : 'Snack Burger',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: palette.onPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'القائمة',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: palette.onPrimary.withValues(alpha: 0.88),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerDestinationTile extends StatelessWidget {
  const _DrawerDestinationTile({
    required this.destination,
    required this.palette,
  });

  final CustomerMenuDrawerDestination destination;
  final TenantPalette palette;

  @override
  Widget build(BuildContext context) {
    final subtitle = destination.subtitle;

    return ListTile(
      enabled: destination.enabled,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: palette.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(destination.icon, color: palette.primary),
      ),
      title: Text(
        destination.title,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: palette.primary,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.primary.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
      onTap: destination.enabled ? destination.onSelected : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
