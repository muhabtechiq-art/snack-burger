import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/utils/price_utils.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/admin_route_observer.dart';
import '../../models/business_day_order_stats.dart';
import '../../models/delivery_order_model.dart';
import '../../state/business_day_notifier.dart';
import '../../state/active_restaurant_notifier.dart';
import '../data/admin_repositories.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';

/// الصفحة الرئيسية للإدارة — لوحة تحكم بصرية.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, required this.slug});

  final String slug;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with RouteAware {
  final AdminOrderRepository _orderRepository = AdminOrderRepository();
  final AdminProductRepository _productRepository = AdminProductRepository();

  int _todayOrderCount = 0;
  double _todaySales = 0;
  int _pendingOrderCount = 0;
  List<DeliveryOrder> _recentPendingOrders = const [];
  int _productCount = 0;
  bool _loadingStats = false;

  StreamSubscription<List<DeliveryOrder>>? _orderChangesSubscription;
  Timer? _realtimeRefreshDebounce;
  int _refreshGeneration = 0;
  String? _subscribedOrdersKey;
  ModalRoute<void>? _route;
  BusinessDayNotifier? _businessDayNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _businessDayNotifier = context.read<BusinessDayNotifier>();
      _businessDayNotifier!.addListener(_onBusinessDayChanged);
      unawaited(_bootstrapDashboard());
    });
  }

  void _onBusinessDayChanged() {
    unawaited(_refreshDashboardStats(includeProducts: false));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) {
        adminRouteObserver.unsubscribe(this);
      }
      _route = route;
      adminRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _businessDayNotifier?.removeListener(_onBusinessDayChanged);
    adminRouteObserver.unsubscribe(this);
    _orderChangesSubscription?.cancel();
    _realtimeRefreshDebounce?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    unawaited(_refreshDashboardStats(includeProducts: true));
  }

  Future<void> _bootstrapDashboard() async {
    final tenant = context.read<ActiveRestaurantNotifier>();
    if (tenant.restaurant == null) {
      await tenant.resolveSlug(widget.slug);
    }
    if (!mounted) return;

    final restaurant = context.read<ActiveRestaurantNotifier>().restaurant;
    if (restaurant == null) return;

    final businessDayNotifier = context.read<BusinessDayNotifier>();
    await businessDayNotifier.ensureScope(
          restaurantId: restaurant.id,
          slug: widget.slug,
        );
    if (!mounted) return;

    _ensureOrderChangeSubscription(
      businessDayId: businessDayNotifier.openDay?.id,
    );
    await _refreshDashboardStats(includeProducts: true);
  }

  void _ensureOrderChangeSubscription({required String? businessDayId}) {
    final key = businessDayId ?? 'none';
    if (_subscribedOrdersKey == key) return;

    _orderChangesSubscription?.cancel();
    _subscribedOrdersKey = key;
    if (businessDayId == null) return;

    _orderChangesSubscription = _orderRepository
        .watchOrdersForBusinessDay(businessDayId: businessDayId)
        .listen(
          (_) => _scheduleRealtimeReportRefresh(),
          onError: (Object error, StackTrace stack) {
            debugPrint('[AdminHomeScreen] order watch error: $error');
          },
          cancelOnError: false,
        );
  }

  void _scheduleRealtimeReportRefresh() {
    _realtimeRefreshDebounce?.cancel();
    _realtimeRefreshDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      unawaited(_refreshDashboardStats(includeProducts: false));
    });
  }

  Future<void> _refreshDashboardStats({required bool includeProducts}) async {
    final tenant = context.read<ActiveRestaurantNotifier>();
    var restaurant = tenant.restaurant;
    if (restaurant == null) {
      await tenant.resolveSlug(widget.slug);
      if (!mounted) return;
      restaurant = context.read<ActiveRestaurantNotifier>().restaurant;
    }
    if (restaurant == null) return;

    _ensureOrderChangeSubscription(
      businessDayId: context.read<BusinessDayNotifier>().openDay?.id,
    );

    final generation = ++_refreshGeneration;
    if (mounted) {
      setState(() => _loadingStats = true);
    }

    try {
      final openDay = context.read<BusinessDayNotifier>().openDay;
      BusinessDayOrderStats? stats;
      if (openDay != null) {
        stats = await _orderRepository.fetchBusinessDayOrderStats(
          businessDayId: openDay.id,
          businessDay: openDay,
        );
      }
      final products = includeProducts
          ? await _productRepository.fetchProducts(
              restaurantId: restaurant.id,
              slug: widget.slug,
            )
          : null;

      if (!mounted || generation != _refreshGeneration) return;

      if (stats != null) {
        debugPrint(
          '[QA][DashboardReport] pending=${stats.pendingOrdersCount} '
          'countableOrders=${stats.closingCountableOrders} '
          'countableSales=${stats.closingCountableSales} '
          'at=${DateTime.now().toIso8601String()}',
        );
      }

      setState(() {
        _pendingOrderCount = stats?.pendingOrdersCount ?? 0;
        _recentPendingOrders = stats?.pendingOrders.take(2).toList() ??
            const <DeliveryOrder>[];
        _todayOrderCount = stats?.closingCountableOrders ?? 0;
        _todaySales = stats?.closingCountableSales ?? 0;
        if (products != null) {
          _productCount = products.length;
        }
        _loadingStats = false;
      });
    } catch (_) {
      if (!mounted || generation != _refreshGeneration) return;
      final hadStats = _todayOrderCount > 0 ||
          _todaySales > 0 ||
          _pendingOrderCount > 0 ||
          _productCount > 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'تعذّر تحميل الإحصائيات. تحقق من الإنترنت وحاول مرة أخرى',
          ),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            onPressed: () {
              unawaited(_refreshDashboardStats(includeProducts: true));
            },
          ),
        ),
      );
      setState(() {
        if (!hadStats) {
          _todayOrderCount = 0;
          _todaySales = 0;
          _productCount = 0;
        }
        _loadingStats = false;
      });
    }
  }

  void _openOrders() {
    context.push('/${widget.slug}/admin/orders');
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      slug: widget.slug,
      title: 'لوحة التحكم',
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: _loadingStats
              ? null
              : () => unawaited(_refreshDashboardStats(includeProducts: true)),
          icon: _loadingStats
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AdminPanelColors.gold,
                  ),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Consumer<ActiveRestaurantNotifier>(
        builder: (context, tenant, _) {
          final restaurant = tenant.restaurant;
          if (restaurant == null) {
            return DecoratedBox(
              decoration: BoxDecoration(gradient: AdminPanelColors.loginGradient),
              child: const Center(
                child: CircularProgressIndicator(color: AdminPanelColors.gold),
              ),
            );
          }

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: AdminPanelColors.loginGradient,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _DashboardWelcomeHeader(),
                    const SizedBox(height: 14),
                    _DashboardStatsGrid(
                      pendingCount: _pendingOrderCount,
                      todayOrderCount: _todayOrderCount,
                      todaySales: _todaySales,
                      productCount: _productCount,
                    ),
                    const SizedBox(height: 20),
                    _RecentOrdersSection(
                      orders: _recentPendingOrders,
                      showViewAll: _pendingOrderCount > 2,
                      onViewAll: _openOrders,
                      onOrderTap: _openOrders,
                    ),
                    const SizedBox(height: 16),
                    _PendingOrdersCta(
                      pendingCount: _pendingOrderCount,
                      onTap: _openOrders,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardWelcomeHeader extends StatelessWidget {
  const _DashboardWelcomeHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AdminPanelColors.gold.withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                SizedBox(width: 6),
                Text(
                  'مباشر',
                  style: TextStyle(
                    color: AdminPanelColors.textLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'مرحباً بك 👋',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: AdminPanelColors.textLight,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Snack Burger',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: AdminPanelColors.gold,
            fontWeight: FontWeight.w900,
            fontSize: 17,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 3,
          width: 72,
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: AdminPanelColors.gold,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _DashboardStatsGrid extends StatelessWidget {
  const _DashboardStatsGrid({
    required this.pendingCount,
    required this.todayOrderCount,
    required this.todaySales,
    required this.productCount,
  });

  final int pendingCount;
  final int todayOrderCount;
  final double todaySales;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _DashboardStatTile(
                icon: Icons.notifications_active_rounded,
                label: 'الطلبات المعلقة',
                value: '$pendingCount',
                iconColor: pendingCount > 0
                    ? AdminPanelColors.charcoal
                    : AdminPanelColors.gold,
                accent: pendingCount > 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DashboardStatTile(
                icon: Icons.receipt_long_rounded,
                label: 'طلبات اليوم',
                value: '$todayOrderCount',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DashboardStatTile(
                icon: Icons.payments_rounded,
                label: 'مبيعات اليوم',
                value: PriceUtils.formatPriceWithCurrency(todaySales),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DashboardStatTile(
                icon: Icons.restaurant_menu_rounded,
                label: 'عدد المنتجات',
                value: '$productCount',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashboardStatTile extends StatelessWidget {
  const _DashboardStatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.accent = false,
  });

  static const _tileHeight = 120.0;

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _tileHeight,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: accent
            ? Border.all(
                color: AdminPanelColors.gold.withValues(alpha: 0.6),
                width: 1.5,
              )
            : Border.all(
                color: AdminPanelColors.gold.withValues(alpha: 0.15),
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? AdminPanelColors.gold)
                    .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AdminPanelColors.gold,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AdminPanelColors.charcoal,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AdminPanelColors.charcoal.withValues(alpha: 0.58),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersSection extends StatelessWidget {
  const _RecentOrdersSection({
    required this.orders,
    required this.showViewAll,
    required this.onViewAll,
    required this.onOrderTap,
  });

  final List<DeliveryOrder> orders;
  final bool showViewAll;
  final VoidCallback onViewAll;
  final VoidCallback onOrderTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AdminPanelColors.gold.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
          ),
          child: Row(
            children: [
              if (showViewAll)
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AdminPanelColors.gold,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'عرض الكل',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              const Spacer(),
              const Text(
                'أحدث الطلبات',
                style: TextStyle(
                  color: AdminPanelColors.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: AdminPanelColors.cardCream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AdminPanelColors.gold.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 20,
                  color: AdminPanelColors.charcoal.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'لا توجد طلبات معلقة حالياً',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AdminPanelColors.charcoal.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...orders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecentOrderTile(
                order: order,
                onTap: onOrderTap,
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({
    required this.order,
    required this.onTap,
  });

  final DeliveryOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminPanelColors.cardCream,
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.chevron_left_rounded,
                color: AdminPanelColors.charcoal.withValues(alpha: 0.35),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    PriceUtils.formatPriceWithCurrency(order.totalPrice),
                    style: const TextStyle(
                      color: AdminPanelColors.charcoal,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AdminPanelColors.gold.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'معلّق',
                      style: TextStyle(
                        color: AdminPanelColors.charcoal,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      order.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AdminPanelColors.charcoal,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.displayOrderHeroLabel,
                      style: TextStyle(
                        color: AdminPanelColors.charcoal.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.customerPhone,
                      style: TextStyle(
                        color: AdminPanelColors.charcoal.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AdminPanelColors.gold.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AdminPanelColors.charcoal,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingOrdersCta extends StatelessWidget {
  const _PendingOrdersCta({
    required this.pendingCount,
    required this.onTap,
  });

  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingCount > 0;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(
          hasPending
              ? Icons.notifications_active_rounded
              : Icons.dashboard_rounded,
          size: 20,
        ),
        label: Text(
          hasPending
              ? 'عرض $pendingCount طلب معلق مباشر'
              : 'لوحة الطلبات المعلقة (مباشر)',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor:
              hasPending ? AdminPanelColors.gold : Colors.white,
          foregroundColor: AdminPanelColors.charcoal,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: hasPending ? 2 : 1,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
