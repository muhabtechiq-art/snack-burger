import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/utils/image_compressor.dart';
import 'image_pick_upload_service.dart';
import 'image_upload_exception.dart';

/// نتيجة معالجة صورة المنتج.
class ProductImageProcessResult {
  const ProductImageProcessResult({
    required this.file,
    required this.previewBytes,
    required this.uploadBytes,
  });

  final XFile file;
  final Uint8List previewBytes;
  final Uint8List uploadBytes;
}

void _productImageLog(String message) {
  debugPrint('[ProductImageUpload] $message');
}

void _productImageLogError(String message, [Object? error, StackTrace? stack]) {
  debugPrint('[ProductImageUpload][ERROR] $message${error != null ? ': $error' : ''}');
  if (stack != null) {
    debugPrint(stack.toString());
  }
}

/// يعالج مسار ملف (ضغط معاينة + رفع) — يُستدعى على isolate أو main حسب المنصة.
Future<ProductImageProcessResult?> productImageProcessPathWorker(
  String path,
) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return null;

  Uint8List? uploadBytes = await ImageCompressor.compressFileForUpload(trimmed);
  Uint8List? previewBytes = uploadBytes == null || uploadBytes.isEmpty
      ? null
      : await ImageCompressor.compressFileForUpload(
          trimmed,
          minWidth: 1200,
          minHeight: 1200,
          quality: 72,
        );

  if (uploadBytes == null || uploadBytes.isEmpty) {
    return null;
  }

  return ProductImageProcessResult(
    file: XFile(trimmed),
    previewBytes: (previewBytes != null && previewBytes.isNotEmpty)
        ? previewBytes
        : uploadBytes,
    uploadBytes: uploadBytes,
  );
}

/// يعالج bytes خام — fallback عند غياب مسار الملف أو فشل الضغط من المسار.
Future<ProductImageProcessResult?> productImageProcessBytesWorker(
  Uint8List raw,
) async {
  if (raw.isEmpty) return null;

  Uint8List? uploadBytes = await ImageCompressor.compressForUpload(raw);
  Uint8List? previewBytes = uploadBytes == null || uploadBytes.isEmpty
      ? null
      : await ImageCompressor.compressForUpload(
          raw,
          minWidth: 1200,
          minHeight: 1200,
          quality: 72,
        );

  uploadBytes ??= raw;
  if (uploadBytes.isEmpty) return null;

  return ProductImageProcessResult(
    file: XFile.fromData(
      uploadBytes,
      name: 'product.jpg',
      mimeType: 'image/jpeg',
    ),
    previewBytes: (previewBytes != null && previewBytes.isNotEmpty)
        ? previewBytes
        : uploadBytes,
    uploadBytes: uploadBytes,
  );
}

/// اختيار وضغط ورفع صور المنتج.
class ProductImageUploadService {
  ProductImageUploadService({
    ImagePickUploadService? imageUploadService,
  }) : _imageUploadService = imageUploadService ?? ImagePickUploadService();

  static const Duration uploadTimeout = Duration(seconds: 30);
  static const Duration processTimeout = Duration(seconds: 30);

  /// أقصى حجم مقبول للصورة على Windows (حيث لا يتوفر ضغط داخل التطبيق).
  static const int maxWindowsImageBytes = 2 * 1024 * 1024;

  final ImagePickUploadService _imageUploadService;

