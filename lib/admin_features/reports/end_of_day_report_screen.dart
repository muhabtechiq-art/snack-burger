import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/end_of_day_report_model.dart';
import '../../services/receipt_escpos_printer.dart';
import '../../state/active_restaurant_notifier.dart';
import '../data/admin_repositories.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';

/// تقرير إغلاق اليوم — مبيعات وطلبات اليوم من Supabase.
class EndOfDayReportScreen extends StatefulWidget {
  const EndOfDayReportScreen({super.key, required this.slug});

  final String slug;

  @override
  State<EndOfDayReportScreen> createState() => _EndOfDayReportScreenState();
}

class _EndOfDayReportScreenState extends State<EndOfDayReportScreen> {
  final AdminOrderRepository _orderRepository = AdminOrderRepository();

  EndOfDayReport? _report;
  bool _loading = true;
  bool _printing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReport());
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final tenant = context.read<ActiveRestaurantNotifier>();
    final restaurant = tenant.restaurant;
    if (restaurant == null) {
      await tenant.resolveSlug(widget.slug);
    }

    if (!mounted) return;
    final resolved = context.read<ActiveRestaurantNotifier>().restaurant;
    if (resolved == null) {
      setState(() {
        _loading = false;
        _error = 'المطعم غير متوفر';
      });
      return;
    }

    try {
      final report = await _orderRepository.fetchTodayClosingReport(
        restaurantId: resolved.id,
        slug: widget.slug,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('[EndOfDayReportScreen] _loadReport: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _printReport() async {
    final report = _report;
    if (report == null) return;

    if (kIsWeb || !Platform.isWindows) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('طباعة التقرير متاحة على Windows فقط حالياً.'),
        ),
      );
      return;
    }

    setState(() => _printing = true);
    try {
      await ReceiptEscPosPrinter.printEndOfDayReport(report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال تقرير الإغلاق للطابعة')),
      );
    } catch (e, stack) {
      debugPrint('[EndOfDayReportScreen] _printReport: $e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّرت الطباعة: $e')),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  String _formatReportDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      slug: widget.slug,
      title: 'تقارير الإغلاق',
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: _loading ? null : _loadReport,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AdminPanelColors.gold),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AdminPanelColors.textMuted),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadReport,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final report = _report!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'تقرير يوم ${_formatReportDate(report.reportDate)}',
          style: const TextStyle(
            color: AdminPanelColors.gold,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'يشمل الطلبات المقبولة وقيد التوصيل والمُسلّمة فقط.',
          style: TextStyle(
            color: AdminPanelColors.textMuted.withValues(alpha: 0.95),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        _StatCard(
          icon: Icons.receipt_long_rounded,
          label: 'عدد الطلبات',
          value: '${report.orderCount}',
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.payments_rounded,
          label: 'إجمالي المبيعات',
          value: '${report.totalSales.toStringAsFixed(0)} د.ع',
        ),
        const SizedBox(height: 24),
        const Text(
          'المنتجات الأكثر طلباً',
          style: TextStyle(
            color: AdminPanelColors.gold,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        if (report.topProducts.isEmpty)
          Text(
            'لا توجد مبيعات مسجّلة لهذا اليوم.',
            style: TextStyle(color: AdminPanelColors.textMuted.withValues(alpha: 0.9)),
          )
        else
          ...report.topProducts.map(
            (stat) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TopProductRow(stat: stat),
            ),
          ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _printing ? null : _printReport,
          style: FilledButton.styleFrom(
            backgroundColor: AdminPanelColors.gold,
            foregroundColor: AdminPanelColors.charcoal,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: _printing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.print_rounded),
          label: const Text(
            'طباعة تقرير الإغلاق',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminPanelColors.charcoalLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AdminPanelColors.gold.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AdminPanelColors.gold, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AdminPanelColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AdminPanelColors.textLight,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
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

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({required this.stat});

  final TopProductStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AdminPanelColors.charcoalLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AdminPanelColors.gold.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              stat.name,
              style: const TextStyle(
                color: AdminPanelColors.textLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            'x${stat.quantity}',
            style: const TextStyle(
              color: AdminPanelColors.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
