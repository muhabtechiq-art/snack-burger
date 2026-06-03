import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/tenant_palette.dart';
import '../../../models/delivery_order_model.dart';
import '../../../models/delivery_order_status.dart';
import '../../../services/order_invoice_printer.dart';
import '../data/admin_repositories.dart';
import 'widgets/cashier_order_alert_dialog.dart';

/// قبول/رفض/طباعة الطلبات المعلقة — منطق إداري فقط.
class PendingOrderActions {
  PendingOrderActions({AdminOrderRepository? orderRepository})
      : _orderRepository = orderRepository ?? AdminOrderRepository();

  final AdminOrderRepository _orderRepository;

  Future<void> rejectOrder({
    required BuildContext context,
    required DeliveryOrder order,
    VoidCallback? onOrderRemovedFromPending,
  }) async {
    await _orderRepository.updateOrderStatus(
      orderId: order.id,
      status: DeliveryOrderStatus.rejected,
    );
    onOrderRemovedFromPending?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض الطلب')),
      );
    }
  }

  Future<void> acceptOrder({
    required BuildContext context,
    required DeliveryOrder order,
  }) async {
    await _orderRepository.updateOrderStatus(
      orderId: order.id,
      status: DeliveryOrderStatus.accepted,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قبول الطلب')),
      );
    }

    unawaited(_printSilently(order));
  }

  Future<void> _printSilently(DeliveryOrder order) async {
    try {
      await printOrderInvoice(order);
    } catch (e, st) {
      debugPrint('PendingOrderActions silent print: $e\n$st');
    }
  }

  Future<void> showOrderDialog({
    required BuildContext context,
    required DeliveryOrder order,
    required TenantPalette palette,
    VoidCallback? onOrderRemovedFromPending,
    VoidCallback? onOrderAcceptFailed,
  }) async {
    final actionsEnabled = order.isPending;

    await showDialog<void>(
      context: context,
      barrierDismissible: !actionsEnabled,
      builder: (dialogContext) {
        var isProcessing = false;

        void closeDialog() {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleReject() async {
              if (isProcessing || !order.isPending) return;
              setDialogState(() => isProcessing = true);
              try {
                await rejectOrder(
                  context: dialogContext,
                  order: order,
                  onOrderRemovedFromPending: onOrderRemovedFromPending,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('تعذّر رفض الطلب: $e')),
                  );
                }
                if (context.mounted) {
                  setDialogState(() => isProcessing = false);
                }
              }
            }

            Future<void> handleAccept() async {
              if (isProcessing || !order.isPending) return;
              setDialogState(() => isProcessing = true);
              onOrderRemovedFromPending?.call();
              try {
                await acceptOrder(
                  context: dialogContext,
                  order: order,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (e) {
                onOrderAcceptFailed?.call();
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('تعذّر قبول الطلب: $e')),
                  );
                }
                if (context.mounted) {
                  setDialogState(() => isProcessing = false);
                }
              }
            }

            return CashierOrderAlertDialog(
              order: order,
              palette: palette,
              isProcessing: isProcessing,
              showActions: true,
              actionsEnabled: actionsEnabled,
              onClose: closeDialog,
              onReject: handleReject,
              onAccept: handleAccept,
            );
          },
        );
      },
    );
  }
}
