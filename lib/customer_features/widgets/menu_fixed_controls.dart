import 'package:flutter/material.dart';

import '../../../core/theme/tenant_palette.dart';
import 'menu_category_bar.dart';

/// شريط بحث وتصنيفات ثابت — خارج التمرير لضمان بقائه في أعلى الشاشة.
class MenuFixedControls extends StatelessWidget {
  const MenuFixedControls({
    super.key,
    required this.searchController,
    required this.palette,
    required this.isSearching,
    required this.onQueryChanged,
    required this.onClear,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final TextEditingController searchController;
  final TenantPalette palette;
  final bool isSearching;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surfaceTint,
      elevation: 2,
      shadowColor: palette.primary.withValues(alpha: 0.12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
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
                fillColor: Colors.white,
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, color: palette.primary, size: 22),
                suffixIcon: isSearching
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: palette.primary),
                        tooltip: 'مسح البحث',
                        onPressed: onClear,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: palette.primary.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: palette.primary.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: palette.primary, width: 1.5),
                ),
              ),
            ),
          ),
          if (categories.isNotEmpty)
            MenuCategoryChipsRow(
              categories: categories,
              selectedCategory: selectedCategory,
              onCategorySelected: onCategorySelected,
              palette: palette,
              showBottomBorder: true,
            ),
        ],
      ),
    );
  }
}
