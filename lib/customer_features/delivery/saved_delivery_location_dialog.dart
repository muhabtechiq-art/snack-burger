import 'package:flutter/material.dart';

import '../../core/theme/tenant_palette.dart';
import '../../models/saved_delivery_location_model.dart';

/// نافذة منبثقة: اعتماد العنوان المحفوظ أو تغيير الموقع.
class SavedDeliveryLocationDialog extends StatelessWidget {
  const SavedDeliveryLocationDialog({
    super.key,
    required this.saved,
    required this.palette,
  });

  final SavedDeliveryLocation saved;
  final TenantPalette palette;

  /// `true` = نعم (اعتماد المحفوظ)، `false` = تغيير الموقع، `null` = إلغاء.
  static Future<bool?> show({
    required BuildContext context,
    required SavedDeliveryLocation saved,
    required TenantPalette palette,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
          'عنوان التوصيل',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: palette.primary,
          ),
        ),
        content: Text(
          'هل نعتمد عنوانك السابق: ${saved.addressLabel}؟',
          textAlign: TextAlign.right,
          style: const TextStyle(height: 1.5, fontSize: 15),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'تغيير الموقع',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: palette.primary,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
            ),
            child: const Text(
              'نعم',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
