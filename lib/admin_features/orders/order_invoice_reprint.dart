import 'package:flutter/material.dart';

import '../../core/theme/tenant_palette.dart';
import '../../models/delivery_order_model.dart';
import '../../services/order_invoice_printer.dart';

/// يعيد طباعة فاتورة الطلب باستخدام [printOrderInvoice] الحالية.
Future<bool> reprintOrderInvoice({
  required BuildContext context,
  required DeliveryOrder order,
}) async {
  debugPrint('[QA][Reprint] reprint requested orderId=${order.id}');

  final ok = await printOrderInvoice(order);

  if (!context.mounted) return ok;

  if (ok) {
    debugPrint('[QA][Reprint] success');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال الفاتورة للطباعة')),
    );
  } else {
    debugPrint('[QA][Reprint] failed error=printOrderInvoice returned false');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر الطباعة، تحقق من الطابعة')),
    );
  }

  return ok;
}

/// زر إعادة طباعة الفاتورة — للاستخدام داخل نوافذ تفاصيل الطلب.
class ReprintInvoiceButton extends StatefulWidget {
  const ReprintInvoiceButton({
    super.key,
    required this.order,
    required this.palette,
  });

  final DeliveryOrder order;
  final TenantPalette palette;

  @override
  State<ReprintInvoiceButton> createState() => _ReprintInvoiceButtonState();
}

class _ReprintInvoiceButtonState extends State<ReprintInvoiceButton> {
  bool _busy = false;

  Future<void> _handleReprint() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await reprintOrderInvoice(context: context, order: widget.order);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _handleReprint,
        icon: _busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.palette.primary,
                ),
              )
            : Icon(Icons.print_rounded, color: widget.palette.primary),
        label: Text(
          _busy ? 'جاري الإرسال...' : 'إعادة طباعة الفاتورة',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: widget.palette.primary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: widget.palette.primary.withValues(alpha: 0.65)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
