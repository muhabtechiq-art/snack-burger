import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/customer_wrapper.dart';
import '../../core/theme/tenant_palette.dart';
import '../../models/product_model.dart';
import '../../models/restaurant_model.dart';
import '../../state/active_restaurant_notifier.dart';
import '../../state/cart_notifier.dart';
import '../../state/delivery_location_notifier.dart';
import 'customer_menu_banners_controller.dart';
import 'customer_menu_controller.dart';
import '../services/customer_last_order_notifier.dart';
import '../widgets/customer_menu_browsing_shell.dart';
import '../widgets/product_detail_page.dart';

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
          key: ValueKey('menu-${widget.slug}'),
          create: (_) => CustomerMenuController(slug: widget.slug),
        ),
        ChangeNotifierProvider(
          key: ValueKey('banners-${widget.slug}'),
          create: (_) => CustomerMenuBannersController(slug: widget.slug),
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

  late CustomerMenuController _menuController;
  late CustomerMenuBannersController _bannersController;
  String? _boundRestaurantId;

  @override
  void initState() {
    super.initState();
    _menuController = context.read<CustomerMenuController>();
    _bannersController = context.read<CustomerMenuBannersController>();
    _scrollController.addListener(_onScrollForLoadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollForLoadMore);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScrollForLoadMore() {
    if (!_scrollController.hasClients) return;
    final menu = _menuController;
    if (!menu.canLoadMoreProducts) return;

    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels < 480) {
      menu.loadMoreProducts();
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
      _bannersController.bindToRestaurant(
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
    final restaurant = context.read<ActiveRestaurantNotifier>().restaurant!;
    final palette = TenantPalette.fromRestaurant(restaurant);
    await ProductDetailPage.open(
      context,
      product: product,
      palette: palette,
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
      child: Selector<ActiveRestaurantNotifier, _TenantGateSnapshot>(
        selector: (_, tenant) => _TenantGateSnapshot(
          isLoading: tenant.isLoading,
          restaurant: tenant.restaurant,
        ),
        shouldRebuild: (previous, next) => previous != next,
        builder: (context, tenantSnapshot, _) {
          if (tenantSnapshot.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final restaurant = tenantSnapshot.restaurant;
          if (restaurant == null || !restaurant.isActive) {
            return Scaffold(
              appBar: AppBar(title: const Text('غير متوفر')),
              body: const Center(
                child: Text('المطعم غير موجود أو غير مفعّل.'),
              ),
            );
          }

          _maybeBindMenu(restaurant, _menuController);

          return CustomerMenuBrowsingShell(
            scaffoldKey: _scaffoldKey,
            scrollController: _scrollController,
            searchController: _searchController,
            restaurant: restaurant,
            onClearSearch: () => _clearSearch(_menuController),
            onQuickAdd: _handleQuickAdd,
            onOpenDetails: _openProductDetails,
          );
        },
      ),
    );
  }
}

@immutable
class _TenantGateSnapshot {
  const _TenantGateSnapshot({
    required this.isLoading,
    required this.restaurant,
  });

  final bool isLoading;
  final RestaurantModel? restaurant;

  @override
  bool operator ==(Object other) {
    if (other is! _TenantGateSnapshot) return false;
    if (isLoading != other.isLoading) return false;
    final a = restaurant;
    final b = other.restaurant;
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return a.id == b.id &&
        a.slug == b.slug &&
        a.isActive == b.isActive;
  }

  @override
  int get hashCode => Object.hash(isLoading, restaurant?.id);
}
