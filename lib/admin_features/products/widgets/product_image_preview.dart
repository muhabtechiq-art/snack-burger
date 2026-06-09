import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/safe_execute.dart';

/// معاينة آمنة لصورة المنتج (ذاكرة أو رابط Supabase Storage).
abstract final class ProductImagePreview {
  ProductImagePreview._();

  static const _logTag = 'ProductImagePreview';

  /// يعرض معاينة ملء الشاشة — لا يرمي استثناءً للواجهة.
  static Future<void> show(
    BuildContext context, {
    Uint8List? imageBytes,
    String? imageUrl,
  }) async {
    await safeExecuteVoid(
      () async {
        final widget = _buildPreviewWidget(
          imageBytes: imageBytes,
          imageUrl: imageUrl,
        );
        if (widget == null) {
          debugPrint('[$_logTag] no valid image — bytes or url missing');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('لا توجد صورة صالحة للمعاينة')),
            );
          }
          return;
        }

        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          barrierColor: Colors.black87,
          builder: (dialogContext) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.black,
              child: Stack(
                children: [
                  InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Center(child: widget),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      tag: _logTag,
    );
  }

  static Widget? _buildPreviewWidget({
    Uint8List? imageBytes,
    String? imageUrl,
  }) {
    if (imageBytes != null && imageBytes.isNotEmpty) {
      return Image.memory(
        imageBytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[$_logTag] memory decode failed: $error\n$stackTrace');
          return _errorPlaceholder();
        },
      );
    }

    final normalizedUrl = normalizeImageUrl(imageUrl);
    if (normalizedUrl == null) return null;

    return CachedNetworkImage(
      imageUrl: normalizedUrl,
      fit: BoxFit.contain,
      placeholder: (_, _) => const SizedBox(
        width: 48,
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, url, error) {
        debugPrint('[$_logTag] cached load failed url=$url error=$error');
        return _errorPlaceholder();
      },
    );
  }

  /// يتحقق من صحة رابط HTTP/HTTPS (بما في ذلك Supabase Storage public URL).
  static String? normalizeImageUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      debugPrint('[$_logTag] invalid scheme: $trimmed');
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      debugPrint('[$_logTag] invalid uri: $trimmed');
      return null;
    }

    return uri.toString();
  }

  static Widget _errorPlaceholder() {
    return const Icon(
      Icons.broken_image_outlined,
      size: 56,
      color: Colors.white70,
    );
  }
}
