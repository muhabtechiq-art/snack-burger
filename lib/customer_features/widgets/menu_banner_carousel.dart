import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../../models/promo_banner_model.dart';

/// شريط بانر دوّار — يعرض الصور النشطة فقط.
class MenuBannerCarousel extends StatelessWidget {
  const MenuBannerCarousel({
    super.key,
    required this.banners,
    required this.height,
  });

  final List<PromoBannerModel> banners;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    final canAutoPlay = banners.length > 1;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CarouselSlider.builder(
        itemCount: banners.length,
        options: CarouselOptions(
          height: height,
          viewportFraction: 1,
          autoPlay: canAutoPlay,
          autoPlayInterval: const Duration(seconds: 5),
          autoPlayAnimationDuration: const Duration(milliseconds: 900),
          autoPlayCurve: Curves.easeInOutCubic,
          enlargeCenterPage: false,
          enableInfiniteScroll: canAutoPlay,
          scrollPhysics: canAutoPlay
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
        ),
        itemBuilder: (context, index, _) {
          final banner = banners[index];
          return _BannerSlide(banner: banner);
        },
      ),
    );
  }
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({required this.banner});

  final PromoBannerModel banner;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: banner.imageUrl,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          placeholder: (_, _) => ColoredBox(
            color: Colors.black.withValues(alpha: 0.18),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (_, _, _) => ColoredBox(
            color: Colors.black.withValues(alpha: 0.35),
            child: const Icon(Icons.broken_image_outlined, color: Colors.white54),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.08),
                Colors.black.withValues(alpha: 0.42),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        if (banner.title.trim().isNotEmpty)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Text(
                banner.title,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
