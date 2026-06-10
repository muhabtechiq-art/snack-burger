import 'package:flutter/material.dart';

import '../../../core/theme/tenant_palette.dart';
import '../../../models/promo_banner_model.dart';
import '../../../models/restaurant_model.dart';
import 'menu_banner_carousel.dart';
import 'menu_persistent_headers.dart';

/// بانر علوي — لوجو دائري بارز على خلفية داكنة متناسقة مع الهوية.
class MenuBanner extends StatelessWidget {
  const MenuBanner({
    super.key,
    required this.restaurant,
    required this.palette,
    required this.onBack,
    required this.onOpenMenu,
    this.promoBanners = const [],
  });

  static const double expandedHeight = MenuHeaderMetrics.bannerExpandedHeight;
  static const double toolbarHeight = MenuHeaderMetrics.bannerToolbarHeight;
  static const String menuLogoAssetPath = 'assets/images/menu_logo.png';

  final RestaurantModel restaurant;
  final TenantPalette palette;
  final VoidCallback onBack;
  final VoidCallback onOpenMenu;
  final List<PromoBannerModel> promoBanners;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      floating: false,
      stretch: true,
      toolbarHeight: toolbarHeight,
      backgroundColor: _bannerBackgroundTop(palette),
      foregroundColor: palette.onPrimary,
      leading: IconButton(
        onPressed: onOpenMenu,
        tooltip: 'القائمة',
        icon: const Icon(Icons.menu_rounded),
      ),
      actions: const [],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        title: null,
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: _hasPromoCarousel
            ? SizedBox.expand(
                child: MenuBannerCarousel(
                  banners: promoBanners,
                  height: expandedHeight,
                ),
              )
            : DecoratedBox(
          decoration: BoxDecoration(
            gradient: _bannerBackgroundGradient(palette),
          ),
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Snack Burger',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFFD700),
                                height: 1.1,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 14,
                                  ),
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'سناك بركر',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFFD700),
                                height: 1.2,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.45),
                                    blurRadius: 10,
                                  ),
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            _BannerLogoMark(palette: palette),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static Color _bannerBackgroundTop(TenantPalette palette) {
    return Color.lerp(palette.primary, SnackBurgerBrandColors.ink, 0.72)!;
  }

  bool get _hasPromoCarousel => promoBanners.isNotEmpty;

  static LinearGradient _bannerBackgroundGradient(TenantPalette palette) {
    return LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Color.lerp(palette.primary, Colors.black, 0.58)!,
        Color.lerp(palette.primary, SnackBurgerBrandColors.ink, 0.48)!,
        SnackBurgerBrandColors.ink,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
  }
}

class _BannerLogoMark extends StatelessWidget {
  const _BannerLogoMark({required this.palette});

  /// قطر اللوجو — أكبر قليلاً لتوازن أفضل داخل البانر.
  static const double _logoSize = 152;

  /// مساحة حماية ~3mm (12 logical px) من جميع الجهات.
  static const double _breathingRoom = 12;

  final TenantPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_breathingRoom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.14),
              blurRadius: 16,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Container(
          width: _logoSize,
          height: _logoSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.2,
            ),
            color: SnackBurgerBrandColors.ink,
          ),
          foregroundDecoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.07),
                Colors.transparent,
              ],
              radius: 0.92,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipOval(
            child: Image.asset(
              MenuBanner.menuLogoAssetPath,
              width: _logoSize,
              height: _logoSize,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: palette.primary.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
