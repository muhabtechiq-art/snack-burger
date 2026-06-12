import 'package:flutter/material.dart';

import '../theme/customer_menu_theme.dart';

enum CustomerBottomNavItem { home, orders, cart }

/// شريط تنقل سفلي ثابت — أحمر مطفي.
class CustomerBottomNav extends StatelessWidget {
  const CustomerBottomNav({
    super.key,
    required this.selected,
    required this.onSelected,
    this.cartItemCount = 0,
  });

  final CustomerBottomNavItem selected;
  final ValueChanged<CustomerBottomNavItem> onSelected;
  final int cartItemCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CustomerMenuTheme.mutedRed,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavTile(
                icon: Icons.home_rounded,
                label: 'الرئيسية',
                selected: selected == CustomerBottomNavItem.home,
                onTap: () => onSelected(CustomerBottomNavItem.home),
              ),
              _NavTile(
                icon: Icons.receipt_long_rounded,
                label: 'طلباتي',
                selected: selected == CustomerBottomNavItem.orders,
                onTap: () => onSelected(CustomerBottomNavItem.orders),
              ),
              _NavTile(
                icon: Icons.shopping_bag_rounded,
                label: 'السلة',
                badge: cartItemCount,
                selected: selected == CustomerBottomNavItem.cart,
                onTap: () => onSelected(CustomerBottomNavItem.cart),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? CustomerMenuTheme.mustard : Colors.white70;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 24),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: CustomerMenuTheme.mustard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: CustomerMenuTheme.ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
