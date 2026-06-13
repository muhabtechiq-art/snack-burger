import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tenant_palette.dart';
import '../../core/utils/safe_execute.dart';
import '../../models/delivery_order_model.dart';
import '../../models/delivery_order_status.dart';
import '../../models/end_of_day_report_model.dart';
import '../../services/receipt_escpos_printer.dart';
import '../../state/active_restaurant_notifier.dart';
import '../data/admin_repositories.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';
import '../shell/admin_panel_widgets.dart';
import 'closing_report_csv_exporter.dart';
import 'widgets/closing_order_detail_dialog.dart';

/// تقرير إغلاق اليوم — جدول تفصيلي + تصدير CSV.
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
  bool _exporting = false;
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
    final printed = await safeExecuteVoid(
      () => ReceiptEscPosPrinter.printEndOfDayReport(report),
      tag: 'printEndOfDayReport',
    );
    if (!mounted) return;
    if (printed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال تقرير الإغلاق للطابعة')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّرت الطباعة. راجع سجل الأخطاء.')),
      );
    }
    if (mounted) setState(() => _printing = false);
  }

  Future<void> _exportCsv() async {
    final report = _report;
    if (report == null) return;

    setState(() => _exporting = true);
    try {
      ClosingReportCsvExporter.downloadCsv(report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم بدء تنزيل ملف CSV')),
      );
    } catch (e, stack) {
      debugPrint('[EndOfDayReportScreen] _exportCsv: $e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _formatReportDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  String _formatOrderTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _statusLabel(String status) => switch (status.trim().toLowerCase()) {
        DeliveryOrderStatus.pending => 'معلّق',
        DeliveryOrderStatus.accepted => 'مقبول',
        DeliveryOrderStatus.preparing => 'تحضير',
        DeliveryOrderStatus.delivering => 'توصيل',
        DeliveryOrderStatus.delivered => 'مُسلّم',
        DeliveryOrderStatus.rejected => 'مرفوض',
        _ => status,
      };

  void _showOrderDetail({
    required DeliveryOrder order,
    required TenantPalette palette,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => ClosingOrderDetailDialog(
        order: order,
        palette: palette,
      ),
    );
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
    final palette = TenantPalette.fromRestaurant(
      context.read<ActiveRestaurantNotifier>().restaurant,
    );
    final averageOrder = report.orderCount > 0
        ? (report.totalSales / report.orderCount).toStringAsFixed(0)
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReportHeader(dateLabel: _formatReportDate(report.reportDate)),
              const SizedBox(height: 12),
              _ClosingSummaryGrid(
                orderCount: '${report.orderCount}',
                totalSales: '${report.totalSales.toStringAsFixed(0)} د.ع',
                averageOrder:
                    averageOrder == '—' ? '—' : '$averageOrder د.ع',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: AdminPanelColors.charcoalLight.withValues(alpha: 0.35),
                  child: TabBar(
                    labelColor: AdminPanelColors.gold,
                    unselectedLabelColor:
                        AdminPanelColors.textMuted.withValues(alpha: 0.9),
                    indicatorColor: AdminPanelColors.gold,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    tabs: [
                      Tab(text: 'الطلبات (${report.orders.length})'),
                      const Tab(text: 'ملخص المنتجات'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      report.orders.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: _ClosingEmptyBox(
                                  message:
                                      'لا توجد طلبات مسجّلة لهذا اليوم.',
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                12,
                                20,
                                8,
                              ),
                              itemCount: report.orders.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final order = report.orders[index];
                                return _ClosingOrderRow(
                                  order: order,
                                  timeLabel: _formatOrderTime(order.createdAt),
                                  statusLabel: _statusLabel(order.status),
                                  onTap: () => _showOrderDetail(
                                    order: order,
                                    palette: palette,
                                  ),
                                );
                              },
                            ),
                      report.productLines.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: _ClosingEmptyBox(
                                  message:
                                      'لا توجد مبيعات مسجّلة لهذا اليوم.',
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                12,
                                20,
                                8,
                              ),
                              itemCount: report.productLines.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                return _ProductSummaryRow(
                                  line: report.productLines[index],
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _exporting ? null : _exportCsv,
                style: FilledButton.styleFrom(
                  backgroundColor: AdminPanelColors.gold,
                  foregroundColor: AdminPanelColors.charcoal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: const Text(
                  'Export CSV',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _printing ? null : _printReport,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminPanelColors.gold,
                  backgroundColor: AdminPanelColors.charcoalLight
                      .withValues(alpha: 0.35),
                  side: BorderSide(
                    color: AdminPanelColors.gold.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تقرير اليوم',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: AdminPanelColors.textMuted.withValues(alpha: 0.95),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dateLabel,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: AdminPanelColors.gold,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'اضغط على أي طلب لعرض التفاصيل الكاملة',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: AdminPanelColors.textMuted.withValues(alpha: 0.88),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ClosingSummaryGrid extends StatelessWidget {
  const _ClosingSummaryGrid({
    required this.orderCount,
    required this.totalSales,
    required this.averageOrder,
  });

  final String orderCount;
  final String totalSales;
  final String averageOrder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _ClosingStatTile(
                icon: Icons.receipt_long_rounded,
                label: 'عدد الطلبات',
                value: orderCount,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ClosingStatTile(
                icon: Icons.payments_rounded,
                label: 'إجمالي المبيعات',
                value: totalSales,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ClosingStatTile(
          icon: Icons.analytics_rounded,
          label: 'متوسط الطلب',
          value: averageOrder,
        ),
      ],
    );
  }
}

class _ClosingStatTile extends StatelessWidget {
  const _ClosingStatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  static const _maxHeight = 85.0;

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _maxHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AdminPanelColors.cardCream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AdminPanelColors.gold.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AdminPanelColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: AdminPanelColors.charcoal, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminPanelColors.charcoal,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AdminPanelColors.charcoal.withValues(alpha: 0.58),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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

class _ClosingEmptyBox extends StatelessWidget {
  const _ClosingEmptyBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AdminPanelColors.cardCream.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AdminPanelColors.gold.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AdminPanelColors.charcoal.withValues(alpha: 0.62),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ClosingOrderRow extends StatelessWidget {
  const _ClosingOrderRow({
    required this.order,
    required this.timeLabel,
    required this.statusLabel,
    required this.onTap,
  });

  final DeliveryOrder order;
  final String timeLabel;
  final String statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            Icons.chevron_left_rounded,
            color: AdminPanelColors.charcoal.withValues(alpha: 0.35),
            size: 24,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${order.totalPrice.toStringAsFixed(0)} د.ع',
                style: const TextStyle(
                  color: AdminPanelColors.charcoal,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AdminPanelColors.gold.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
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
                  order.customerPhone,
                  style: TextStyle(
                    color: AdminPanelColors.charcoal.withValues(alpha: 0.62),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeLabel,
                  style: TextStyle(
                    color: AdminPanelColors.charcoal.withValues(alpha: 0.48),
                    fontSize: 12,
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

class _ProductSummaryRow extends StatelessWidget {
  const _ProductSummaryRow({required this.line});

  final ClosingProductLine line;

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            '${line.lineTotal.toStringAsFixed(0)} د.ع',
            style: const TextStyle(
              color: AdminPanelColors.charcoal,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                line.productName,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AdminPanelColors.charcoal,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'الكمية: ${line.quantitySold}',
                style: TextStyle(
                  color: AdminPanelColors.charcoal.withValues(alpha: 0.58),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

