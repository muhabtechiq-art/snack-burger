import 'package:flutter/material.dart';

import '../../../models/order_model.dart';

/// سطر وجبة + قائمة إضافاتها في الفاتورة.
class OrderItemReceiptLines extends StatelessWidget {
  const OrderItemReceiptLines({
    super.key,
    required this.item,
    this.primaryColor,
    this.compact = false,
  });

  final CartItem item;
  final Color? primaryColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 14 : 15,
                ),
              ),
            ),
            Text('x${item.quantity}'),
            const SizedBox(width: 12),
            Text(
              '${item.baseLineTotal.toStringAsFixed(0)} د.ع',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        if (item.selectedAddons.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...item.selectedAddons.map(
            (addon) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '+ ${addon.name}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          color: color.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'x${addon.quantity}',
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.receiptAddonLineTotal(addon).toStringAsFixed(0)} د.ع',
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w700,
                        color: color.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
