import 'package:flutter/material.dart';

import '../../../core/theme/tenant_palette.dart';
import '../../../models/delivery_order_model.dart';
import 'order_item_receipt_lines.dart';

/// نافذة عائمة لعرض تفاصيل الطلب — قبول/رفض للمطبخ، أو عرض فقط مع زر X.
class CashierOrderAlertDialog extends StatelessWidget {
  const CashierOrderAlertDialog({
    super.key,
    required this.order,
    required this.palette,
    required this.onClose,
    required this.onAccept,
    required this.onReject,
    this.isProcessing = false,
    this.showActions = true,
    this.actionsEnabled = true,
  });

  final DeliveryOrder order;
  final TenantPalette palette;
  final VoidCallback onClose;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool isProcessing;
  /// يعرض شريط الأزرار في أسفل النافذة.
  final bool showActions;
  /// يفعّل قبول/رفض — يُعطَّل للطلبات التي ليست «معلّقة».
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final maxHeight = screen.height * 0.82;
    const headerHeight = 52.0;
    const footerHeight = 80.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: maxHeight,
          ),
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
                          actionsEnabled ? 'طلب جديد' : 'تفاصيل الطلب',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: palette.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: isProcessing ? null : onClose,
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
                  maxHeight: maxHeight -
                      headerHeight -
                      (showActions ? footerHeight : 16),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InfoRow(label: 'الزبون', value: order.customerName),
                      _InfoRow(label: 'الهاتف', value: order.customerPhone),
                      _InfoRow(label: 'العنوان', value: order.address),
                      if (order.googleMapsUrl != null)
                        const _InfoRow(
                          label: 'الموقع',
                          value: 'إحداثيات GPS متوفرة',
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
              if (showActions)
                _OrderActionFooter(
                  palette: palette,
                  isProcessing: isProcessing,
                  actionsEnabled: actionsEnabled,
                  onReject: onReject,
                  onAccept: onAccept,
                )
              else
                const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderActionFooter extends StatelessWidget {
  const _OrderActionFooter({
    required this.palette,
    required this.isProcessing,
    required this.actionsEnabled,
    required this.onReject,
    required this.onAccept,
  });

  final TenantPalette palette;
  final bool isProcessing;
  final bool actionsEnabled;
  final VoidCallback onReject;
  final VoidCallback onAccept;

  bool get _canAct => actionsEnabled && !isProcessing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _canAct ? onReject : null,
                  icon: const Icon(Icons.cancel_rounded, size: 22),
                  label: const Text(
                    'رفض الطلب',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red.shade200,
                    disabledForegroundColor: Colors.white70,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _canAct ? onAccept : null,
                  icon: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 22),
                  label: Text(
                    isProcessing ? 'جاري...' : 'قبول الطلب',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.green.shade200,
                    disabledForegroundColor: Colors.white70,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
