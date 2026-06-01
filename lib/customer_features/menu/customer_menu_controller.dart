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
    }
  }

  final ProductRepository _productRepository;
  String slug;
  final bool useMockProducts;
  final List<ProductModel> _mockProducts;

  StreamSubscription<List<ProductModel>>? _productsSubscription;

  String? _restaurantId;

  List<ProductModel> _products = const [];
  Object? _streamError;
  bool _productsLoading = true;
  String _searchQuery = '';
  String? _selectedCategory;
  List<String> _categoryTitles = const [];
  bool _disposed = false;

  String? get restaurantId => _restaurantId;

  List<ProductModel> get products =>
      List<ProductModel>.unmodifiable(_products);

  String get searchQuery => _searchQuery;

  bool get isSearching => _searchQuery.trim().isNotEmpty;

  bool get productsLoading => _productsLoading;

  Object? get streamError => _streamError;

  bool get hasProductsError => _streamError != null;

  String? get productsErrorMessage => _streamError == null
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
    if (category == null || category == allCategoryLabel) {
      return bySearch;
    }

    return bySearch
        .where((product) => product.category.trim() == category)
        .toList(growable: false);
  }

  List<MapEntry<String, List<ProductModel>>> get categorySections =>
      orderedCategoryEntries(filteredProducts);

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
      if (!_disposed) notifyListeners();
      return;
    }

    _productsSubscription?.cancel();
    _productsSubscription = null;
    _productsLoading = true;
    _streamError = null;
    if (!_disposed) notifyListeners();

    _productsSubscription = _productRepository
        .watchProductsForRestaurant(
          restaurantId: restaurantId,
          slug: slug,
        )
        .listen(
      (List<ProductModel> items) {
        if (_disposed) return;
        _applyProducts(items);
        _productsLoading = false;
        _streamError = null;
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('CustomerMenuController stream: $error\n$stack');
        if (_disposed) return;
        _streamError = error;
        _productsLoading = false;
        notifyListeners();
      },
    );
  }

  void selectCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    if (!_disposed) notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _syncCategoriesFromProducts();
    if (!_disposed) notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    _syncCategoriesFromProducts();
    if (!_disposed) notifyListeners();
  }

  void _applyProducts(List<ProductModel> items) {
    _products = List<ProductModel>.unmodifiable(items);
    _syncCategoriesFromProducts();
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
    return 'تعذّr تحميل المنتجات';
  }

  @override
  void dispose() {
    _disposed = true;
    _productsSubscription?.cancel();
    super.dispose();
  }
}
