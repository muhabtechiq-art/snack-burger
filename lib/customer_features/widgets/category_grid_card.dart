import 'package:flutter/material.dart';

import '../../../core/theme/tenant_palette.dart';
import '../../models/product_model.dart';
import '../theme/customer_menu_theme.dart';
import 'category_english_label.dart';
import 'menu_product_image.dart';

/// بطاقة قسم — صورة كبيرة، اسم عربي + إنجليزي، زر سهم دائري.
class CategoryGridCard extends StatelessWidget {
  const CategoryGridCard({
    super.key,
    required this.categoryName,
    required this.products,
    required this.palette,
    required this.onTap,
  });

  final String categoryName;
  final List<ProductModel> products;
  final TenantPalette palette;
  final VoidCallback onTap;

  String? get _coverImageUrl {
    for (final product in products) {
      final url = product.imageUrl?.trim();
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final english = englishCategoryLabel(categoryName);
    final imageUrl = _coverImageUrl;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(CustomerMenuTheme.radiusMd),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CustomerMenuTheme.radiusMd),
            border: Border.all(
              color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1.15,
                child: imageUrl == null
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              CustomerMenuTheme.mustardSoft,
                              CustomerMenuTheme.mustardDeep
                                  .withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.restaurant_menu_rounded,
                          size: 48,
                          color: CustomerMenuTheme.mutedRed
                              .withValues(alpha: 0.45),
                        ),
                      )
                    : MenuProductImage(
                        imageUrl: imageUrl,
                        palette: palette,
                        fit: BoxFit.cover,
                        cacheWidth: 480,
                        cacheHeight: 420,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: CustomerMenuTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            english,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CustomerMenuTheme.inkMuted
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: CustomerMenuTheme.mutedRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
