import 'package:flutter/material.dart';

import '../theme/customer_menu_theme.dart';

/// هيدر المنيو — قائمة يسار، اسم المطعم بالوسط، سلة يمين.
class CustomerMenuHeader extends StatelessWidget implements PreferredSizeWidget {
  const CustomerMenuHeader({
    super.key,
    required this.title,
    required this.onOpenMenu,
    required this.onOpenCart,
    this.cartItemCount = 0,
    this.leading,
  });

  final String title;
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenCart;
  final int cartItemCount;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: CustomerMenuTheme.surfaceWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leadingWidth: 52,
      leading: leading ??
          IconButton(
            onPressed: onOpenMenu,
            tooltip: 'القائمة',
            icon: const Icon(Icons.menu_rounded, color: CustomerMenuTheme.ink),
          ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: CustomerMenuTheme.ink,
        ),
      ),
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onOpenCart,
              tooltip: 'السلة',
              icon: const Icon(
                Icons.shopping_bag_outlined,
                color: CustomerMenuTheme.mutedRed,
              ),
            ),
            if (cartItemCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: CustomerMenuTheme.mustard,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    cartItemCount > 99 ? '99+' : '$cartItemCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: CustomerMenuTheme.ink,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
