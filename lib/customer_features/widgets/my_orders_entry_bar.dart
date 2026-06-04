import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tenant_palette.dart';

/// شريط دخول «طلباتي» — يظهر بعد إرسال أول طلب.
class MyOrdersEntryBar extends StatelessWidget {
  const MyOrdersEntryBar({
    super.key,
    required this.slug,
    required this.palette,
  });

  final String slug;
  final TenantPalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.pushNamed(
          'my-orders',
          pathParameters: {'slug': slug},
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                palette.primary.withValues(alpha: 0.95),
                palette.primary.withValues(alpha: 0.82),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Icon(Icons.chevron_left_rounded, color: palette.onPrimary),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'طلباتي',
                      style: TextStyle(
                        color: palette.onPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'عرض كل طلباتك',
                      style: TextStyle(
                        color: palette.onPrimary.withValues(alpha: 0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: palette.onPrimary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
