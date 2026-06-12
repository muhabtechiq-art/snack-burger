import 'package:flutter/foundation.dart';

import '../models/restaurant_model.dart';
import '../services/supabase_restaurant_service.dart';

/// سياق المطعم النشط من الـ slug في الرابط — يُحمَّل من Supabase مع fallback محلي.
class ActiveRestaurantNotifier extends ChangeNotifier {
  ActiveRestaurantNotifier();

  RestaurantModel? _restaurant;
  String? _resolvedSlug;
  bool _loading = false;

  RestaurantModel? get restaurant => _restaurant;
  String? get resolvedSlug => _resolvedSlug;
  bool get isLoading => _loading;

  static const Duration _foregroundRefreshDebounce = Duration(seconds: 2);

  DateTime? _lastForegroundRefreshAt;

  /// يعيد جلب بيانات المطعم الحالي من Supabase — يتجاوز cache الجلسة.
  Future<void> refreshRestaurant() async {
    final slug = _resolvedSlug;
    if (slug == null || slug.isEmpty) return;

    final now = DateTime.now();
    final last = _lastForegroundRefreshAt;
    if (last != null && now.difference(last) < _foregroundRefreshDebounce) {
      return;
    }
    _lastForegroundRefreshAt = now;

    await resolveSlug(slug, force: true);
  }

  Future<void> resolveSlug(String slug, {bool force = false}) async {
    final normalized = slug.trim().toLowerCase();
    if (normalized.isEmpty) {
      _restaurant = null;
      _resolvedSlug = null;
      notifyListeners();
      return;
    }
    if (!force && _resolvedSlug == normalized && _restaurant != null) {
      return;
    }

    final showLoading = _restaurant == null || _resolvedSlug != normalized;
    if (showLoading) {
      _loading = true;
      notifyListeners();
    }

    _resolvedSlug = normalized;

    _restaurant = await _loadRestaurant(normalized);

    if (showLoading) {
      _loading = false;
    }
    notifyListeners();
  }

  void clearTenant() {
    _restaurant = null;
    _resolvedSlug = null;
    notifyListeners();
  }

  Future<RestaurantModel> _loadRestaurant(String slug) async {
    try {
      final fromDb = await SupabaseRestaurantService.fetchBySlug(slug);
      if (fromDb != null) {
        debugPrint('[ActiveRestaurantNotifier] loaded slug=$slug from Supabase');
        return fromDb;
      }
    } catch (e, stack) {
      debugPrint(
        '[ActiveRestaurantNotifier] Supabase fetch failed for slug=$slug — '
        'using local fallback: $e\n$stack',
      );
    }

    debugPrint('[ActiveRestaurantNotifier] local fallback for slug=$slug');
    return _restaurantFromSlug(slug);
  }

  /// Fallback محلي حتى يُنشأ جدول `restaurants` أو يُضاف slug جديد.
  RestaurantModel _restaurantFromSlug(String slug) {
    if (slug == 'snack_burger') {
      return const RestaurantModel(
        id: 'snack_burger',
        slug: 'snack_burger',
        name: 'Snack Burger',
        logoUrl: null,
        primaryColorHex: '#8B0000',
        accentColorHex: '#E1AD01',
        whatsappNumber: '9647XXXXXXXXX',
        orderRoutingMode: 'whatsapp',
        isActive: true,
      );
    }

    final title = slug.replaceAll('_', ' ');
    final displayName = title.isEmpty
        ? 'Restaurant'
        : '${title[0].toUpperCase()}${title.length > 1 ? title.substring(1) : ''}';
    return RestaurantModel(
      id: slug,
      slug: slug,
      name: displayName,
      logoUrl: null,
      primaryColorHex: '#1565C0',
      accentColorHex: '#FF9800',
      whatsappNumber: null,
      orderRoutingMode: 'whatsapp',
      isActive: true,
    );
  }
}
