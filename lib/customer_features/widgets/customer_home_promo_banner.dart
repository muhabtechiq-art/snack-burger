import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/promo_banner_model.dart';
import '../menu/customer_menu_banners_controller.dart';
import 'menu_banner_carousel.dart';

/// بانر ترويجي مدمج — الصفحة الرئيسية فقط، بدون مساحة فارغة.
class CustomerHomePromoBanner extends StatelessWidget {
  const CustomerHomePromoBanner({super.key});

  static const double horizontalMargin = 16;
  static const double borderRadius = 18;
  static const double widthBreakpoint = 600;

  static double heightFor(double viewportWidth) {
    if (viewportWidth < widthBreakpoint) return 155;
    return 170;
  }

  @override
  Widget build(BuildContext context) {
    final banners = context.select<CustomerMenuBannersController,
        List<PromoBannerModel>>(
      (controller) => controller.activeBanners,
    );

    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    final height = heightFor(MediaQuery.sizeOf(context).width);

    return Padding(
      padding: const EdgeInsets.fromLTRB(horizontalMargin, 4, horizontalMargin, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: MenuBannerCarousel(
          banners: banners,
          height: height,
        ),
      ),
    );
  }
}
