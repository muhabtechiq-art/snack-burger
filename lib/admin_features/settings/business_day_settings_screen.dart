import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tenant_palette.dart';
import '../../core/utils/price_utils.dart';
import '../../models/business_day_order_stats.dart';
import '../../models/business_day_model.dart';
import '../../models/end_of_day_report_model.dart';
import '../../services/supabase_business_day_service.dart';
import '../../state/business_day_notifier.dart';
import '../data/admin_repositories.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';
import '../../state/active_restaurant_notifier.dart';

/// ألوان قراءة أوضح على الكروت الكريمية — من لوحة الهوية الحالية فقط.
abstract final class _BusinessDayCardColors {
  _BusinessDayCardColors._();

  static const Color title = AdminPanelColors.charcoal;
  static const Color body = SnackBurgerBrandColors.ink;
  static final Color label =
      Color.lerp(SnackBurgerBrandColors.mustard, SnackBurgerBrandColors.ink, 0.72)!;
  static const Color value = AdminPanelColors.charcoal;
  static const Color divider = AdminPanelColors.goldMuted;
  static const Color statsBackground = AdminPanelColors.cardLight;
  static const Color cardBorder = AdminPanelColors.goldMuted;
}

/// إدارة يوم العمل اليدوي — فتح/إغلاق يوم العمل.
class BusinessDaySettingsScreen extends StatefulWidget {
  const BusinessDaySettingsScreen({super.key, required this.slug});

  final String slug;

  @override
  State<BusinessDaySettingsScreen> createState() =>
      _BusinessDaySettingsScreenState();
}

class _BusinessDaySettingsScreenState extends State<BusinessDaySettingsScreen> {
  final AdminOrderRepository _orderRepository = AdminOrderRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final tenant = context.read<ActiveRestaurantNotifier>();
    if (tenant.restaurant == null) {
      await tenant.resolveSlug(widget.slug);
    }
    if (!mounted) return;
    final restaurant = context.read<ActiveRestaurantNotifier>().restaurant;
    if (restaurant == null) return;

    await context.read<BusinessDayNotifier>().ensureScope(
          restaurantId: restaurant.id,
          slug: widget.slug,
        );
  }

  Future<void> _openBusinessDay() async {
    final notifier = context.read<BusinessDayNotifier>();
    try {
      await notifier.openBusinessDay();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم بدء يوم العمل بنجاح')),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      final message = error.message ==
              SupabaseBusinessDayService.alreadyOpenCode
          ? 'يوجد يوم عمل مفتوح بالفعل'
          : 'تعذّر بدء يوم العمل';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر بدء يوم العمل. تحقق من الاتصال وحاول مرة أخرى'),
        ),
      );
    }
  }

  Future<void> _confirmCloseBusinessDay() async {
    final businessDay = context.read<BusinessDayNotifier>().openDay;
    final restaurant = context.read<ActiveRestaurantNotifier>().restaurant;
    if (businessDay == null || restaurant == null) return;

    EndOfDayReport? preview;
    try {
      preview = await _orderRepository.fetchClosingReport(
        restaurantId: restaurant.id,
        slug: widget.slug,
        businessDayId: businessDay.id,
        businessDay: businessDay,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تحميل إحصائيات اليوم')),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _CloseBusinessDayDialog(report: preview!),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<BusinessDayNotifier>().closeBusinessDay();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إغلاق يوم العمل بنجاح')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر إغلاق يوم العمل. تحقق من الاتصال وحاول مرة أخرى'),
        ),
      );
    }
  }

  String _formatOpenedTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $period';
  }

  String _formatOpenedDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      slug: widget.slug,
      title: 'يوم العمل',
      titleIcon: Icons.storefront_rounded,
      body: Consumer2<BusinessDayNotifier, ActiveRestaurantNotifier>(
        builder: (context, businessDay, tenant, _) {
          if (businessDay.isLoading || tenant.restaurant == null) {
            return const Center(
              child: CircularProgressIndicator(color: AdminPanelColors.gold),
            );
          }

          final openDay = businessDay.openDay;
          final isOpen = openDay != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isOpen)
                      _OpenBusinessDayCard(
                        openedTimeLabel: _formatOpenedTime(openDay.openedAt),
                        openedDateLabel: _formatOpenedDate(openDay.openedAt),
                        liveStats: _LiveStatsSection(
                          slug: widget.slug,
                          restaurantId: tenant.restaurant!.id,
                          businessDayId: openDay.id,
                          businessDay: openDay,
                        ),
                      )
                    else
                      const _ClosedBusinessDayCard(),
                    const SizedBox(height: 24),
                    if (isOpen)
                      _BusinessDayActionButton(
                        label: '🔴 إغلاق يوم العمل',
                        icon: Icons.lock_rounded,
                        backgroundColor: Colors.redAccent.shade200,
                        enabled: !businessDay.actionInProgress,
                        onPressed: _confirmCloseBusinessDay,
                      )
                    else
                      _BusinessDayActionButton(
                        label: '🟢 بدء يوم العمل',
                        icon: Icons.play_arrow_rounded,
                        backgroundColor: Colors.greenAccent.shade400,
                        enabled: !businessDay.actionInProgress,
                        onPressed: _openBusinessDay,
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

class _OpenBusinessDayCard extends StatelessWidget {
  const _OpenBusinessDayCard({
    required this.openedTimeLabel,
    required this.openedDateLabel,
    required this.liveStats,
  });

  final String openedTimeLabel;
  final String openedDateLabel;
  final Widget liveStats;

  @override
  Widget build(BuildContext context) {
    return _BusinessDayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BusinessDayStatusHeader(
            emoji: '🟢',
            title: 'يوم العمل مفتوح',
            accentColor: Colors.greenAccent.shade400,
          ),
          const SizedBox(height: 20),
          const _BusinessDayDivider(),
          const SizedBox(height: 20),
          _InfoRow(
            label: 'بدأ الساعة',
            value: openedTimeLabel,
            emphasizeValue: true,
          ),
          const SizedBox(height: 14),
          _InfoRow(
            label: 'التاريخ',
            value: openedDateLabel,
            emphasizeValue: true,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _BusinessDayCardColors.statsBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _BusinessDayCardColors.cardBorder,
                width: 1.5,
              ),
            ),
            child: liveStats,
          ),
        ],
      ),
    );
  }
}

