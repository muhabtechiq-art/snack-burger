import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../../core/utils/menu_product_image_url.dart';
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
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _BannerSlide(banner: banner),
          );
        },
      ),
    );
  }
}

class _BannerSlide extends StatefulWidget {
  const _BannerSlide({required this.banner});

  final PromoBannerModel banner;

  @override
  State<_BannerSlide> createState() => _BannerSlideState();
}

class _BannerSlideState extends State<_BannerSlide> {
  static const int _decodeWidth = 640;
  static const int _decodeHeight = 240;

  bool _useOriginalUrl = false;

  @override
  void didUpdateWidget(covariant _BannerSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banner.imageUrl != widget.banner.imageUrl) {
      _useOriginalUrl = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalized =
        MenuProductImageUrl.normalizeImageUrl(widget.banner.imageUrl);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final memWidth = (_decodeWidth * devicePixelRatio).round();
    final memHeight = (_decodeHeight * devicePixelRatio).round();

    final resolvedUrl = normalized == null
        ? null
        : _useOriginalUrl
            ? normalized
            : MenuProductImageUrl.bannerThumbnail(normalized) ?? normalized;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (resolvedUrl == null)
          ColoredBox(color: Colors.black.withValues(alpha: 0.35))
        else
          CachedNetworkImage(
            imageUrl: resolvedUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            memCacheWidth: memWidth,
            memCacheHeight: memHeight,
            filterQuality: FilterQuality.medium,
            fadeInDuration: const Duration(milliseconds: 180),
            placeholder: (_, _) => ColoredBox(
              color: Colors.black.withValues(alpha: 0.18),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) {
              if (!_useOriginalUrl && resolvedUrl != normalized) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _useOriginalUrl = true);
                });
                return ColoredBox(
                  color: Colors.black.withValues(alpha: 0.18),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                ),
              );
            },
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.5),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        if (widget.banner.title.trim().isNotEmpty)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              child: Text(
                widget.banner.title,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 15,
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
