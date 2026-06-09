import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/utils/safe_execute.dart';
import 'product_image_preview.dart';

/// اختيار صورة وجبة من المعرض مع معاينة فورية (Web/Mobile).
class ProductImagePickerField extends StatelessWidget {
  const ProductImagePickerField({
    super.key,
    required this.previewBytes,
    required this.existingImageUrl,
    required this.onPickPressed,
    this.onClear,
    this.onExistingImageFailed,
    this.isLoading = false,
    this.loadingLabel,
  });

  final Uint8List? previewBytes;
  final String? existingImageUrl;
  final VoidCallback onPickPressed;
  final VoidCallback? onClear;
  final VoidCallback? onExistingImageFailed;
  final bool isLoading;
  final String? loadingLabel;

  bool get _hasLocalPreview => previewBytes != null && previewBytes!.isNotEmpty;

  String? get _resolvedNetworkUrl =>
      ProductImagePreview.normalizeImageUrl(existingImageUrl);

  bool get _hasPreview => _hasLocalPreview || _resolvedNetworkUrl != null;

  void _onImageTap(BuildContext context) {
    if (isLoading) return;
    if (!_hasPreview) {
      onPickPressed();
      return;
    }
    unawaited(
      safeExecuteVoid(
        () => ProductImagePreview.show(
          context,
          imageBytes: _hasLocalPreview ? previewBytes : null,
          imageUrl: _resolvedNetworkUrl,
        ),
        tag: 'productImagePreview',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_hasPreview)
                _FilledPreview(
                  previewBytes: _hasLocalPreview ? previewBytes : null,
                  existingImageUrl: _resolvedNetworkUrl,
                  onTap: isLoading ? null : () => _onImageTap(context),
                  onExistingImageFailed: onExistingImageFailed,
                )
              else
                _EmptyPreview(
                  onTap: isLoading ? null : onPickPressed,
                  scheme: scheme,
                ),
              if (isLoading)
                _LoadingOverlay(
                  scheme: scheme,
                  label: loadingLabel,
                ),
              if (_hasPreview && onClear != null && !isLoading)
                Positioned(
                  top: 10,
                  left: 10,
                  child: _ClearButton(onPressed: onClear!),
                ),
            ],
          ),
        ),
        if (_hasPreview) ...[
          const SizedBox(height: 10),
          Text(
            'اضغط على الصورة للمعاينة',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isLoading ? null : onPickPressed,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('تغيير الصورة من المعرض'),
          ),
        ],
      ],
    );
  }
}

class _FilledPreview extends StatelessWidget {
  const _FilledPreview({
    required this.previewBytes,
    required this.existingImageUrl,
    this.onTap,
    this.onExistingImageFailed,
  });

  final Uint8List? previewBytes;
  final String? existingImageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onExistingImageFailed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildImage(scheme),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(ColorScheme scheme) {
    if (previewBytes != null && previewBytes!.isNotEmpty) {
      return Image.memory(
        previewBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, error, stackTrace) {
          debugPrint(
            'ProductImagePickerField memory image failed: $error\n$stackTrace',
          );
          return _BrokenImageFallback(scheme: scheme);
        },
      );
    }

    final url = existingImageUrl;
    if (url == null || url.isEmpty) {
      return _BrokenImageFallback(scheme: scheme);
    }

    return _NetworkProductImage(
      url: url,
      scheme: scheme,
      onFailed: onExistingImageFailed,
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({
    required this.onTap,
    required this.scheme,
  });

  final VoidCallback? onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: scheme.primary.withValues(alpha: 0.04),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.22),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      scheme.primary.withValues(alpha: 0.12),
                      scheme.secondary.withValues(alpha: 0.28),
                    ],
                  ),
                  border: Border.all(
                    color: scheme.secondary.withValues(alpha: 0.55),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 36,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'اضغط لاختيار صورة الوجبة من المعرض',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'JPEG أو PNG — معاينة فورية قبل الرفع',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({
    required this.scheme,
    this.label,
  });

  final ColorScheme scheme;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: scheme.surface.withValues(alpha: 0.72),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: scheme.primary,
                ),
              ),
              if (label != null && label!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    label!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade600,
      elevation: 4,
      shadowColor: Colors.orange.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _BrokenImageFallback extends StatelessWidget {
  const _BrokenImageFallback({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: scheme.primary.withValues(alpha: 0.5),
          size: 48,
        ),
      ),
    );
  }
}

class _NetworkProductImage extends StatefulWidget {
  const _NetworkProductImage({
    required this.url,
    required this.scheme,
    this.onFailed,
  });

  final String url;
  final ColorScheme scheme;
  final VoidCallback? onFailed;

  @override
  State<_NetworkProductImage> createState() => _NetworkProductImageState();
}

class _NetworkProductImageState extends State<_NetworkProductImage> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _BrokenImageFallback(scheme: widget.scheme);
    }

    return Image.network(
      widget.url,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            color: widget.scheme.primary,
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded /
                    progress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (_, error, stackTrace) {
        debugPrint(
          'ProductImagePickerField network image failed: ${widget.url}\n'
          '$error\n$stackTrace',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _failed) return;
          setState(() => _failed = true);
          widget.onFailed?.call();
        });
        return _BrokenImageFallback(scheme: widget.scheme);
      },
    );
  }
}
