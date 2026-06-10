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
    final displayName =
        widget.restaurant.name.isNotEmpty
            ? widget.restaurant.name
            : PrinterConfig.restaurantDisplayName;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Drawer(
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(18)),
        ),
        child: SafeArea(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AdminPanelColors.panelGradient,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        color: AdminPanelColors.gold,
                        size: 36,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لوحة التحكم',
                        style: TextStyle(
                          color: AdminPanelColors.gold,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: AdminPanelColors.textLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 2,
                        width: 64,
                        decoration: BoxDecoration(
                          color: AdminPanelColors.gold,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                    if (!kIsWeb && Platform.isWindows)
                      _AdminTile(
                        icon: Icons.print_outlined,
                        title: 'إعدادات الطابعة',
                        subtitle: 'Generic / Text Only — RAW spooler',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/${widget.slug}/admin/settings/printer');
                        },
                      ),
                    _SectionLabel(title: 'إشعارات الطلبات المعلقة'),
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
                    Divider(
                      color: Colors.white.withValues(alpha: 0.2),
                      height: 24,
                      indent: 20,
                      endIndent: 20,
                    ),
                    _SectionLabel(title: 'التقارير'),
                    _AdminTile(
                      icon: Icons.summarize_rounded,
                      title: 'تقارير الإغلاق',
                      subtitle: 'مبيعات اليوم وطباعة التقرير',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/${widget.slug}/admin/reports/closing');
                      },
                    ),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.2),
                      height: 24,
                      indent: 20,
                      endIndent: 20,
                    ),
                    _SectionLabel(title: 'إدارة القائمة'),
                    _AdminTile(
                      icon: Icons.restaurant_menu_rounded,
                      title: 'إدارة المنتجات',
                      subtitle: 'عرض، إضافة، وتعديل الوجبات',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/${widget.slug}/admin/products/manage');
                      },
                    ),
                    _AdminTile(
                      icon: Icons.view_carousel_rounded,
                      title: 'بانرات المنيو',
                      subtitle: 'صور ترويجية دوّارة في المنيو',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/${widget.slug}/admin/banners/manage');
                      },
                    ),
                    _AdminTile(
                      icon: Icons.home_rounded,
                      title: 'الرئيسية',
                      subtitle: 'لوحة التحكم',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/${widget.slug}/admin');
                      },
                    ),
                    ],
                  ),
                ),
                Divider(
                  color: Colors.white.withValues(alpha: 0.2),
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_signOut());
                  },
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Icon(
                    Icons.logout_rounded,
                    color: AdminPanelColors.gold,
                  ),
                  title: Text(
                    'تسجيل خروج',
                    style: TextStyle(
                      color: AdminPanelColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'وضع الإدارة — الزبائن لا يرون هذه القائمة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AdminPanelColors.textMuted.withValues(alpha: 0.95),
                      fontSize: 12,
                    ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        title,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: AdminPanelColors.goldMuted,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 0.3,
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
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AdminPanelColors.gold.withValues(alpha: 0.45),
          ),
        ),
        child: Icon(icon, color: AdminPanelColors.gold, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AdminPanelColors.textLight,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AdminPanelColors.textMuted, fontSize: 12),
      ),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            )
          : Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: AdminPanelColors.gold.withValues(alpha: 0.7),
            ),
    );
  }
}
