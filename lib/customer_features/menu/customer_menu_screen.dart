import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/customer_wrapper.dart';
import '../../core/theme/tenant_palette.dart';
import '../../models/product_model.dart';
import '../../models/restaurant_model.dart';
import '../../state/active_restaurant_notifier.dart';
import '../../state/cart_notifier.dart';
import '../../state/delivery_location_notifier.dart';
import 'customer_menu_controller.dart';
import 'customer_menu_drawer.dart';
import '../services/customer_last_order_notifier.dart';
import '../widgets/category_section_header.dart';
import '../widgets/menu_banner.dart';
import '../widgets/menu_cart_bar.dart';
import '../widgets/menu_persistent_headers.dart';
import '../widgets/menu_product_card.dart';
import '../widgets/product_detail_dialog.dart';

/// واجهة المنيو للزبون — عرض وطلب فقط (بدون أي عناصر إدارية).
class CustomerMenuScreen extends StatelessWidget {
  const CustomerMenuScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return CustomerWrapper(
      slug: slug,
      child: _CustomerMenuScope(slug: slug),
    );
  }
}

class _CustomerMenuScope extends StatefulWidget {
  const _CustomerMenuScope({required this.slug});

  final String slug;

  @override
  State<_CustomerMenuScope> createState() => _CustomerMenuScopeState();
}

class _CustomerMenuScopeState extends State<_CustomerMenuScope> {
  final CartNotifier _cartNotifier = CartNotifier();
  final DeliveryLocationNotifier _locationNotifier = DeliveryLocationNotifier();
  late final CustomerLastOrderNotifier _lastOrderNotifier;

  @override
  void initState() {
    super.initState();
    _lastOrderNotifier = CustomerLastOrderNotifier(slug: widget.slug);
  }

  @override
  void dispose() {
    _cartNotifier.dispose();
    _locationNotifier.dispose();
    _lastOrderNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          key: ValueKey(widget.slug),
          create: (_) => CustomerMenuController(slug: widget.slug),
        ),
        ChangeNotifierProvider<CartNotifier>.value(value: _cartNotifier),
        ChangeNotifierProvider<DeliveryLocationNotifier>.value(
          value: _locationNotifier,
        ),
        ChangeNotifierProvider<CustomerLastOrderNotifier>.value(
          value: _lastOrderNotifier,
        ),
      ],
      child: _CustomerMenuSlugResolver(
        slug: widget.slug,
        child: const _CustomerMenuBody(),
      ),
    );
  }
}

class _CustomerMenuSlugResolver extends StatefulWidget {
  const _CustomerMenuSlugResolver({
    required this.slug,
    required this.child,
  });

  final String slug;
  final Widget child;

  @override
  State<_CustomerMenuSlugResolver> createState() =>
      _CustomerMenuSlugResolverState();
}

