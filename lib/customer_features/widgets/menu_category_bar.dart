import 'package:flutter/material.dart';

import '../../../core/theme/tenant_palette.dart';

/// شريط الأقسام العلوي المثبت (Chips).
class MenuCategoryBar extends StatelessWidget {
  static const double height = 64;

  const MenuCategoryBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.palette,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final TenantPalette palette;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _MenuCategoryBarDelegate(
        categories: categories,
        selectedCategory: selectedCategory,
        onCategorySelected: onCategorySelected,
        palette: palette,
      ),
    );
  }
}

class _MenuCategoryBarDelegate extends SliverPersistentHeaderDelegate {
  _MenuCategoryBarDelegate({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.palette,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final TenantPalette palette;

  @override
  double get minExtent => MenuCategoryBar.height;

  @override
  double get maxExtent => MenuCategoryBar.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: palette.surfaceTint,
      elevation: overlapsContent ? 4 : 0,
      shadowColor: palette.primary.withValues(alpha: 0.15),
      child: MenuCategoryChipsRow(
        categories: categories,
        selectedCategory: selectedCategory,
        onCategorySelected: onCategorySelected,
        palette: palette,
        showBottomBorder: true,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MenuCategoryBarDelegate oldDelegate) {
    return oldDelegate.categories != categories ||
        oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.palette.primary != palette.primary;
  }
}

/// صف أفقي لشرائح الأصناف — يُستخدم في الرأس المثبت وشريط الأقسام المنفصل.
class MenuCategoryChipsRow extends StatelessWidget {
  const MenuCategoryChipsRow({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.palette,
    this.height = MenuCategoryBar.height,
    this.backgroundColor,
    this.showBottomBorder = false,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final TenantPalette palette;
  final double height;
  final Color? backgroundColor;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? palette.surfaceTint,
        border: showBottomBorder
            ? Border(
                bottom: BorderSide(color: palette.primary.withValues(alpha: 0.08)),
              )
            : null,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;
          return FilterChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) => onCategorySelected(category),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? palette.onPrimary : palette.primary,
            ),
            backgroundColor: Colors.white,
            selectedColor: palette.primary,
            side: BorderSide(
              color: selected
                  ? palette.primary
                  : palette.primary.withValues(alpha: 0.25),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}
