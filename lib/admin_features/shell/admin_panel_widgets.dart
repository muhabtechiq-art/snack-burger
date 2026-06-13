import 'package:flutter/material.dart';

import 'admin_panel_colors.dart';

/// بطاقة إحصائية للوحة الإدارة — عرض فقط.
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminPanelColors.cardCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AdminPanelColors.gold.withValues(alpha: 0.55)
              : AdminPanelColors.gold.withValues(alpha: 0.22),
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            icon,
            color: highlight ? AdminPanelColors.charcoal : AdminPanelColors.gold,
            size: 26,
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AdminPanelColors.charcoal.withValues(alpha: 0.65),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AdminPanelColors.charcoal,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة محتوى كريمية — قوائم وجداول.
class AdminSurfaceCard extends StatelessWidget {
  const AdminSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AdminPanelColors.cardCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? AdminPanelColors.gold.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

/// عنوان قسم في لوحة الإدارة.
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: AdminPanelColors.gold,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AdminPanelColors.textMuted.withValues(alpha: 0.95),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
