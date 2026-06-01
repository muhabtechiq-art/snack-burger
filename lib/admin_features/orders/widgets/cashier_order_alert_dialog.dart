import 'package:flutter/material.dart';

import '../../../core/theme/tenant_palette.dart';
import '../../../models/delivery_order_model.dart';
import '../../delivery/delivery_invoice_qr_sheet.dart';
import 'order_item_receipt_lines.dart';

/// نافذة تنبيه طلب جديد للكاشير.
class CashierOrderAlertDialog extends StatelessWidget {
  const CashierOrderAlertDialog({
    super.key,
    required this.order,
    required this.palette,
    required this.onAccept,
    required this.onReject,
    this.isProcessing = false,
  });

  final DeliveryOrder order;
  final TenantPalette palette;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final maxScrollHeight = MediaQuery.sizeOf(context).height * 0.55;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: palette.accent),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'طلب جديد!',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxScrollHeight),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _InfoRow(label: 'الزبون', value: order.customerName),
                      _InfoRow(label: 'الهاتف', value: order.customerPhone),
                      _InfoRow(label: 'العنوان', value: order.address),
                      if (order.googleMapsUrl != null)
                        _InfoRow(
                          label: 'الموقع',
                          value: 'متاح — امسح QR لفتح Google Maps',
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => DeliveryInvoiceQrSheet.show(
                          context: context,
                          order: order,
                          palette: palette,
                        ),
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('عرض فاتورة التوصيل'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: palette.primary.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isProcessing ? null : onReject,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('رفض الطلب'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isProcessing ? null : onAccept,
                      icon: isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: Text(isProcessing ? 'جاري...' : 'قبول الطلب'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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
