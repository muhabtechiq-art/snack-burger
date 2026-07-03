import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tenant_palette.dart';
import '../../core/utils/safe_execute.dart';
import '../../models/delivery_order_model.dart';
import '../../services/receipt_escpos_printer.dart';
import '../../state/active_restaurant_notifier.dart';

/// يعيد طباعة جزء من فاتورة الطلب (كاشير / مطبخ / الاثنين).
Future<bool> reprintOrderInvoice({
  required BuildContext context,
  required DeliveryOrder order,
  OrderReceiptPrintScope scope = OrderReceiptPrintScope.both,
}) async {
  debugPrint(
    '[QA][Reprint] reprint requested orderId=${order.id} scope=$scope',
  );

  final restaurantName =
      context.read<ActiveRestaurantNotifier>().restaurant?.name.trim();
  final restaurantDisplayName =
      (restaurantName != null && restaurantName.isNotEmpty)
          ? restaurantName
          : null;

  final ok = await safeExecuteVoid(
    () async {
      if (kIsWeb) {
        throw UnsupportedError('إعادة الطباعة غير متاحة على الويب');
      }
      if (!Platform.isWindows) {
        throw UnsupportedError('إعادة الطباعة متاحة على Windows فقط');
      }
      await ReceiptEscPosPrinter.printOrderReceipt(
        order,
        scope: scope,
        restaurantDisplayName: restaurantDisplayName,
      );
    },
    tag: 'reprintOrderInvoice',
  );

  if (!context.mounted) return ok;

  if (ok) {
    debugPrint('[QA][Reprint] success scope=$scope');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_successMessage(scope))),
    );
  } else {
    debugPrint('[QA][Reprint] failed scope=$scope');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر الطباعة، تحقق من الطابعة')),
    );
  }

  return ok;
}

String _successMessage(OrderReceiptPrintScope scope) {
  return switch (scope) {
    OrderReceiptPrintScope.cashierOnly => 'تم إرسال فاتورة الكاشير',
    OrderReceiptPrintScope.kitchenOnly => 'تم إرسال بون المطبخ',
    OrderReceiptPrintScope.both => 'تم إرسال الفاتورة للطباعة',
  };
}

Future<OrderReceiptPrintScope?> pickReprintScope(
  BuildContext context, {
  required TenantPalette palette,
}) {
  return showModalBottomSheet<OrderReceiptPrintScope>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'إعادة الطباعة',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: palette.primary,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.receipt_long, color: palette.primary),
                title: const Text('الاثنين'),
                subtitle: const Text('كاشير + مطبخ'),
                onTap: () => Navigator.pop(
                  sheetContext,
                  OrderReceiptPrintScope.both,
                ),
              ),
              ListTile(
                leading: Icon(Icons.point_of_sale_rounded, color: palette.primary),
                title: const Text('فاتورة الكاشير'),
                onTap: () => Navigator.pop(
                  sheetContext,
                  OrderReceiptPrintScope.cashierOnly,
                ),
              ),
              ListTile(
                leading: Icon(Icons.restaurant_rounded, color: palette.primary),
                title: const Text('بون المطبخ'),
                onTap: () => Navigator.pop(
                  sheetContext,
                  OrderReceiptPrintScope.kitchenOnly,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// زر إعادة طباعة — يفتح اختيار النطاق ثم يطبع.
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

    final scope = await pickReprintScope(
      context,
      palette: widget.palette,
    );
    if (scope == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await reprintOrderInvoice(
        context: context,
        order: widget.order,
        scope: scope,
      );
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
          _busy ? 'جاري الإرسال...' : 'إعادة طباعة',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: widget.palette.primary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: widget.palette.primary.withValues(alpha: 0.65),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
