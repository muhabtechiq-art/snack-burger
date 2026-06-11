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

  Future<void> resolveSlug(String slug) async {
    final normalized = slug.trim().toLowerCase();
    if (normalized.isEmpty) {
      _restaurant = null;
      _resolvedSlug = null;
      notifyListeners();
      return;
    }
    if (_resolvedSlug == normalized && _restaurant != null) {
      return;
    }

    _loading = true;
    _resolvedSlug = normalized;
    notifyListeners();

    _restaurant = await _loadRestaurant(normalized);
    _loading = false;
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
