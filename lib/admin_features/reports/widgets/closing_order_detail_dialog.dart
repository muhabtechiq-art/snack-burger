import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/tenant_palette.dart';
import '../../../models/delivery_order_model.dart';
import '../../../models/delivery_order_status.dart';
import '../../orders/order_invoice_reprint.dart';
import '../../orders/widgets/order_item_receipt_lines.dart';

/// نافذة تفاصيل طلب للأرشيف — للقراءة فقط (تقارير الإغلاق).
class ClosingOrderDetailDialog extends StatelessWidget {
  const ClosingOrderDetailDialog({
    super.key,
    required this.order,
    required this.palette,
  });

  final DeliveryOrder order;
  final TenantPalette palette;

  bool get _canReprint {
    final status = order.status.trim().toLowerCase();
    return status == DeliveryOrderStatus.accepted ||
        status == DeliveryOrderStatus.preparing ||
        status == DeliveryOrderStatus.delivering ||
        status == DeliveryOrderStatus.delivered;
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final maxHeight = screen.height * 0.85;
    const headerHeight = 52.0;
    const reprintFooterHeight = 72.0;
    final bottomPadding = _canReprint ? reprintFooterHeight : 16.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 580, maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: SizedBox(
                  height: headerHeight,
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: palette.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تفاصيل الطلب',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: palette.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'إغلاق',
                        icon: const Icon(Icons.close_rounded, size: 26),
                        color: Colors.grey.shade700,
                      ),
                    ],
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxHeight - headerHeight - bottomPadding,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InfoRow(
                        label: 'الوقت',
                        value: _formatTimestamp(order.createdAt),
                      ),
                      _InfoRow(label: 'الزبون', value: order.customerName),
                      _InfoRow(label: 'الهاتف', value: order.customerPhone),
                      _InfoRow(label: 'العنوان', value: order.address),
                      _GpsSection(order: order, palette: palette),
                      const SizedBox(height: 12),
                      Divider(color: palette.primary.withValues(alpha: 0.12)),
                      const SizedBox(height: 8),
                      Text(
                        'الوجبات',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: palette.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...order.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: OrderItemReceiptLines(
                            item: item,
                            primaryColor: palette.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${order.totalPrice.toStringAsFixed(0)} د.ع',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: palette.primary,
                              ),
                            ),
                            const Text(
                              'الإجمالي',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_canReprint)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: ReprintInvoiceButton(
                    order: order,
                    palette: palette,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date  $time';
  }
}

class _GpsSection extends StatelessWidget {
  const _GpsSection({required this.order, required this.palette});

  final DeliveryOrder order;
  final TenantPalette palette;

  @override
  Widget build(BuildContext context) {
    if (!order.hasLocation && order.locationCoordinates == null) {
      return const _InfoRow(label: 'الموقع', value: 'غير متوفر');
    }

    final lat = order.latitude;
    final lng = order.longitude;
    final coordsText = lat != null && lng != null
        ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
        : (order.locationCoordinates ?? '—');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RichText(
            textAlign: TextAlign.right,
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                const TextSpan(
                  text: 'الموقع (GPS): ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: coordsText),
              ],
            ),
          ),
          if (order.googleMapsUrl != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openMaps(order.googleMapsUrl!),
                icon: Icon(Icons.map_rounded, color: palette.primary, size: 18),
                label: Text(
                  'فتح على الخريطة',
                  style: TextStyle(
                    color: palette.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openMaps(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        textAlign: TextAlign.right,
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
