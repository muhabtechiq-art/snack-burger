import 'package:flutter/material.dart';

import '../theme/customer_menu_theme.dart';

/// هيدر المنيو — قائمة يسار، اسم المطعم بالوسط.
class CustomerMenuHeader extends StatelessWidget implements PreferredSizeWidget {
  const CustomerMenuHeader({
    super.key,
    required this.title,
    required this.onOpenMenu,
    this.leading,
  });

  final String title;
  final VoidCallback onOpenMenu;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: CustomerMenuTheme.surfaceWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 52,
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
    );
  }
}
