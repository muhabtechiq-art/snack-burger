import 'package:flutter/material.dart';

import '../../core/theme/tenant_palette.dart';

/// اختيار عند اختلاف الموقع الجديد عن المحفوظ بأكثر من 100م.
enum FarFromSavedChoice { orderOnly, updateSaved }

class LocationFarFromSavedDialog extends StatelessWidget {
  const LocationFarFromSavedDialog({
    super.key,
    required this.palette,
    required this.distanceMeters,
  });

  final TenantPalette palette;
  final double distanceMeters;

  static Future<FarFromSavedChoice?> show({
    required BuildContext context,
    required TenantPalette palette,
    required double distanceMeters,
  }) {
    return showDialog<FarFromSavedChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LocationFarFromSavedDialog(
        palette: palette,
        distanceMeters: distanceMeters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distanceLabel = distanceMeters.toStringAsFixed(0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'موقع مختلف عن المحفوظ',
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
              'هذا الموقع يبعد نحو $distanceLabel متر عن موقعك المحفوظ.\n'
              'هل تريد استخدامه لهذه الطلبية فقط أم تحديث موقعك المحفوظ؟',
              textAlign: TextAlign.right,
              style: const TextStyle(height: 1.55, fontSize: 15),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(FarFromSavedChoice.orderOnly),
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
              ),
              child: const Text(
                'لهذه الطلبية فقط',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pop(FarFromSavedChoice.updateSaved),
              child: Text(
                'تحديث موقعي المحفوظ',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
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
