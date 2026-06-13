import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/config/printer_config.dart';
import '../../../core/theme/tenant_palette.dart';
import '../../../models/delivery_order_model.dart';
import '../../../models/restaurant_model.dart';
import '../data/admin_repositories.dart';
import 'admin_panel_colors.dart';

/// Drawer إداري — يظهر فقط داخل واجهة الإدارة.
class AdminDrawer extends StatefulWidget {
  const AdminDrawer({
    super.key,
    required this.slug,
    required this.restaurant,
    required this.palette,
  });

  final String slug;
  final RestaurantModel restaurant;
  final TenantPalette palette;

  @override
  State<AdminDrawer> createState() => _AdminDrawerState();
}

class _AdminDrawerState extends State<AdminDrawer> {
  final AdminOrderRepository _orderRepository = AdminOrderRepository();

  late Stream<List<DeliveryOrder>> _pendingStream;

  @override
  void initState() {
    super.initState();
    _pendingStream = _orderRepository.watchPendingOrders(
      restaurantId: widget.restaurant.id,
      slug: widget.slug,
    );
  }

  Future<void> _signOut() async {
    await context.read<AuthNotifier>().signOut();
    if (!mounted) return;
    context.go('/${widget.slug}');
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.restaurant.name.isNotEmpty
        ? widget.restaurant.name
        : PrinterConfig.restaurantDisplayName;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Drawer(
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
        ),
        child: SafeArea(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AdminPanelColors.loginGradient,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DrawerHeader(displayName: displayName),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                    children: [
                      const _SectionLabel(title: 'العمليات اليومية'),
                      StreamBuilder<List<DeliveryOrder>>(
                        stream: _pendingStream,
                        builder: (context, snapshot) {
                          final count = snapshot.data?.length ?? 0;

                          return _AdminTile(
                            icon: Icons.notifications_active_rounded,
                            title: 'الطلبات المعلقة',
                            subtitle: count == 0
                                ? 'لا توجد طلبات جديدة — بث مباشر'
                                : '$count طلب بانتظار القبول',
                            badge: count > 0 ? '$count' : null,
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/${widget.slug}/admin/orders');
                            },
                          );
                        },
                      ),
                      if (!kIsWeb && Platform.isWindows)
                        _AdminTile(
                          icon: Icons.print_outlined,
                          title: 'إعدادات الطباعة',
                          subtitle: 'Generic / Text Only — RAW spooler',
                          onTap: () {
                            Navigator.pop(context);
                            context.push(
                              '/${widget.slug}/admin/settings/printer',
                            );
                          },
                        ),
                      const SizedBox(height: 8),
                      const _SectionLabel(title: 'إدارة المطعم'),
                      _AdminTile(
                        icon: Icons.restaurant_menu_rounded,
                        title: 'المنتجات',
                        subtitle: 'عرض، إضافة، وتعديل الوجبات',
                        onTap: () {
                          Navigator.pop(context);
                          context.push(
                            '/${widget.slug}/admin/products/manage',
                          );
                        },
                      ),
                      _AdminTile(
                        icon: Icons.view_carousel_rounded,
                        title: 'البانرات',
                        subtitle: 'صور ترويجية دوّارة في المنيو',
                        onTap: () {
                          Navigator.pop(context);
                          context.push(
                            '/${widget.slug}/admin/banners/manage',
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      const _SectionLabel(title: 'التقارير'),
                      _AdminTile(
                        icon: Icons.summarize_rounded,
                        title: 'تقارير الإغلاق',
                        subtitle: 'مبيعات اليوم وطباعة التقرير',
                        onTap: () {
                          Navigator.pop(context);
                          context.push(
                            '/${widget.slug}/admin/reports/closing',
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 4, 14, 0),
                  child: _SectionLabel(title: 'النظام'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    children: [
                      _AdminTile(
                        icon: Icons.info_outline_rounded,
                        title: 'حول النظام',
                        subtitle: 'Snack Burger — أنظمة المهاب',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/${widget.slug}/admin/about');
                        },
                      ),
                      _AdminTile(
                        icon: Icons.logout_rounded,
                        title: 'تسجيل الخروج',
                        subtitle: 'الخروج من لوحة الإدارة',
                        onTap: () {
                          Navigator.pop(context);
                          unawaited(_signOut());
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/menu_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.restaurant_rounded,
                    color: AdminPanelColors.charcoal.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'لوحة التحكم',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AdminPanelColors.gold,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayName,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AdminPanelColors.textLight,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              height: 3,
              width: 56,
              decoration: BoxDecoration(
                color: AdminPanelColors.gold,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
      child: Text(
        title,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: AdminPanelColors.gold,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AdminPanelColors.gold.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AdminPanelColors.charcoalLight
                          .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: AdminPanelColors.gold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: AdminPanelColors.gold,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AdminPanelColors.textLight,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AdminPanelColors.textMuted
                                .withValues(alpha: 0.92),
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AdminPanelColors.gold,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: AdminPanelColors.charcoal,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 22,
                      color: AdminPanelColors.gold.withValues(alpha: 0.75),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
