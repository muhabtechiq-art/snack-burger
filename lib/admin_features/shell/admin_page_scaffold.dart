import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tenant_palette.dart';
import '../../state/active_restaurant_notifier.dart';
import 'admin_drawer.dart';
import 'admin_panel_colors.dart';

/// غلاف موحّد لصفحات الإدارة — القائمة الجانبية في كل مكان.
class AdminPageScaffold extends StatefulWidget {
  const AdminPageScaffold({
    super.key,
    required this.slug,
    required this.title,
    required this.body,
    this.titleIcon,
    this.actions,
    this.floatingActionButton,
  });

  final String slug;
  final String title;
  final Widget body;
  final IconData? titleIcon;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  State<AdminPageScaffold> createState() => _AdminPageScaffoldState();
}

class _AdminPageScaffoldState extends State<AdminPageScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ActiveRestaurantNotifier>().resolveSlug(widget.slug);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Consumer<ActiveRestaurantNotifier>(
        builder: (context, tenant, _) {
          if (tenant.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final restaurant = tenant.restaurant;
          if (restaurant == null) {
            return Scaffold(
              appBar: AppBar(title: Text(widget.title)),
              body: const Center(child: Text('المطعم غير متوفر')),
            );
          }

          final palette = TenantPalette.fromRestaurant(restaurant);

          return Scaffold(
            backgroundColor: AdminPanelColors.charcoal,
            drawer: AdminDrawer(
              slug: widget.slug,
              restaurant: restaurant,
              palette: palette,
            ),
            appBar: AppBar(
              backgroundColor: AdminPanelColors.charcoal,
              foregroundColor: AdminPanelColors.gold,
              automaticallyImplyLeading: false,
              leading: context.canPop()
                  ? IconButton(
                      tooltip: 'رجوع',
                      icon: const Icon(Icons.arrow_forward_ios_rounded),
                      onPressed: () => context.pop(),
                    )
                  : Builder(
                      builder: (context) => IconButton(
                        tooltip: 'القائمة',
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.titleIcon != null) ...[
                    Icon(widget.titleIcon, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: widget.actions,
            ),
            floatingActionButton: widget.floatingActionButton,
            body: widget.body,
          );
        },
      ),
    );
  }
}
