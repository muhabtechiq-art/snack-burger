import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tenant_palette.dart';

/// تأكيد نجاح الطلب — يبقي الزبون على المنيو ما لم يختار «عرض طلبي».
class OrderConfirmationDialog extends StatelessWidget {
  const OrderConfirmationDialog({
    super.key,
    required this.palette,
    required this.slug,
  });

  final TenantPalette palette;
  final String slug;

  static Future<void> show({
    required BuildContext context,
    required TenantPalette palette,
    required String slug,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => OrderConfirmationDialog(
        palette: palette,
        slug: slug,
      ),
    );
  }

  static const _message =
      'نتمنى لك وجبة شهية! طلبك قيد التجهيز وسيصلك قريباً.';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: palette.primary, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تم إرسال طلبك!',
                style: TextStyle(
                  color: palette.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تم إرسال طلبك بنجاح، يرجى انتظار قبول المطعم.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: palette.primary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pushNamed(
                'my-orders',
                pathParameters: {'slug': slug},
              );
            },
            child: Text(
              'عرض طلبي',
              style: TextStyle(
                color: palette.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
            ),
            child: const Text(
              'متابعة التسوق',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