class _ClosedBusinessDayCard extends StatelessWidget {
  const _ClosedBusinessDayCard();

  @override
  Widget build(BuildContext context) {
    return _BusinessDayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BusinessDayStatusHeader(
            emoji: '🔴',
            title: 'لا يوجد يوم عمل مفتوح',
            accentColor: Colors.redAccent.shade200,
          ),
          const SizedBox(height: 20),
          const _BusinessDayDivider(),
          const SizedBox(height: 20),
          Text(
            'لن يتم استقبال الطلبات حتى يتم بدء يوم العمل.',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _BusinessDayCardColors.body,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessDayStatusHeader extends StatelessWidget {
  const _BusinessDayStatusHeader({
    required this.emoji,
    required this.title,
    required this.accentColor,
  });

  final String emoji;
  final String title;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AdminPanelColors.cardLight,
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _BusinessDayCardColors.title,
              fontWeight: FontWeight.w900,
              fontSize: 23,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessDayActionButton extends StatelessWidget {
  const _BusinessDayActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 22),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 17,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: AdminPanelColors.charcoal,
        disabledBackgroundColor: AdminPanelColors.goldMuted,
        disabledForegroundColor: SnackBurgerBrandColors.ink,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _LiveStatsSection extends StatefulWidget {
  const _LiveStatsSection({
    required this.slug,
    required this.restaurantId,
    required this.businessDayId,
    required this.businessDay,
  });

  final String slug;
  final String restaurantId;
  final String businessDayId;
  final BusinessDayModel businessDay;

  @override
  State<_LiveStatsSection> createState() => _LiveStatsSectionState();
}

class _LiveStatsSectionState extends State<_LiveStatsSection> {
  final AdminOrderRepository _orderRepository = AdminOrderRepository();
  BusinessDayOrderStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stats = await _orderRepository.fetchBusinessDayOrderStats(
        businessDayId: widget.businessDayId,
        businessDay: widget.businessDay,
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AdminPanelColors.gold,
            ),
          ),
        ),
      );
    }

    final stats = _stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoRow(
          label: 'إجمالي الطلبات',
          value: '${stats?.allOrdersCount ?? 0}',
          isStat: true,
        ),
        const SizedBox(height: 14),
        _InfoRow(
          label: 'الطلبات المحتسبة',
          value: '${stats?.closingCountableOrders ?? 0}',
          isStat: true,
        ),
        const SizedBox(height: 14),
        _InfoRow(
          label: 'مبيعات اليوم',
          value: PriceUtils.formatPriceWithCurrency(
            stats?.closingCountableSales ?? 0,
          ),
          isStat: true,
        ),
      ],
    );
  }
}

class _BusinessDayCard extends StatelessWidget {
  const _BusinessDayCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminPanelColors.cardCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _BusinessDayCardColors.cardBorder,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BusinessDayDivider extends StatelessWidget {
  const _BusinessDayDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.5,
      color: _BusinessDayCardColors.divider,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.onDarkSurface = false,
    this.emphasizeValue = false,
    this.isStat = false,
  });

  final String label;
  final String value;
  final bool onDarkSurface;
  final bool emphasizeValue;
  final bool isStat;

  @override
  Widget build(BuildContext context) {
    final labelStyle = onDarkSurface
        ? const TextStyle(
            color: AdminPanelColors.textMuted,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          )
        : TextStyle(
            color: _BusinessDayCardColors.label,
            fontWeight: FontWeight.w800,
            fontSize: isStat ? 15 : 15,
          );

    final valueStyle = onDarkSurface
        ? const TextStyle(
            color: AdminPanelColors.gold,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            height: 1.2,
          )
        : TextStyle(
            color: _BusinessDayCardColors.value,
            fontWeight: FontWeight.w900,
            fontSize: emphasizeValue
                ? 24
                : isStat
                    ? 22
                    : 20,
            height: 1.15,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.right,
          style: labelStyle,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.right,
          style: valueStyle,
        ),
      ],
    );
  }
}

class _CloseBusinessDayDialog extends StatelessWidget {
  const _CloseBusinessDayDialog({required this.report});

  final EndOfDayReport report;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AdminPanelColors.charcoalLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'تأكيد إغلاق يوم العمل',
          style: TextStyle(
            color: AdminPanelColors.gold,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'هل أنت متأكد من إغلاق يوم العمل؟',
              style: TextStyle(
                color: AdminPanelColors.textLight,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            _InfoRow(
              label: 'الطلبات المحتسبة',
              value: '${report.orderCount}',
              onDarkSurface: true,
              isStat: true,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'مبيعات اليوم',
              value: PriceUtils.formatPriceWithCurrency(report.totalSales),
              onDarkSurface: true,
              isStat: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.shade200,
              foregroundColor: AdminPanelColors.charcoal,
            ),
            child: const Text('إغلاق يوم العمل'),
          ),
        ],
      ),
    );
  }
}