class _CustomerMenuSlugResolverState extends State<_CustomerMenuSlugResolver> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ActiveRestaurantNotifier>().resolveSlug(widget.slug);
    });
  }

  @override
  void didUpdateWidget(covariant _CustomerMenuSlugResolver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) {
      context.read<ActiveRestaurantNotifier>().resolveSlug(widget.slug);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _CustomerMenuBody extends StatefulWidget {
  const _CustomerMenuBody();

  @override
  State<_CustomerMenuBody> createState() => _CustomerMenuBodyState();
}

class _CustomerMenuBodyState extends State<_CustomerMenuBody> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, GlobalKey> _sectionKeys = {};

  late CustomerMenuController _menuController;
  String? _boundRestaurantId;

  @override
  void initState() {
    super.initState();
    _menuController = context.read<CustomerMenuController>();
    _menuController.addListener(_onMenuControllerChanged);
  }

  @override
  void dispose() {
    _menuController.removeListener(_onMenuControllerChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onMenuControllerChanged() {
    if (!mounted) return;
    _syncSectionKeys(_menuController.categories);
  }

  void _openMenuDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _syncSectionKeys(List<String> titles) {
    _sectionKeys.removeWhere((key, _) => !titles.contains(key));
    for (final title in titles) {
      _sectionKeys.putIfAbsent(title, GlobalKey.new);
    }
  }

  void _maybeBindMenu(RestaurantModel restaurant, CustomerMenuController menu) {
    if (_boundRestaurantId == restaurant.id) return;
    _boundRestaurantId = restaurant.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_boundRestaurantId != restaurant.id) return;
      menu.bindToRestaurant(
        restaurantId: restaurant.id,
        slug: restaurant.slug,
      );
    });
  }

  void _clearSearch(CustomerMenuController menu) {
    _searchController.clear();
    menu.clearSearch();
  }

  void _addToCart(BuildContext context, ProductModel product) {
    context.read<CartNotifier>().addProduct(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة ${product.name} إلى السلة'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openProductDetails(
    BuildContext context,
    ProductModel product,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ProductDetailDialog(
        product: product,
        palette: TenantPalette.fromRestaurant(
          context.read<ActiveRestaurantNotifier>().restaurant!,
        ),
        onAdd: ({required selectedAddons, selectedVariant}) {
          context.read<CartNotifier>().addProduct(
            product,
            selectedAddons: selectedAddons,
            selectedVariant: selectedVariant,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تمت إضافة ${product.name} إلى السلة'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleQuickAdd(
    BuildContext context,
    ProductModel product,
  ) async {
    if (!product.requiresConfiguration) {
      _addToCart(context, product);
      return;
    }
    await _openProductDetails(context, product);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Consumer2<ActiveRestaurantNotifier, CustomerMenuController>(
        builder: (context, tenant, menu, _) {
          if (tenant.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final restaurant = tenant.restaurant;
          if (restaurant == null || !restaurant.isActive) {
            return Scaffold(
              appBar: AppBar(title: const Text('غير متوفر')),
              body: const Center(
                child: Text('المطعم غير موجود أو غير مفعّل.'),
              ),
            );
          }

          _maybeBindMenu(restaurant, menu);
          _syncSectionKeys(menu.categories);

          final palette = TenantPalette.fromRestaurant(restaurant);

          final menuTheme = Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: palette.primary,
              primary: palette.primary,
              secondary: palette.accent,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: palette.surfaceTint,
            iconTheme: IconThemeData(color: palette.primary),
            textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: SnackBurgerBrandColors.ink,
                  displayColor: SnackBurgerBrandColors.ink,
                ),
            appBarTheme: AppBarTheme(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              iconTheme: IconThemeData(color: palette.onPrimary),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.primary,
                side: BorderSide(
                  color: palette.primary.withValues(alpha: 0.35),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              prefixIconColor: palette.primary,
              suffixIconColor: palette.primary,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: palette.primary.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: palette.primary, width: 1.5),
              ),
            ),
          );

          return Theme(
            data: menuTheme,
            child: Scaffold(
              key: _scaffoldKey,
              backgroundColor: palette.surfaceTint,
              drawer: CustomerMenuDrawer(
                restaurant: restaurant,
                palette: palette,
              ),
              bottomNavigationBar: Consumer<CartNotifier>(
                builder: (context, cart, _) {
                  if (cart.itemCount == 0) {
                    return const SizedBox.shrink();
                  }
                  return MenuCartBar(
                    palette: palette,
                    restaurant: restaurant,
                  );
                },
              ),
              body: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  MenuBanner(
                    restaurant: restaurant,
                    palette: palette,
                    onBack: () => context.go('/'),
                    onOpenMenu: _openMenuDrawer,
                  ),
                  MenuStickyControlsHeader(
                    searchController: _searchController,
                    isSearching: menu.isSearching,
                    onQueryChanged: menu.setSearchQuery,
                    onClear: () => _clearSearch(menu),
                    categories: menu.categories,
                    selectedCategory:
                        menu.selectedCategory ?? menu.categories.firstOrNull,
                    onCategorySelected: menu.selectCategory,
                    palette: palette,
                  ),
                  _buildProductsSliver(
                    context: context,
                    menu: menu,
                    palette: palette,
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: TextButton.icon(
                        onPressed: () =>
                            context.push('/${restaurant.slug}/admin/login'),
                        icon: Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 18,
                          color: palette.primary.withValues(alpha: 0.55),
                        ),
                        label: Text(
                          'دخول الإدارة',
                          style: TextStyle(
                            color: palette.primary.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsSliver({
    required BuildContext context,
    required CustomerMenuController menu,
    required TenantPalette palette,
  }) {
    if (menu.productsLoading && !menu.hasProducts) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: CircularProgressIndicator(color: palette.primary),
          ),
        ),
      );
    }

    if (menu.showProductsError) {
      final message =
          menu.productsErrorMessage ?? 'تعذّر تحميل المنتجات';
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: palette.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.primary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: menu.retryProductsLoad,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (menu.isEmpty) {
      final message = menu.isSearching
          ? 'لا توجد نتائج مطابقة للبحث.'
          : 'لا توجد منتجات في قائمة المطعم حالياً.';

      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.primary.withValues(alpha: 0.7)),
              ),
              if (menu.isSearching) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _clearSearch(menu),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('الرجوع للقائمة الكاملة'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return _buildProductListSliver(
      context: context,
      sections: menu.categorySections,
      palette: palette,
    );
  }

  Widget _buildProductListSliver({
    required BuildContext context,
    required List<MapEntry<String, List<ProductModel>>> sections,
    required TenantPalette palette,
  }) {
    return SliverMainAxisGroup(
      slivers: [
        for (final section in sections) ...[
          SliverToBoxAdapter(
            child: CategorySectionHeader(
              title: section.key,
              count: section.value.length,
              palette: palette,
              sectionKey: _sectionKeys[section.key],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.76,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = section.value[index];
                  return MenuProductCard(
                    product: product,
                    palette: palette,
                    layout: MenuProductCardLayout.grid,
                    onQuickAdd: () => _handleQuickAdd(context, product),
                    onOpenDetails: () => _openProductDetails(context, product),
                  );
                },
                childCount: section.value.length,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}
