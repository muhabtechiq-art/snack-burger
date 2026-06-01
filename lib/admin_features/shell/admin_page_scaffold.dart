import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_notifier.dart';
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
    this.actions,
    this.floatingActionButton,
  });

  final String slug;
  final String title;
  final Widget body;
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

  Future<void> _signOut() async {
    await context.read<AuthNotifier>().signOut();
    if (!mounted) return;
    context.go('/${widget.slug}');
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
              title: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              actions: [
                ...?widget.actions,
                IconButton(
                  tooltip: 'تسجيل الخروج',
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
            floatingActionButton: widget.floatingActionButton,
            body: widget.body,
          );
        },
      ),
    );
  }
}
