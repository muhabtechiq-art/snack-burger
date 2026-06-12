import 'package:flutter/material.dart';

import '../../../core/theme/tenant_palette.dart';
import '../../../models/promo_banner_model.dart';
import '../../../models/restaurant_model.dart';
import 'menu_banner_carousel.dart';
import 'menu_persistent_headers.dart';

/// بانر علوي مدمج — كاروسيل/خلفية + شريط اسم المطعم أسفله.
class MenuBanner extends StatelessWidget {
  const MenuBanner({
    super.key,
    required this.restaurant,
    required this.palette,
    required this.onBack,
    required this.onOpenMenu,
    this.promoBanners = const [],
  });

  static const double toolbarHeight = MenuHeaderMetrics.bannerToolbarHeight;
  static const String menuLogoAssetPath = 'assets/images/menu_logo.png';
  static const double _bannerHorizontalInset = 12;
  static const double _bannerBottomInset = 6;
  static const double _bannerCornerRadius = 12;

  final RestaurantModel restaurant;
  final TenantPalette palette;
  final VoidCallback onBack;
  final VoidCallback onOpenMenu;
  final List<PromoBannerModel> promoBanners;

  bool get _hasPromoCarousel => promoBanners.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final expandedHeight = MenuHeaderMetrics.bannerExpandedHeightFor(
      MediaQuery.sizeOf(context).width,
    );
    final carouselHeight = expandedHeight - _bannerBottomInset;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      floating: false,
      stretch: false,
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
        stretchModes: const [],
        background: _hasPromoCarousel
            ? _PromoBannerBackground(
                promoBanners: promoBanners,
                carouselHeight: carouselHeight,
                restaurantName: restaurant.name,
                palette: palette,
              )
            : _FallbackBannerBackground(
                restaurantName: restaurant.name,
                palette: palette,
                carouselHeight: carouselHeight,
              ),
      ),
    );
  }

  static Color _bannerBackgroundTop(TenantPalette palette) {
    return Color.lerp(palette.primary, SnackBurgerBrandColors.ink, 0.72)!;
  }

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

class _PromoBannerBackground extends StatelessWidget {
  const _PromoBannerBackground({
    required this.promoBanners,
    required this.carouselHeight,
    required this.restaurantName,
    required this.palette,
  });

  final List<PromoBannerModel> promoBanners;
  final double carouselHeight;
  final String restaurantName;
  final TenantPalette palette;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MenuBanner._bannerBackgroundTop(palette),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: MenuBanner._bannerHorizontalInset,
            right: MenuBanner._bannerHorizontalInset,
            bottom: MenuBanner._bannerBottomInset,
            height: carouselHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MenuBanner._bannerCornerRadius),
              child: MenuBannerCarousel(
                banners: promoBanners,
                height: carouselHeight,
              ),
            ),
          ),
          if (restaurantName.trim().isNotEmpty)
            Positioned(
              left: MenuBanner._bannerHorizontalInset,
              right: MenuBanner._bannerHorizontalInset,
              bottom: MenuBanner._bannerBottomInset,
              child: _RestaurantNameBar(name: restaurantName),
            ),
        ],
      ),
    );
  }
}

class _FallbackBannerBackground extends StatelessWidget {
  const _FallbackBannerBackground({
    required this.restaurantName,
    required this.palette,
    required this.carouselHeight,
  });

  final String restaurantName;
  final TenantPalette palette;
  final double carouselHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: MenuBanner._bannerHorizontalInset,
          right: MenuBanner._bannerHorizontalInset,
          bottom: MenuBanner._bannerBottomInset,
          height: carouselHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MenuBanner._bannerCornerRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: MenuBanner._bannerBackgroundGradient(palette),
              ),
              child: Center(
                child: _CompactBannerLogo(palette: palette),
              ),
            ),
          ),
        ),
        if (restaurantName.trim().isNotEmpty)
          Positioned(
            left: MenuBanner._bannerHorizontalInset,
            right: MenuBanner._bannerHorizontalInset,
            bottom: MenuBanner._bannerBottomInset,
            child: _RestaurantNameBar(name: restaurantName),
          ),
      ],
    );
  }
}

class _RestaurantNameBar extends StatelessWidget {
  const _RestaurantNameBar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(MenuBanner._bannerCornerRadius),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _CompactBannerLogo extends StatelessWidget {
  const _CompactBannerLogo({required this.palette});

  static const double _logoSize = 56;

  final TenantPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
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
        clipBehavior: Clip.antiAlias,
        child: ClipOval(
          child: Image.asset(
            MenuBanner.menuLogoAssetPath,
            width: _logoSize,
            height: _logoSize,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: palette.primary.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
