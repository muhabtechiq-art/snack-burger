import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tenant_palette.dart';
import '../../models/product_model.dart';
import '../../models/restaurant_model.dart';
import '../../state/cart_notifier.dart';
import '../menu/customer_menu_controller.dart';
import '../menu/customer_menu_drawer.dart';
import '../theme/customer_menu_theme.dart';
import 'category_grid_card.dart';
import 'category_section_header.dart';
import 'customer_bottom_nav.dart';
import 'customer_menu_header.dart';
import 'customer_welcome_screen.dart';
import 'menu_cart_bar.dart';
import 'menu_product_card.dart';

/// غلاف واجهة المنيو — ترحيب ثم تصفح (أقسام / منتجات).
class CustomerMenuBrowsingShell extends StatefulWidget {
  const CustomerMenuBrowsingShell({
    super.key,
    required this.scaffoldKey,
    required this.scrollController,
    required this.searchController,
    required this.restaurant,
    required this.onClearSearch,
    required this.onQuickAdd,
    required this.onOpenDetails,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final RestaurantModel restaurant;
  final VoidCallback onClearSearch;
  final Future<void> Function(BuildContext context, ProductModel product)
      onQuickAdd;
  final Future<void> Function(BuildContext context, ProductModel product)
      onOpenDetails;

  @override
  State<CustomerMenuBrowsingShell> createState() =>
      _CustomerMenuBrowsingShellState();
}

class _CustomerMenuBrowsingShellState extends State<CustomerMenuBrowsingShell> {
  bool _showWelcome = true;
  String? _activeCategory;
  CustomerBottomNavItem _bottomNav = CustomerBottomNavItem.home;

  TenantPalette get _palette =>
      TenantPalette.fromRestaurant(widget.restaurant);

  void _startOrder() {
    setState(() => _showWelcome = false);
  }

  void _openCategory(String category) {
    final menu = context.read<CustomerMenuController>();
    menu.selectCategory(category);
    setState(() {
      _activeCategory = category;
      _bottomNav = CustomerBottomNavItem.home;
    });
  }

  void _goHome() {
    final menu = context.read<CustomerMenuController>();
    menu.selectCategory(CustomerMenuController.allCategoryLabel);
    setState(() => _activeCategory = null);
  }

  void _openCart() {
    final cartCount = context.read<CartNotifier>().itemCount;
    if (cartCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة')),
      );
      return;
    }
    unawaited(
      MenuCartBar.openCheckoutSheet(
        context,
        palette: _palette,
        restaurant: widget.restaurant,
      ),
    );
  }

  void _handleBottomNav(CustomerBottomNavItem item) {
    switch (item) {
      case CustomerBottomNavItem.home:
        setState(() {
          _bottomNav = item;
          _activeCategory = null;
        });
        context
            .read<CustomerMenuController>()
            .selectCategory(CustomerMenuController.allCategoryLabel);
      case CustomerBottomNavItem.orders:
        setState(() => _bottomNav = item);
        context.pushNamed(
          'my-orders',
          pathParameters: {'slug': widget.restaurant.slug},
        );
      case CustomerBottomNavItem.cart:
        setState(() => _bottomNav = item);
        _openCart();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showWelcome) {
      return CustomerWelcomeScreen(
        restaurant: widget.restaurant,
        onStartOrder: _startOrder,
      );
    }

    final cartCount = context.select<CartNotifier, int>(
      (cart) => cart.itemCount,
    );
    final headerTitle = _activeCategory ?? widget.restaurant.name;

    return Theme(
      data: CustomerMenuTheme.buildTheme(_palette),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          key: widget.scaffoldKey,
          backgroundColor: CustomerMenuTheme.surfaceWhite,
          drawer: CustomerMenuDrawer(
            restaurant: widget.restaurant,
            palette: _palette,
          ),
          appBar: CustomerMenuHeader(
            title: headerTitle,
            cartItemCount: cartCount,
            onOpenMenu: () => widget.scaffoldKey.currentState?.openDrawer(),
            onOpenCart: _openCart,
            leading: _activeCategory == null
                ? null
                : IconButton(
                    onPressed: _goHome,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: CustomerMenuTheme.ink,
                    ),
                  ),
          ),
          body: _activeCategory == null
              ? _CategoryHomeBody(
                  palette: _palette,
                  onCategoryTap: _openCategory,
                )
              : _CategoryProductsBody(
                  palette: _palette,
                  scrollController: widget.scrollController,
                  searchController: widget.searchController,
                  onClearSearch: widget.onClearSearch,
                  onQuickAdd: widget.onQuickAdd,
                  onOpenDetails: widget.onOpenDetails,
                ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MenuCartBar(
                palette: _palette,
                restaurant: widget.restaurant,
              ),
              CustomerBottomNav(
                selected: _bottomNav,
                cartItemCount: cartCount,
                onSelected: _handleBottomNav,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryHomeBody extends StatelessWidget {
  const _CategoryHomeBody({
    required this.palette,
    required this.onCategoryTap,
  });

  final TenantPalette palette;
  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Selector<CustomerMenuController, _CategoryHomeSnapshot>(
      selector: (_, menu) => _CategoryHomeSnapshot(
        loading: menu.productsLoading && !menu.hasProducts,
        error: menu.showProductsError,
        errorMessage: menu.productsErrorMessage,
        sections: menu.categorySections
            .where(
              (section) =>
                  section.key != CustomerMenuController.allCategoryLabel &&
                  section.key != 'قائمة عامة',
            )
            .toList(growable: false),
      ),
      builder: (context, snapshot, _) {
        final menu = context.read<CustomerMenuController>();

        if (snapshot.loading) {
          return const Center(
            child: CircularProgressIndicator(color: CustomerMenuTheme.mutedRed),
          );
        }

        if (snapshot.error) {
          return _ErrorState(
            message: snapshot.errorMessage ?? 'تعذّر تحميل المنتجات',
            onRetry: menu.retryProductsLoad,
          );
        }

        if (snapshot.sections.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد أقسام في القائمة حالياً.',
              style: TextStyle(
                color: CustomerMenuTheme.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  'اختر القسم',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: CustomerMenuTheme.ink.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final section = snapshot.sections[index];
                    return CategoryGridCard(
                      key: ValueKey(section.key),
                      categoryName: section.key,
                      products: section.value,
                      palette: palette,
                      onTap: () => onCategoryTap(section.key),
                    );
                  },
                  childCount: snapshot.sections.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: TextButton.icon(
                  onPressed: () =>
                      context.push('/${menu.slug}/admin/login'),
                  icon: Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 18,
                    color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.45),
                  ),
                  label: Text(
                    'دخول الإدارة',
                    style: TextStyle(
                      color:
                          CustomerMenuTheme.mutedRed.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryProductsBody extends StatelessWidget {
  const _CategoryProductsBody({
    required this.palette,
    required this.scrollController,
    required this.searchController,
    required this.onClearSearch,
    required this.onQuickAdd,
    required this.onOpenDetails,
  });

  final TenantPalette palette;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final VoidCallback onClearSearch;
  final Future<void> Function(BuildContext context, ProductModel product)
      onQuickAdd;
  final Future<void> Function(BuildContext context, ProductModel product)
      onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Selector<CustomerMenuController, _ProductsBodySnapshot>(
      selector: (_, menu) => _ProductsBodySnapshot(
        isSearching: menu.isSearching,
        loading: menu.productsLoading && !menu.hasProducts,
        error: menu.showProductsError,
        errorMessage: menu.productsErrorMessage,
        isEmpty: menu.isEmpty,
        sections: menu.visibleCategorySections,
        canLoadMore: menu.canLoadMoreProducts,
      ),
      builder: (context, snapshot, _) {
        final menu = context.read<CustomerMenuController>();

        return CustomScrollView(
          controller: scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: searchController,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  textInputAction: TextInputAction.search,
                  onChanged: menu.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'ابحث في القائمة...',
                    hintTextDirection: TextDirection.rtl,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: snapshot.isSearching
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: onClearSearch,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            if (snapshot.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: CustomerMenuTheme.mutedRed,
                  ),
                ),
              )
            else if (snapshot.error)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                  message: snapshot.errorMessage ?? 'تعذّر تحميل المنتجات',
                  onRetry: menu.retryProductsLoad,
                ),
              )
            else if (snapshot.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.isSearching
                            ? 'لا توجد نتائج مطابقة للبحث.'
                            : 'لا توجد منتجات في هذا القسم.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: CustomerMenuTheme.inkMuted),
                      ),
                      if (snapshot.isSearching) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: onClearSearch,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('مسح البحث'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              SliverMainAxisGroup(
                slivers: [
                  for (final section in snapshot.sections) ...[
                    SliverToBoxAdapter(
                      child: CategorySectionHeader(
                        title: section.key,
                        count: section.value.length,
                        palette: palette,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.76,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = section.value[index];
                            return MenuProductCard(
                              key: ValueKey(product.id),
                              product: product,
                              palette: palette,
                              layout: MenuProductCardLayout.grid,
                              onQuickAdd: () => onQuickAdd(context, product),
                              onOpenDetails: () =>
                                  onOpenDetails(context, product),
                            );
                          },
                          childCount: section.value.length,
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                        ),
                      ),
                    ),
                  ],
                  if (snapshot.canLoadMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: CustomerMenuTheme.mutedRed
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CustomerMenuTheme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

@immutable
class _CategoryHomeSnapshot {
  const _CategoryHomeSnapshot({
    required this.loading,
    required this.error,
    required this.errorMessage,
    required this.sections,
  });

  final bool loading;
  final bool error;
  final String? errorMessage;
  final List<MapEntry<String, List<ProductModel>>> sections;

  @override
  bool operator ==(Object other) {
    return other is _CategoryHomeSnapshot &&
        loading == other.loading &&
        error == other.error &&
        errorMessage == other.errorMessage &&
        _sectionsEqual(sections, other.sections);
  }

  static bool _sectionsEqual(
    List<MapEntry<String, List<ProductModel>>> a,
    List<MapEntry<String, List<ProductModel>>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key || a[i].value.length != b[i].value.length) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(loading, error, errorMessage, sections.length);
}

@immutable
class _ProductsBodySnapshot {
  const _ProductsBodySnapshot({
    required this.isSearching,
    required this.loading,
    required this.error,
    required this.errorMessage,
    required this.isEmpty,
    required this.sections,
    required this.canLoadMore,
  });

  final bool isSearching;
  final bool loading;
  final bool error;
  final String? errorMessage;
  final bool isEmpty;
  final List<MapEntry<String, List<ProductModel>>> sections;
  final bool canLoadMore;

  @override
  bool operator ==(Object other) {
    return other is _ProductsBodySnapshot &&
        isSearching == other.isSearching &&
        loading == other.loading &&
        error == other.error &&
        errorMessage == other.errorMessage &&
        isEmpty == other.isEmpty &&
        canLoadMore == other.canLoadMore &&
        _CategoryHomeSnapshot._sectionsEqual(sections, other.sections);
  }

  @override
  int get hashCode => Object.hash(
        isSearching,
        loading,
        error,
        errorMessage,
        isEmpty,
        canLoadMore,
        sections.length,
      );
}
