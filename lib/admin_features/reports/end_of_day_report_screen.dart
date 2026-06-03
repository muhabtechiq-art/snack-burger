import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tenant_palette.dart';
import '../../models/delivery_order_model.dart';
import '../../models/delivery_order_status.dart';
import '../../models/end_of_day_report_model.dart';
import '../../services/receipt_escpos_printer.dart';
import '../../state/active_restaurant_notifier.dart';
import '../data/admin_repositories.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                'اضغط على أي طلب لعرض التفاصيل الكاملة (الزبون، العنوان، GPS، الوجبات).',
                style: TextStyle(
                  color: AdminPanelColors.textMuted.withValues(alpha: 0.95),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.receipt_long_rounded,
                      label: 'عدد الطلبات',
                      value: '${report.orderCount}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.payments_rounded,
                      label: 'إجمالي المبيعات',
                      value: '${report.totalSales.toStringAsFixed(0)} د.ع',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabBar(
                  labelColor: AdminPanelColors.gold,
                  unselectedLabelColor: AdminPanelColors.textMuted,
                  indicatorColor: AdminPanelColors.gold,
                  tabs: [
                    Tab(text: 'الطلبات (${report.orders.length})'),
                    const Tab(text: 'ملخص المنتجات'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      report.orders.isEmpty
                          ? Center(
                              child: Text(
                                'لا توجد طلبات مسجّلة لهذا اليوم.',
                                style: TextStyle(
                                  color: AdminPanelColors.textMuted
                                      .withValues(alpha: 0.9),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              itemCount: report.orders.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
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
                          ? Center(
                              child: Text(
                                'لا توجد مبيعات مسجّلة لهذا اليوم.',
                                style: TextStyle(
                                  color: AdminPanelColors.textMuted
                                      .withValues(alpha: 0.9),
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: SingleChildScrollView(
                                child: _ProductSalesTable(
                                  lines: report.productLines,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _exporting ? null : _exportCsv,
                style: FilledButton.styleFrom(
                  backgroundColor: AdminPanelColors.gold,
                  foregroundColor: AdminPanelColors.charcoal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: const Text(
                  'Export to CSV',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _printing ? null : _printReport,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminPanelColors.gold,
                  side: BorderSide(
                    color: AdminPanelColors.gold.withValues(alpha: 0.45),
                  ),
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
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ],
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
    return Material(
      color: AdminPanelColors.charcoalLight,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AdminPanelColors.gold.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.chevron_left_rounded,
                color: AdminPanelColors.gold.withValues(alpha: 0.75),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    order.customerName,
                    style: const TextStyle(
                      color: AdminPanelColors.textLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.customerPhone} • ${order.items.length} وجبة',
                    style: const TextStyle(
                      color: AdminPanelColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${order.totalPrice.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(
                      color: AdminPanelColors.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$timeLabel • $statusLabel',
                    style: TextStyle(
                      color: AdminPanelColors.textMuted.withValues(alpha: 0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductSalesTable extends StatelessWidget {
  const _ProductSalesTable({required this.lines});

  final List<ClosingProductLine> lines;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(
        AdminPanelColors.charcoalLight,
      ),
      dataRowMinHeight: 44,
      headingRowHeight: 48,
      columnSpacing: 24,
      headingTextStyle: const TextStyle(
        color: AdminPanelColors.gold,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
      dataTextStyle: const TextStyle(
        color: AdminPanelColors.textLight,
        fontSize: 13,
      ),
      columns: const [
        DataColumn(label: Text('Product Name')),
        DataColumn(label: Text('Quantity Sold'), numeric: true),
        DataColumn(label: Text('Unit Price'), numeric: true),
        DataColumn(label: Text('Total'), numeric: true),
      ],
      rows: lines
          .map(
            (line) => DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Text(
                      line.productName,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                DataCell(Text('${line.quantitySold}')),
                DataCell(Text('${line.unitPrice.toStringAsFixed(0)} د.ع')),
                DataCell(Text('${line.lineTotal.toStringAsFixed(0)} د.ع')),
              ],
            ),
          )
          .toList(),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminPanelColors.charcoalLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AdminPanelColors.gold.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, color: AdminPanelColors.gold, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AdminPanelColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AdminPanelColors.textLight,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
