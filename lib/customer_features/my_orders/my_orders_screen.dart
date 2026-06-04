import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/customer_wrapper.dart';
import '../../core/config/customer_my_orders_config.dart';
import '../../core/theme/tenant_palette.dart';
import '../../models/delivery_order_model.dart';
import '../../models/delivery_order_status.dart';
import '../../state/active_restaurant_notifier.dart';
import '../data/customer_order_repository.dart';
import '../services/customer_order_session.dart';
import '../../admin_features/orders/widgets/order_item_receipt_lines.dart';

/// شاشة «طلباتي» — كل الطلبات المرتبطة برقم هاتف الجلسة.
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

  String? _phone;
  bool _sessionLoaded = false;
  StreamSubscription<List<DeliveryOrder>>? _ordersSubscription;
  List<DeliveryOrder> _orders = const [];
  Object? _streamError;
  bool _waitingFirstEvent = true;

  static const _friendlyMessage =
      'نتمنى لك وجبة شهية! طلبك قيد التجهيز وسيصلك قريباً.';

  @override
  void initState() {
    super.initState();
    unawaited(_loadSession());
  }

  @override
  void dispose() {
    unawaited(_ordersSubscription?.cancel());
    super.dispose();
  }

  Future<void> _loadSession() async {
    final phone = await CustomerOrderSession.getCustomerPhone(widget.slug);
    if (!mounted) return;
    setState(() {
      _phone = phone;
      _sessionLoaded = true;
    });
    if (phone != null && phone.isNotEmpty) {
      _subscribeToOrders(phone);
    }
  }

  void _subscribeToOrders(String phone) {
    unawaited(_ordersSubscription?.cancel());
    _streamError = null;
    _waitingFirstEvent = true;
    if (mounted) setState(() {});

    _ordersSubscription = _repository
        .watchOrdersByPhone(slug: widget.slug, phoneNumber: phone)
        .listen(
      (orders) {
        if (!mounted) return;
        setState(() {
          _orders = orders;
          _streamError = null;
          _waitingFirstEvent = false;
        });
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('MyOrdersScreen stream: $error\n$stack');
        if (!mounted) return;
        setState(() {
          _streamError = error;
          _waitingFirstEvent = false;
        });
      },
    );
  }

  Future<void> _retry() async {
    final phone = _phone;
    if (phone == null || phone.isEmpty) {
      await _loadSession();
      return;
    }
    _subscribeToOrders(phone);
  }

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case DeliveryOrderStatus.pending:
        return 'قيد المراجعة';
      case DeliveryOrderStatus.accepted:
        return 'مقبول';
      case DeliveryOrderStatus.preparing:
        return 'قيد التحضير';
      case DeliveryOrderStatus.delivering:
        return 'قيد التوصيل';
      case DeliveryOrderStatus.delivered:
        return 'تم التسليم';
      case DeliveryOrderStatus.rejected:
        return 'مرفوض';
      default:
        return status;
    }
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
    if (!_sessionLoaded) {
      return Center(
        child: CircularProgressIndicator(color: palette.primary),
      );
    }

    if (_phone == null || _phone!.isEmpty) {
      return _EmptyMyOrdersState(
        palette: palette,
        message: 'لا يوجد رقم هاتف محفوظ.\nأرسل طلباً من المنيو لحفظ رقمك.',
        onBackToMenu: () => context.pop(),
      );
    }

    if (_waitingFirstEvent && _streamError == null) {
      return Center(
        child: CircularProgressIndicator(color: palette.primary),
      );
    }

    if (_streamError != null && _orders.isEmpty) {
      return _MyOrdersErrorState(
        palette: palette,
        onRetry: _retry,
      );
    }

    if (_orders.isEmpty) {
      final hours = CustomerMyOrdersConfig.visibleOrdersWindow.inHours;
      return _EmptyMyOrdersState(
        palette: palette,
        message:
            'لا توجد طلبات خلال آخر $hours ساعة لهذا الرقم.\n'
            'الطلبات الأقدم لا تظهر هنا.',
        onBackToMenu: () => context.pop(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemCount: _orders.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _FriendlyMessageCard(
              palette: palette,
              message: _friendlyMessage,
            ),
          );
        }

        final order = _orders[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _OrderListTile(
            order: order,
            palette: palette,
            statusLabel: _statusLabel(order.status),
            onTap: () => _showOrderDetails(context, order, palette),
          ),
        );
      },
    );
  }

  void _showOrderDetails(
    BuildContext context,
    DeliveryOrder order,
    TenantPalette palette,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: Icon(Icons.close_rounded, color: palette.primary),
                        ),
                        Expanded(
                          child: Text(
                            'تفاصيل الطلب',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: palette.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _OrderMetaRow(
                      label: 'الحالة',
                      value: _statusLabel(order.status),
                      palette: palette,
                    ),
                    _OrderMetaRow(
                      label: 'التاريخ',
                      value: _formatDate(order.createdAt),
                      palette: palette,
                    ),
                    const SizedBox(height: 12),
                    _OrderItemsSection(order: order, palette: palette),
                    const SizedBox(height: 12),
                    _OrderTotalCard(order: order, palette: palette),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y/$m/$d — $h:$min';
  }
}

class _OrderListTile extends StatelessWidget {
  const _OrderListTile({
    required this.order,
    required this.palette,
    required this.statusLabel,
    required this.onTap,
  });

  final DeliveryOrder order;
  final TenantPalette palette;
  final String statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.primary.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(Icons.chevron_left_rounded, color: palette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${order.totalPrice.toStringAsFixed(0)} د.ع',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.items.length} صنف · $statusLabel',
                      style: TextStyle(
                        color: palette.primary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.receipt_long_rounded, color: palette.accent, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderMetaRow extends StatelessWidget {
  const _OrderMetaRow({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final TenantPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: palette.primary,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: palette.primary.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
    required this.message,
    required this.onBackToMenu,
  });

  final TenantPalette palette;
  final String message;
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
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.primary.withValues(alpha: 0.75),
                height: 1.5,
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
  });

  final TenantPalette palette;
  final VoidCallback onRetry;
  static const String _message = 'تعذّر تحميل الطلبات.';

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
              _message,
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
