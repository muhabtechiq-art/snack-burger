import 'package:flutter/material.dart';

import '../../../core/theme/tenant_palette.dart';
import '../../../models/product_model.dart';

enum MenuProductCardLayout { grid, list }

/// بطاقة منتج — شبكة (عمودين) أو قائمة أفقية.
class MenuProductCard extends StatelessWidget {
  const MenuProductCard({
    super.key,
    required this.product,
    required this.palette,
    required this.onQuickAdd,
    required this.onOpenDetails,
    this.layout = MenuProductCardLayout.grid,
  });

  final ProductModel product;
  final TenantPalette palette;
  final VoidCallback onQuickAdd;
  final VoidCallback onOpenDetails;
  final MenuProductCardLayout layout;

  @override
  Widget build(BuildContext context) {
    return layout == MenuProductCardLayout.grid
        ? _GridProductCard(
            product: product,
            palette: palette,
            onQuickAdd: onQuickAdd,
            onOpenDetails: onOpenDetails,
          )
        : _ListProductCard(
            product: product,
            palette: palette,
            onQuickAdd: onQuickAdd,
            onOpenDetails: onOpenDetails,
          );
  }
}

class _GridProductCard extends StatelessWidget {
  const _GridProductCard({
    required this.product,
    required this.palette,
    required this.onQuickAdd,
    required this.onOpenDetails,
  });

  final ProductModel product;
  final TenantPalette palette;
  final VoidCallback onQuickAdd;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasDescription =
        product.description != null && product.description!.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.primary.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 11,
                child: _ProductImageSlot(
                  imageUrl: product.imageUrl,
                  palette: palette,
                  onTap: onOpenDetails,
                ),
              ),
              Expanded(
                flex: 9,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          product.name,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: palette.primary,
                                height: 1.15,
                                fontSize: 12,
                              ),
                        ),
                      ),
                      if (hasDescription)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              product.description!,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                height: 1.2,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        textDirection: TextDirection.rtl,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _PriceBadge(
                              product: product,
                              palette: palette,
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _AddIconButton(
                            palette: palette,
                            onAddToCart: onQuickAdd,
                            size: 28,
                            iconSize: 17,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _ListProductCard extends StatelessWidget {
  const _ListProductCard({
    required this.product,
    required this.palette,
    required this.onQuickAdd,
    required this.onOpenDetails,
  });

  final ProductModel product;
  final TenantPalette palette;
  final VoidCallback onQuickAdd;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasDescription =
        product.description != null && product.description!.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.primary.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              textDirection: TextDirection.rtl,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: _ProductImageSlot(
                      imageUrl: product.imageUrl,
                      palette: palette,
                      onTap: onOpenDetails,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: palette.primary,
                              height: 1.2,
                            ),
                      ),
                      if (hasDescription) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description!,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            height: 1.3,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        textDirection: TextDirection.rtl,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: _PriceBadge(product: product, palette: palette),
                          ),
                          const SizedBox(width: 8),
                          _AddIconButton(
                            palette: palette,
                            onAddToCart: onQuickAdd,
                          ),
                        ],
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

class _ProductImageSlot extends StatelessWidget {
  const _ProductImageSlot({
    required this.imageUrl,
    required this.palette,
    required this.onTap,
  });

  final String? imageUrl;
  final TenantPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    if (hasImage) {
      return InkWell(
        onTap: onTap,
        child: Image.network(
          imageUrl!,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _Placeholder(
              palette: palette,
              showLoading: true,
            );
          },
          errorBuilder: (_, _, _) => _Placeholder(palette: palette),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: _Placeholder(palette: palette),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.palette,
    this.showLoading = false,
  });

  final TenantPalette palette;
  final bool showLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            palette.primary.withValues(alpha: 0.05),
            palette.accent.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: showLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.primary.withValues(alpha: 0.4),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    size: 22,
                    color: palette.primary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'صورة',
                    style: TextStyle(
                      color: palette.primary.withValues(alpha: 0.3),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({
    required this.product,
    required this.palette,
    this.compact = false,
  });

  final ProductModel product;
  final TenantPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        product.hasVariants
            ? 'من ${product.displayPrice.toStringAsFixed(0)} د.ع'
            : '${product.displayPrice.toStringAsFixed(0)} د.ع',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: palette.primary,
          fontWeight: FontWeight.w900,
          fontSize: compact ? 10 : 13,
        ),
      ),
    );
  }
}

class _AddIconButton extends StatelessWidget {
  const _AddIconButton({
    required this.palette,
    required this.onAddToCart,
    this.size = 32,
    this.iconSize = 19,
  });

  final TenantPalette palette;
  final VoidCallback onAddToCart;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.primary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAddToCart,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.add_rounded, color: palette.onPrimary, size: iconSize),
        ),
      ),
    );
  }
}
