import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/product_model.dart';
import '../../services/product_repository.dart';
import 'menu_mock_products.dart';
import 'utils/product_grouping.dart';

/// منطق عرض المنيو للزبون — جلب المنتجات، الأقسام، والبحث.
class CustomerMenuController extends ChangeNotifier {
  static const String allCategoryLabel = 'الكل';

  /// تبويب يُخفى من شريط الأقسام — المنتجات تبقى ظاهرة تحت «الكل».
  static const String _hiddenMenuCategoryLabel = 'قائمة عامة';

  /// عدد المنتجات المعروضة في كل دفعة (تحميل تدريجي).
  static const int productsPageSize = 20;

  CustomerMenuController({
    required this.slug,
    ProductRepository? productRepository,
    this.useMockProducts = kUseMockMenuProducts,
    List<ProductModel>? mockProducts,
  })  : _productRepository = productRepository ?? ProductRepository(),
        _mockProducts = mockProducts ?? mockMenuProducts {
    if (useMockProducts) {
      _applyProducts(_mockProducts);
      _productsLoading = false;
      _initialLoadComplete = true;
    }
  }

  final ProductRepository _productRepository;
  String slug;
  final bool useMockProducts;
  final List<ProductModel> _mockProducts;

  StreamSubscription<List<ProductModel>>? _productsSubscription;
  int _bindGeneration = 0;

  String? _restaurantId;

  List<ProductModel> _products = const [];
  Object? _streamError;
  bool _productsLoading = true;
  bool _initialLoadComplete = false;
  String _searchQuery = '';
  String? _selectedCategory;
  List<String> _categoryTitles = const [];
  bool _disposed = false;

  List<ProductModel>? _cachedFilteredProducts;
  String _cachedSearchQuery = '';
  String? _cachedSelectedCategory;
  List<MapEntry<String, List<ProductModel>>>? _cachedCategorySections;
  int _visibleProductLimit = productsPageSize;

  String? get restaurantId => _restaurantId;

  List<ProductModel> get products =>
      List<ProductModel>.unmodifiable(_products);

  String get searchQuery => _searchQuery;

  bool get isSearching => _searchQuery.trim().isNotEmpty;

  bool get productsLoading => _productsLoading;

  Object? get streamError => _streamError;

  bool get hasProductsError => _streamError != null;

  /// يُعرض فقط بعد انتهاء المحاولة الأولى وفشلها مع عدم وجود منتجات.
  bool get showProductsError =>
      hasProductsError &&
      _initialLoadComplete &&
      !productsLoading &&
      !hasProducts;

  String? get productsErrorMessage => !showProductsError
      ? null
      : _mapProductsError(_streamError!);

  bool get hasProducts => _products.isNotEmpty;

  bool get isEmpty => filteredProducts.isEmpty;

  List<String> get categories => List<String>.unmodifiable(<String>[
        allCategoryLabel,
        ..._categoryTitles.where(
          (title) => title != _hiddenMenuCategoryLabel,
        ),
      ]);

  String? get selectedCategory => _selectedCategory;

  List<ProductModel> get filteredProducts {
    if (_cachedFilteredProducts != null &&
        _cachedSearchQuery == _searchQuery &&
        _cachedSelectedCategory == _selectedCategory) {
      return _cachedFilteredProducts!;
    }

    final query = _searchQuery.trim().toLowerCase();
    final bySearch = query.isEmpty
        ? products
        : products
            .where(
              (product) =>
                  product.name.toLowerCase().contains(query) ||
                  (product.description ?? '').toLowerCase().contains(query) ||
                  product.category.toLowerCase().contains(query),
            )
            .toList(growable: false);

    final category = _selectedCategory;
    final result = category == null || category == allCategoryLabel
        ? bySearch
        : bySearch
            .where((product) => product.category.trim() == category)
            .toList(growable: false);

    _cachedFilteredProducts = result;
    _cachedSearchQuery = _searchQuery;
    _cachedSelectedCategory = _selectedCategory;
    _cachedCategorySections = null;
    return result;
  }

  List<MapEntry<String, List<ProductModel>>> get categorySections {
    if (_cachedCategorySections != null) {
      return _cachedCategorySections!;
    }
    final sections = orderedCategoryEntries(filteredProducts);
    _cachedCategorySections = sections;
    return sections;
  }

  /// أقسام مع تحميل تدريجي — أول [visibleProductLimit] منتجاً فقط.
  List<MapEntry<String, List<ProductModel>>> get visibleCategorySections {
    final all = categorySections;
    var remaining = _visibleProductLimit;
    if (remaining <= 0 || all.isEmpty) return const [];

    final visible = <MapEntry<String, List<ProductModel>>>[];
    for (final section in all) {
      if (remaining <= 0) break;
      final take = section.value.length.clamp(0, remaining);
      if (take <= 0) continue;
      visible.add(MapEntry(section.key, section.value.sublist(0, take)));
      remaining -= take;
    }
    return visible;
  }

  int get visibleProductLimit => _visibleProductLimit;

