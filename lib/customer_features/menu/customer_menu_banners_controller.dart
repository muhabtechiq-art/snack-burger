import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/cache/menu_catalog_cache.dart';
import '../../models/promo_banner_model.dart';
import '../../services/banner_repository.dart';

/// جلب بانرات المنيو — مستقل عن [CustomerMenuController].
class CustomerMenuBannersController extends ChangeNotifier {
  CustomerMenuBannersController({
    required this.slug,
    BannerRepository? bannerRepository,
  }) : _bannerRepository = bannerRepository ?? BannerRepository();

  final BannerRepository _bannerRepository;
  String slug;

  StreamSubscription<List<PromoBannerModel>>? _subscription;
  int _bindGeneration = 0;

  List<PromoBannerModel> _activeBanners = const [];
  bool _loading = true;
  bool _disposed = false;

  List<PromoBannerModel> get activeBanners =>
      List<PromoBannerModel>.unmodifiable(_activeBanners);

  bool get loading => _loading;

  bool get hasActiveBanners => _activeBanners.isNotEmpty;

  void bindToRestaurant({
    required String restaurantId,
    required String slug,
  }) {
    this.slug = slug;
    unawaited(_reload(restaurantId: restaurantId, slug: slug));
  }

  Future<void> retryLoad({
    required String restaurantId,
    required String slug,
  }) {
    return _reload(restaurantId: restaurantId, slug: slug);
  }

  Future<void> _reload({
    required String restaurantId,
    required String slug,
  }) async {
    final generation = ++_bindGeneration;

    await _subscription?.cancel();
    _subscription = null;

    final cached = await MenuCatalogCache.loadBanners(slug);
    if (_disposed || generation != _bindGeneration) return;

    if (cached != null && cached.isNotEmpty) {
      _activeBanners = List<PromoBannerModel>.unmodifiable(cached);
      _loading = false;
      notifyListeners();
    } else {
      _loading = true;
      notifyListeners();
    }

    try {
      final items = await _bannerRepository.fetchActiveBanners(
        restaurantId: restaurantId,
        slug: slug,
      );
      if (_disposed || generation != _bindGeneration) return;
      _activeBanners = List<PromoBannerModel>.unmodifiable(items);
      unawaited(MenuCatalogCache.saveBanners(slug, items));
      debugPrint(
        '[CustomerMenuBannersController] جُلب ${items.length} بانر نشط',
      );
    } catch (error, stack) {
      debugPrint('CustomerMenuBannersController fetch: $error\n$stack');
      if (_disposed || generation != _bindGeneration) return;
      if (!hasActiveBanners) {
        _activeBanners = const [];
      }
    }

    if (_disposed || generation != _bindGeneration) return;
    _loading = false;
    notifyListeners();

    if (_disposed || generation != _bindGeneration) return;

    _subscription = _bannerRepository
        .watchActiveBanners(restaurantId: restaurantId, slug: slug)
        .listen(
      (banners) {
        if (_disposed || generation != _bindGeneration) return;
        _activeBanners = List<PromoBannerModel>.unmodifiable(banners);
        unawaited(MenuCatalogCache.saveBanners(slug, banners));
        _loading = false;
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('CustomerMenuBannersController stream: $error\n$stack');
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _bindGeneration++;
    _subscription?.cancel();
    super.dispose();
  }
}
