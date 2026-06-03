import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/customer_wrapper.dart';
import '../../core/theme/tenant_palette.dart';
import '../../models/delivery_order_model.dart';
import '../../state/active_restaurant_notifier.dart';
import '../data/customer_order_repository.dart';
import '../services/customer_order_session.dart';
import '../../admin_features/orders/widgets/order_item_receipt_lines.dart';

/// شاشة «طلباتي» — تفاصيل الطلب فقط بدون خطوات حالة.
class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return CustomerWrapper(
      slug: slug,
      child: _MyOrdersScope(slug: slug),
    );
  }
}

class _MyOrdersScope extends StatefulWidget {
  const _MyOrdersScope({required this.slug});

  final String slug;

  @override
  State<_MyOrdersScope> createState() => _MyOrdersScopeState();
}

class _MyOrdersScopeState extends State<_MyOrdersScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ActiveRestaurantNotifier>().resolveSlug(widget.slug);
    });
  }

  @override
  Widget build(BuildContext context) => _MyOrdersBody(slug: widget.slug);
}

class _MyOrdersBody extends StatefulWidget {
  const _MyOrdersBody({required this.slug});

  final String slug;

  @override
  State<_MyOrdersBody> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<_MyOrdersBody> {
  final CustomerOrderRepository _repository = CustomerOrderRepository();

  String? _orderId;
  Future<DeliveryOrder?>? _orderFuture;

  static const _friendlyMessage =
      'نتمنى لك وجبة شهية! طلبك قيد التجهيز وسيصلك قريباً.';

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final orderId = await CustomerOrderSession.getLastOrderId(widget.slug);
    if (!mounted) return;
    setState(() {
      _orderId = orderId;
      _orderFuture = orderId == null ? null : _fetchOrder(orderId);
    });
  }

  Future<DeliveryOrder?> _fetchOrder(String orderId) {
    return _repository.watchOrderById(orderId: orderId).first;
  }

  Future<void> _retry() async {
    if (_orderId == null) {
      await _loadOrder();
      return;
    }
    setState(() => _orderFuture = _fetchOrder(_orderId!));
    await _orderFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Consumer<ActiveRestaurantNotifier>(
        builder: (context, tenant, _) {
          final restaurant = tenant.restaurant;
          final palette = restaurant != null
              ? TenantPalette.fromRestaurant(restaurant)
              : const TenantPalette(
                  primary: SnackBurgerBrandColors.primary,
                  accent: SnackBurgerBrandColors.accent,
                );

          return Scaffold(
            backgroundColor: palette.surfaceTint,
            appBar: AppBar(
              title: const Text('طلباتي'),
              centerTitle: true,
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
            ),
            body: _buildBody(palette),
          );
        },
      ),
    );
  }

  Widget _buildBody(TenantPalette palette) {
    if (_orderId == null) {
      return _EmptyMyOrdersState(
        palette: palette,
        onBackToMenu: () => context.pop(),
      );
    }

    return FutureBuilder<DeliveryOrder?>(
      future: _orderFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: palette.primary),
          );
        }

        if (snapshot.hasError) {
          return _MyOrdersErrorState(
            palette: palette,
            onRetry: _retry,
          );
        }

        final order = snapshot.data;
        if (order == null) {
          return _MyOrdersErrorState(
            palette: palette,
            message: 'لم يتم العثور على طلبك.',
            onRetry: _retry,
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _FriendlyMessageCard(
              palette: palette,
              message: _friendlyMessage,
            ),
            const SizedBox(height: 16),
            _OrderItemsSection(order: order, palette: palette),
            const SizedBox(height: 16),
            _OrderTotalCard(order: order, palette: palette),
          ],
        );
      },
    );
  }
}

class _FriendlyMessageCard extends StatelessWidget {
  const _FriendlyMessageCard({
    required this.palette,
    required this.message,
  });

  final TenantPalette palette;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.primary.withValues(alpha: 0.92),
            palette.primary.withValues(alpha: 0.78),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_rounded,
              color: palette.onPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'شكراً لطلبك!',
                  style: TextStyle(
                    color: palette.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: palette.onPrimary.withValues(alpha: 0.95),
                    fontSize: 14.5,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemsSection extends StatelessWidget {
  const _OrderItemsSection({
    required this.order,
    required this.palette,
  });

  final DeliveryOrder order;
  final TenantPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: palette.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'تفاصيل الطلب',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: palette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < order.items.length; i++) ...[
            OrderItemReceiptLines(
              item: order.items[i],
              primaryColor: palette.primary,
            ),
            if (i < order.items.length - 1)
              Divider(
                height: 22,
                color: palette.primary.withValues(alpha: 0.1),
              ),
          ],
        ],
      ),
    );
  }
}

class _OrderTotalCard extends StatelessWidget {
  const _OrderTotalCard({
    required this.order,
    required this.palette,
  });

  final DeliveryOrder order;
  final TenantPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Text(
            '${order.totalPrice.toStringAsFixed(0)} د.ع',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: palette.primary,
            ),
          ),
          const Spacer(),
          Text(
            'الإجمالي',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: palette.primary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMyOrdersState extends StatelessWidget {
  const _EmptyMyOrdersState({
    required this.palette,
    required this.onBackToMenu,
  });

  final TenantPalette palette;
  final VoidCallback onBackToMenu;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 56,
              color: palette.primary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد طلب محفوظ بعد.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.primary.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onBackToMenu,
              icon: const Icon(Icons.restaurant_menu_rounded),
              label: const Text('العودة للمنيو'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyOrdersErrorState extends StatelessWidget {
  const _MyOrdersErrorState({
    required this.palette,
    required this.onRetry,
    this.message = 'تعذّر تحميل تفاصيل الطلب.',
  });

  final TenantPalette palette;
  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: palette.primary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
