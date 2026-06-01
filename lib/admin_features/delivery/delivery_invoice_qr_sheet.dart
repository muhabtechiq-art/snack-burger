import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/tenant_palette.dart';
import '../../../models/delivery_order_model.dart';

/// فاتورة توصيل مع QR Code يُولَّد محلياً على الجهاز.
class DeliveryInvoiceQrSheet extends StatelessWidget {
  const DeliveryInvoiceQrSheet({
    super.key,
    required this.order,
    required this.palette,
  });

  final DeliveryOrder order;
  final TenantPalette palette;

  static Future<void> show({
    required BuildContext context,
    required DeliveryOrder order,
    required TenantPalette palette,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DeliveryInvoiceQrSheet(order: order, palette: palette),
    );
  }

  Future<void> _openInMaps(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح خرائط Google')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapsUrl = order.googleMapsUrl;
    final hasCoords = mapsUrl != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                'فاتورة التوصيل',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: palette.primary,
                    ),
              ),
              const SizedBox(height: 16),
              _InfoLine(label: 'الزبون', value: order.customerName),
              _InfoLine(label: 'الهاتف', value: order.customerPhone),
              _InfoLine(label: 'العنوان', value: order.address),
              if (order.locationCoordinates != null)
                _InfoLine(label: 'GPS', value: order.locationCoordinates!),
              const SizedBox(height: 16),
              if (hasCoords) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: palette.primary.withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: mapsUrl,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: palette.primary,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: palette.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'امسح الرمز لفتح موقع التوصيل في Google Maps',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.primary.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _openInMaps(context, Uri.parse(mapsUrl)),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('فتح في Google Maps'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surfaceTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'لا تتوفر إحداثيات GPS لهذا الطلب.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.primary.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        textAlign: TextAlign.right,
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
