import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/tenant_palette.dart';
import '../../core/utils/menu_product_image_url.dart';

/// صورة منتج في المنيو — كاش + decode بحجم محدود.
class MenuProductImage extends StatefulWidget {
  const MenuProductImage({
    super.key,
    required this.imageUrl,
    required this.palette,
    this.cacheWidth = 320,
    this.cacheHeight = 320,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final TenantPalette palette;
  final int cacheWidth;
  final int cacheHeight;
  final BoxFit fit;

  @override
  State<MenuProductImage> createState() => _MenuProductImageState();
}

class _MenuProductImageState extends State<MenuProductImage> {
  bool _useOriginalUrl = false;

  @override
  void didUpdateWidget(covariant MenuProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _useOriginalUrl = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalized = MenuProductImageUrl.normalizeImageUrl(widget.imageUrl);
    if (normalized == null) {
      return _MenuProductImagePlaceholder(palette: widget.palette);
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final memWidth = (widget.cacheWidth * devicePixelRatio).round();
    final memHeight = (widget.cacheHeight * devicePixelRatio).round();

    final resolvedUrl = _useOriginalUrl
        ? normalized
        : MenuProductImageUrl.thumbnail(
            normalized,
            width: widget.cacheWidth,
            height: widget.cacheHeight,
          ) ??
            normalized;

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: memWidth,
      memCacheHeight: memHeight,
      filterQuality: FilterQuality.medium,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => _MenuProductImagePlaceholder(
        palette: widget.palette,
        showLoading: true,
      ),
      errorWidget: (context, url, error) {
        if (!_useOriginalUrl && resolvedUrl != normalized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _useOriginalUrl = true);
          });
          return _MenuProductImagePlaceholder(
            palette: widget.palette,
            showLoading: true,
          );
        }
        return _MenuProductImagePlaceholder(palette: widget.palette);
      },
    );
  }
}

class _MenuProductImagePlaceholder extends StatelessWidget {
  const _MenuProductImagePlaceholder({
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
