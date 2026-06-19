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
import '../../../state/business_day_notifier.dart';
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
  String? _expandedGroup;

  Future<void> _signOut() async {
    await context.read<AuthNotifier>().signOut();
    if (!mounted) return;
    context.go('/${widget.slug}');
  }

  void _toggleGroup(String groupId) {
    setState(() {
      _expandedGroup = _expandedGroup == groupId ? null : groupId;
    });
  }

  void _navigate(String path) {
    Navigator.pop(context);
    context.push(path);
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
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    children: [
                      Consumer<BusinessDayNotifier>(
                        builder: (context, businessDay, _) {
                          final openDayId = businessDay.openDay?.id;
                          if (openDayId == null) {
                            return _AdminTile(
                              icon: Icons.receipt_long_rounded,
                              title: 'الطلبات',
                              subtitle: 'لا يوجد يوم عمل مفتوح',
                              onTap: () =>
                                  _navigate('/${widget.slug}/admin/orders'),
                            );
                          }

                          return StreamBuilder<List<DeliveryOrder>>(
                            stream: _orderRepository
                                .watchPendingOrdersForBusinessDay(
                              businessDayId: openDayId,
                            ),
                            builder: (context, snapshot) {
                              final count = snapshot.data?.length ?? 0;

                              return _AdminTile(
                                icon: Icons.receipt_long_rounded,
                                title: 'الطلبات',
                                subtitle: count == 0
                                    ? 'لا توجد طلبات جديدة — بث مباشر'
                                    : '$count طلب بانتظار القبول',
                                badge: count > 0 ? '$count' : null,
                                onTap: () =>
                                    _navigate('/${widget.slug}/admin/orders'),
                              );
                            },
                          );
                        },
                      ),
                      _AdminTile(
                        icon: Icons.schedule_rounded,
                        title: 'يوم العمل',
                        subtitle: 'فتح/إغلاق يوم العمل يدوياً',
                        onTap: () => _navigate(
                          '/${widget.slug}/admin/settings/business-day',
                        ),
                      ),
                      _AdminExpandableGroup(
                        groupId: 'content',
                        expandedGroup: _expandedGroup,
                        onToggle: _toggleGroup,
                        icon: Icons.dashboard_customize_rounded,
                        title: 'المحتوى',
                        subtitle: 'المنتجات، البانرات، وصوت اليوم',
                        children: [
                          _AdminSubItem(
                            icon: Icons.restaurant_menu_rounded,
                            title: 'المنتجات',
                            subtitle: 'عرض، إضافة، وتعديل الوجبات',
                            onTap: () => _navigate(
                              '/${widget.slug}/admin/products/manage',
                            ),
                          ),
                          _AdminSubItem(
                            icon: Icons.view_carousel_rounded,
                            title: 'البانرات',
                            subtitle: 'صور ترويجية دوّارة في المنيو',
                            onTap: () => _navigate(
                              '/${widget.slug}/admin/banners/manage',
                            ),
                          ),
                          _AdminSubItem(
                            icon: Icons.volume_up_rounded,
                            title: 'صوت اليوم',
                            subtitle: 'ترحيب أو إعلان صوتي اختياري للزبائن',
                            onTap: () => _navigate(
                              '/${widget.slug}/admin/settings/daily-sound',
                            ),
                          ),
                        ],
                      ),
                      _AdminTile(
                        icon: Icons.summarize_rounded,
                        title: 'التقارير',
                        subtitle: 'تقارير الإغلاق والمبيعات',
                        onTap: () => _navigate(
                          '/${widget.slug}/admin/reports/closing',
                        ),
                      ),
                      _AdminExpandableGroup(
                        groupId: 'system',
                        expandedGroup: _expandedGroup,
                        onToggle: _toggleGroup,
                        icon: Icons.settings_rounded,
                        title: 'النظام',
                        subtitle: 'الصيانة ومعلومات النظام',
                        children: [
                          _AdminSubItem(
                            icon: Icons.construction_rounded,
                            title: 'وضع الصيانة',
                            subtitle: 'إيقاف استقبال طلبات الزبائن مؤقتاً',
                            onTap: () => _navigate(
                              '/${widget.slug}/admin/settings/maintenance',
                            ),
                          ),
                          _AdminSubItem(
                            icon: Icons.info_outline_rounded,
                            title: 'حول النظام',
                            subtitle: 'Snack Burger — أنظمة المهاب',
                            onTap: () => _navigate('/${widget.slug}/admin/about'),
                          ),
                          if (!kIsWeb && Platform.isWindows)
                            _AdminSubItem(
                              icon: Icons.print_outlined,
                              title: 'إعدادات الطباعة',
                              subtitle: 'Generic / Text Only — RAW spooler',
                              onTap: () => _navigate(
                                '/${widget.slug}/admin/settings/printer',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: _AdminTile(
                    icon: Icons.logout_rounded,
                    title: 'تسجيل الخروج',
                    subtitle: 'الخروج من لوحة الإدارة',
                    onTap: () {
                      Navigator.pop(context);
                      unawaited(_signOut());
                    },
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

class _AdminSubItem {
  const _AdminSubItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _AdminExpandableGroup extends StatelessWidget {
  const _AdminExpandableGroup({
    required this.groupId,
    required this.expandedGroup,
    required this.onToggle,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String groupId;
  final String? expandedGroup;
  final ValueChanged<String> onToggle;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<_AdminSubItem> children;

  bool get _isExpanded => expandedGroup == groupId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: _isExpanded ? 0.14 : 0.1),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => onToggle(groupId),
              splashColor: AdminPanelColors.gold.withValues(alpha: 0.12),
              highlightColor: Colors.white.withValues(alpha: 0.06),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isExpanded
                        ? AdminPanelColors.gold.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
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
                          size: 24,
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
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AdminPanelColors.textMuted
                                    .withValues(alpha: 0.92),
                                fontSize: 11.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedRotation(
                        turns: _isExpanded ? -0.25 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 26,
                          color: AdminPanelColors.gold.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      _AdminSubTile(item: children[i]),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminSubTile extends StatelessWidget {
  const _AdminSubTile({required this.item});

  final _AdminSubItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminPanelColors.charcoalLight.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        splashColor: AdminPanelColors.gold.withValues(alpha: 0.1),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: AdminPanelColors.gold.withValues(alpha: 0.9),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.title,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AdminPanelColors.textLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              AdminPanelColors.textMuted.withValues(alpha: 0.88),
                          fontSize: 10.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: AdminPanelColors.gold.withValues(alpha: 0.65),
                ),
              ],
            ),
          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
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
                      size: 24,
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
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AdminPanelColors.textMuted
                                .withValues(alpha: 0.92),
                            fontSize: 11.5,
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