  bool get canLoadMoreProducts =>
      filteredProducts.length > _visibleProductLimit;

  void loadMoreProducts() {
    if (!canLoadMoreProducts) return;
    _visibleProductLimit += productsPageSize;
    if (!_disposed) notifyListeners();
  }

  int productCountForCategory(String category) {
    for (final section in categorySections) {
      if (section.key == category) {
        return section.value.length;
      }
    }
    return 0;
  }

  void bindToRestaurant({
    required String restaurantId,
    required String slug,
  }) {
    this.slug = slug;
    _restaurantId = restaurantId;

    if (useMockProducts) {
      _applyProducts(_mockProducts);
      _productsLoading = false;
      _streamError = null;
      _initialLoadComplete = true;
      if (!_disposed) notifyListeners();
      return;
    }

    unawaited(_reloadProducts(restaurantId: restaurantId, slug: slug));
  }

  Future<void> retryProductsLoad() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) return;
    await _reloadProducts(restaurantId: restaurantId, slug: slug);
  }

  Future<void> _reloadProducts({
    required String restaurantId,
    required String slug,
  }) async {
    final generation = ++_bindGeneration;

    await _productsSubscription?.cancel();
    _productsSubscription = null;
    _productsLoading = true;
    _streamError = null;
    _initialLoadComplete = false;
    if (!_disposed) notifyListeners();

    try {
      final items = await _productRepository.fetchProductsForRestaurant(
        restaurantId: restaurantId,
        slug: slug,
      );
      if (_disposed || generation != _bindGeneration) return;
      _applyProducts(items);
      _streamError = null;
    } catch (error, stack) {
      debugPrint('CustomerMenuController fetch: $error\n$stack');
      if (_disposed || generation != _bindGeneration) return;
      if (!hasProducts) {
        _streamError = error;
      }
    }

    if (_disposed || generation != _bindGeneration) return;
    _initialLoadComplete = true;
    _productsLoading = false;
    notifyListeners();

    if (_disposed || generation != _bindGeneration) return;

    _productsSubscription = _productRepository
        .watchProductsForRestaurant(
          restaurantId: restaurantId,
          slug: slug,
        )
        .listen(
      (List<ProductModel> items) {
        if (_disposed || generation != _bindGeneration) return;
        _applyProducts(items);
        _productsLoading = false;
        _streamError = null;
        _initialLoadComplete = true;
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('CustomerMenuController stream: $error\n$stack');
        if (_disposed || generation != _bindGeneration) return;
        if (!hasProducts) {
          _streamError = error;
        }
        _productsLoading = false;
        _initialLoadComplete = true;
        notifyListeners();
      },
    );
  }

  void selectCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    _resetVisibleProductLimit();
    _invalidateProductCaches();
    if (!_disposed) notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _resetVisibleProductLimit();
    _invalidateProductCaches();
    _syncCategoriesFromProducts();
    if (!_disposed) notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    _resetVisibleProductLimit();
    _invalidateProductCaches();
    _syncCategoriesFromProducts();
    if (!_disposed) notifyListeners();
  }

  void _applyProducts(List<ProductModel> items) {
    _products = List<ProductModel>.unmodifiable(items);
    _resetVisibleProductLimit();
    _invalidateProductCaches();
    _syncCategoriesFromProducts();
  }

  void _invalidateProductCaches() {
    _cachedFilteredProducts = null;
    _cachedCategorySections = null;
  }

  void _resetVisibleProductLimit() {
    _visibleProductLimit = productsPageSize;
  }

  void _syncCategoriesFromProducts() {
    final sections = categorySections;
    final titles = sections.map((entry) => entry.key).toList();

    if (listEquals(titles, _categoryTitles)) {
      _ensureSelectedCategoryValid(titles);
      return;
    }

    _categoryTitles = titles;
    _ensureSelectedCategoryValid(titles);
  }

  void _ensureSelectedCategoryValid(List<String> titles) {
    final available = <String>{
      allCategoryLabel,
      ...titles.where((title) => title != _hiddenMenuCategoryLabel),
    };
    if (_selectedCategory == _hiddenMenuCategoryLabel ||
        _selectedCategory == null ||
        !available.contains(_selectedCategory)) {
      _selectedCategory = allCategoryLabel;
    }
  }

  String _mapProductsError(Object error) {
    if (error is PostgrestException) {
      if (error.code == '42501' || error.message.contains('permission')) {
        return 'لا توجد صلاحية لعرض المنتجات من Supabase';
      }
      return 'تعذّر تحميل المنتجات من Supabase';
    }
    if (error is AuthException) {
      return 'خطأ في مصادقة Supabase';
    }
    if (error is TimeoutException) {
      return 'انتهت مهلة الاتصال. حاول مرة أخرى';
    }
    return 'تعذّر تحميل المنتجات';
  }

  @override
  void dispose() {
    _disposed = true;
    _bindGeneration++;
    _productsSubscription?.cancel();
    super.dispose();
  }
}
