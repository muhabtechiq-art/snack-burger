import 'package:flutter/material.dart';

import '../../../core/theme/tenant_palette.dart';
import 'menu_category_bar.dart';

/// ثوابت ارتفاع رؤوس المنيو المثبتة.
abstract final class MenuHeaderMetrics {
  static const double bannerExpandedHeight = 296;
  static const double bannerToolbarHeight = 48;
  static const double searchHeight = 72;
  static const double categoriesHeight = 64;

  static double collapseProgress(double scrollOffset) {
    const collapseDistance = bannerExpandedHeight - bannerToolbarHeight;
    if (collapseDistance <= 0) return 1;
    return (scrollOffset / collapseDistance).clamp(0.0, 1.0);
  }

  static double searchExtent(double progress) => searchHeight;

  static double categoriesExtent(double progress) => categoriesHeight;
}

/// رأس مثبت يجمع البحث + شريط التصنيفات مباشرة أسفل البانر.
class MenuStickyControlsHeader extends StatelessWidget {
  const MenuStickyControlsHeader({
    super.key,
    required this.searchController,
    required this.isSearching,
    required this.onQueryChanged,
    required this.onClear,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.palette,
  });

  final TextEditingController searchController;
  final bool isSearching;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final TenantPalette palette;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: categories.isNotEmpty,
      delegate: _MenuStickyControlsHeaderDelegate(
        searchController: searchController,
        isSearching: isSearching,
        onQueryChanged: onQueryChanged,
        onClear: onClear,
        categories: categories,
        selectedCategory: selectedCategory,
        onCategorySelected: onCategorySelected,
        palette: palette,
      ),
    );
  }
}

class _MenuStickyControlsHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MenuStickyControlsHeaderDelegate({
    required this.searchController,
    required this.isSearching,
    required this.onQueryChanged,
    required this.onClear,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.palette,
  });

  final TextEditingController searchController;
  final bool isSearching;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final TenantPalette palette;

  @override
  double get minExtent =>
      categories.isEmpty
          ? 0
          : MenuHeaderMetrics.searchHeight + MenuHeaderMetrics.categoriesHeight;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final pinned = overlapsContent;
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: maxExtent,
      child: Material(
        color: pinned ? const Color(0xFFFAFAFA) : Colors.white,
        elevation: pinned ? 2 : 0,
        shadowColor: palette.primary.withValues(alpha: 0.1),
        child: Column(
          children: [
            SizedBox(
              height: MenuHeaderMetrics.searchHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: TextField(
                  controller: searchController,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  textInputAction: TextInputAction.search,
                  onChanged: onQueryChanged,
                  decoration: InputDecoration(
                    hintText: 'ابحث في القائمة...',
                    hintTextDirection: TextDirection.rtl,
                    filled: true,
                    fillColor: palette.surfaceTint,
                    isDense: true,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: palette.primary,
                      size: 22,
                    ),
                    suffixIcon: isSearching
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: palette.primary,
                            ),
                            tooltip: 'مسح البحث',
                            onPressed: onClear,
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: palette.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: palette.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: palette.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            MenuCategoryChipsRow(
              categories: categories,
              selectedCategory: selectedCategory,
              onCategorySelected: onCategorySelected,
              palette: palette,
              height: MenuHeaderMetrics.categoriesHeight,
              backgroundColor: Colors.transparent,
              showBottomBorder: true,
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MenuStickyControlsHeaderDelegate oldDelegate) {
    return oldDelegate.categories != categories ||
        oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.isSearching != isSearching ||
        oldDelegate.palette.primary != palette.primary;
  }
}
