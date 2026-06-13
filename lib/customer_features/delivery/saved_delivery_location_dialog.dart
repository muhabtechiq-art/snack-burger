import 'package:flutter/material.dart';

import '../../core/theme/tenant_palette.dart';
import '../../models/saved_delivery_location_model.dart';

/// خيارات الموقع المحفوظ عند إتمام الطلب.
enum SavedLocationChoice {
  useSaved,
  orderOnly,
  updateSaved,
}

/// نافذة: الموقع المحفوظ + 3 خيارات واضحة.
class SavedDeliveryLocationDialog extends StatelessWidget {
  const SavedDeliveryLocationDialog({
    super.key,
    required this.saved,
    required this.palette,
  });

  final SavedDeliveryLocation saved;
  final TenantPalette palette;

  static Future<SavedLocationChoice?> show({
    required BuildContext context,
    required SavedDeliveryLocation saved,
    required TenantPalette palette,
  }) {
    return showDialog<SavedLocationChoice>(
      context: context,
      barrierDismissible: true,
      builder: (_) => SavedDeliveryLocationDialog(
        saved: saved,
        palette: palette,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'الموقع المحفوظ',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: palette.primary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              saved.addressLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${saved.latitude.toStringAsFixed(5)}, '
              '${saved.longitude.toStringAsFixed(5)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: palette.primary.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'اختر كيف تريد استخدام موقع التوصيل:',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.primary.withValues(alpha: 0.8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(SavedLocationChoice.useSaved),
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
              ),
              child: const Text(
                'استخدام موقعي المحفوظ',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pop(SavedLocationChoice.orderOnly),
              child: Text(
                'موقع جديد — هذه الطلبية فقط',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: palette.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pop(SavedLocationChoice.updateSaved),
              child: Text(
                'تحديث موقعي المحفوظ بهذا الموقع',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