  /// `compute()` على Android/iOS فقط — Desktop/Web على main isolate.
  static bool get _useComputeForImageProcessing {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Windows لا يدعم flutter_image_compress — نتجنّب استدعاءه ونتحقق من الحجم فقط.
  static bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<XFile?> pickProductImageFromGallery() async {
    _productImageLog('picking image');
    try {
      final file = await _imageUploadService.pickProductImageFromGallery();
      if (file == null) {
        _productImageLog('pick cancelled');
        return null;
      }
      _productImageLog('file selected name=${file.name}');
      return file;
    } catch (e, st) {
      _productImageLogError('pick failed', e, st);
      rethrow;
    }
  }

  /// يقرأ ويضغط الصورة للمعاينة والرفع — timeout + fallback بدون تعليق.
  Future<ProductImageProcessResult?> processPickedImage(XFile file) async {
    _productImageLog('compress start');
    try {
      final result = await _processPickedImageCore(file).timeout(
        processTimeout,
        onTimeout: () {
          _productImageLogError('compress timeout');
          return null;
        },
      );
      _productImageLog(
        'compress end preview=${result?.previewBytes.length ?? 0}B '
        'upload=${result?.uploadBytes.length ?? 0}B',
      );
      return result;
    } catch (e, st) {
      _productImageLogError('compress failed', e, st);
      rethrow;
    }
  }

  Future<ProductImageProcessResult?> _processPickedImageCore(XFile file) async {
    // Windows: لا نستدعي flutter_image_compress إطلاقاً (غير مدعوم ويسبب تجمّد).
    if (_isWindows) {
      return _processWindowsImageWithoutCompression(file);
    }

    final path = file.path.trim();
    ProductImageProcessResult? result;

    if (path.isNotEmpty) {
      result = await _processPath(path);
    }

    if (result != null) return result;

    final raw = await _imageUploadService.readFileBytes(file);
    if (raw == null || raw.isEmpty) {
      _productImageLogError('read bytes empty');
      return null;
    }

    result = await _processBytes(raw);
    return result ?? _fallbackFromRawBytes(file, raw);
  }

  /// مسار Windows الآمن: قراءة bytes الأصلية + فحص الحجم فقط بدون أي plugin.
  Future<ProductImageProcessResult?> _processWindowsImageWithoutCompression(
    XFile file,
  ) async {
    debugPrint(
      '[ProductImageUpload] Windows compression unavailable; '
      'validating original image bytes',
    );

    final raw = await _imageUploadService.readFileBytes(file);
    if (raw == null || raw.isEmpty) {
      _productImageLogError('read bytes empty (windows)');
      return null;
    }

    if (raw.length > maxWindowsImageBytes) {
      throw const ImageUploadException(
        'الصورة كبيرة جدًا. اختر صورة أصغر من 2MB.',
      );
    }

    final resolvedFile = file.path.trim().isNotEmpty
        ? file
        : XFile.fromData(
            raw,
            name: file.name.trim().isNotEmpty ? file.name : 'product.jpg',
            mimeType: 'image/jpeg',
          );

    return ProductImageProcessResult(
      file: resolvedFile,
      previewBytes: raw,
      uploadBytes: raw,
    );
  }

  Future<ProductImageProcessResult?> _processPath(String path) async {
    if (_useComputeForImageProcessing) {
      return compute(productImageProcessPathWorker, path);
    }
    return productImageProcessPathWorker(path);
  }

  Future<ProductImageProcessResult?> _processBytes(Uint8List raw) async {
    if (_useComputeForImageProcessing) {
      return compute(productImageProcessBytesWorker, raw);
    }
    return productImageProcessBytesWorker(raw);
  }

  ProductImageProcessResult _fallbackFromRawBytes(XFile file, Uint8List raw) {
    _productImageLog('compress fallback using raw bytes (${raw.length}B)');
    final resolvedFile = file.path.trim().isNotEmpty
        ? file
        : XFile.fromData(
            raw,
            name: file.name.trim().isNotEmpty ? file.name : 'product.jpg',
            mimeType: 'image/jpeg',
          );
    return ProductImageProcessResult(
      file: resolvedFile,
      previewBytes: raw,
      uploadBytes: raw,
    );
  }

  Future<String> uploadProductImage({
    required String restaurantId,
    required String productId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    _productImageLog('upload start productId=$productId bytes=${bytes.length}');
    try {
      final url = await _imageUploadService
          .uploadProductImage(
            restaurantId: restaurantId,
            productId: productId,
            bytes: bytes,
            fileName: fileName,
          )
          .timeout(
            uploadTimeout,
            onTimeout: () {
              throw ImageUploadException(
                productImageUploadFailureMessage,
                cause: TimeoutException('upload timeout'),
              );
            },
          );
      _productImageLog('upload end url=$url');
      return url;
    } on ImageUploadException catch (e, st) {
      _productImageLogError('upload failed', e, st);
      rethrow;
    } catch (e, st) {
      _productImageLogError('upload failed', e, st);
      throw ImageUploadException(productImageUploadFailureMessage, cause: e);
    }
  }
}
