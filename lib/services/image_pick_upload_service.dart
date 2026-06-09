import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'image_upload_exception.dart';

/// اختيار صورة من المعرض ورفعها إلى Supabase Storage.
class ImagePickUploadService {
  ImagePickUploadService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const String bucketName = 'product-images';
  static const String _logTag = 'ImagePickUploadService';

  static final RegExp _pathSegmentPattern = RegExp(r'[^\w\-]');
  static final RegExp _fileNamePattern = RegExp(r'[^\w.\-]');
  static final RegExp _outerSlashesPattern = RegExp(r'^/+|/+$');

  final ImagePicker _picker;

  SupabaseClient get _supabase => Supabase.instance.client;

  static void _log(
    String method,
    String message, {
    Object? error,
    StackTrace? stack,
  }) {
    if (error == null) {
      debugPrint('$_logTag.$method: $message');
      return;
    }
    debugPrint('$_logTag.$method: $message\n$error${stack != null ? '\n$stack' : ''}');
  }

  static String _sanitizePathSegment(String value, RegExp pattern) {
    return value.trim().replaceAll(pattern, '_');
  }

  static String _stripOuterSlashes(String path) {
    return path.trim().replaceAll(_outerSlashesPattern, '');
  }

  static bool _isClipboardLikeText(String value) {
    final lower = value.trim().toLowerCase();
    return lower.contains('copied') || lower.contains('clipboard');
  }

  static String productImageStoragePath({
    required String restaurantId,
    required String productId,
    required String fileName,
  }) {
    final safeRestaurant =
        _sanitizePathSegment(restaurantId, _pathSegmentPattern);
    final safeProduct = _sanitizePathSegment(productId, _pathSegmentPattern);
    final safeName = _sanitizePathSegment(fileName, _fileNamePattern);

    if (safeRestaurant.isEmpty || safeProduct.isEmpty) {
      throw const ImageUploadException('مسار التخزين غير صالح');
    }
    if (safeName.isEmpty) {
      throw const ImageUploadException('اسم الملف غير صالح');
    }

    return '$safeRestaurant/$safeProduct/$safeName';
  }

  /// يحوّل `Key` القادم من Storage إلى مسار نسبي داخل الـ bucket.
  static String normalizeUploadedKey({
    required String uploadedKey,
    required String fallbackPath,
  }) {
    var key = _stripOuterSlashes(uploadedKey);
    final bucketPrefix = '$bucketName/';

    if (key.startsWith(bucketPrefix)) {
      key = key.substring(bucketPrefix.length);
    }

    return key.isNotEmpty ? key : fallbackPath;
  }

  /// يبني الرابط العام من Supabase بعد الرفع — لا يستخدم الحافظة أو نصوص يدوية.
  String getPublicUrlForStoragePath(String storagePath) {
    final path = _stripOuterSlashes(storagePath);
    if (path.isEmpty) {
      throw const ImageUploadException('مسار الصورة فارغ بعد الرفع');
    }

    final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(path);
    return validatePublicUrl(publicUrl);
  }

  /// يتحقق أن الرابط HTTP حقيقي وليس نص إشعار أو لصق خاطئ.
  static String validatePublicUrl(String url) {
    final trimmed = url.trim();

    if (trimmed.isEmpty) {
      throw const ImageUploadException('تعذّر الحصول على رابط الصورة العام');
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      throw const ImageUploadException('رابط الصورة غير صالح');
    }
    if (_isClipboardLikeText(trimmed)) {
      throw const ImageUploadException(
        'رابط الصورة غير صالح — يُجلب تلقائياً من Supabase بعد الرفع',
      );
    }

    return trimmed;
  }

  Future<XFile?> pickProductImageFromGallery() async {
    try {
      return await _picker
          .pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
            maxWidth: 2048,
            maxHeight: 2048,
          )
          .timeout(
            const Duration(minutes: 2),
            onTimeout: () {
              _log('pickProductImageFromGallery', 'timed out');
              return null;
            },
          );
    } catch (e, st) {
      _log('pickProductImageFromGallery', 'failed', error: e, stack: st);
      return null;
    }
  }

  Future<Uint8List?> readFileBytes(XFile file) async {
    try {
      final bytes = await file.readAsBytes().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _log('readFileBytes', 'timed out');
          return Uint8List(0);
        },
      );
      if (bytes.isEmpty) {
        _log('readFileBytes', 'empty file');
        return null;
      }
      return bytes;
    } catch (e, st) {
      _log('readFileBytes', 'failed', error: e, stack: st);
      return null;
    }
  }

  static String contentTypeForFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  static String resolveFileName({
    required String originalName,
    required String productId,
  }) {
    final trimmed = originalName.trim();
    if (trimmed.isNotEmpty && !_isClipboardLikeText(trimmed)) {
      return trimmed;
    }
    return '$productId.jpg';
  }

  /// يرفع الصورة ثم يعيد الرابط العام من `getPublicUrl`.
  Future<String> uploadProductImage({
    required String restaurantId,
    required String productId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw const ImageUploadException('ملف الصورة فارغ أو تالف');
    }

    final resolvedName = resolveFileName(
      originalName: fileName,
      productId: productId,
    );

    final storagePath = productImageStoragePath(
      restaurantId: restaurantId,
      productId: productId,
      fileName: resolvedName,
    );

    try {
      final storage = _supabase.storage.from(bucketName);

      final uploadedKey = await storage.uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: contentTypeForFileName(resolvedName),
          upsert: true,
        ),
      );

      final normalizedPath = normalizeUploadedKey(
        uploadedKey: uploadedKey,
        fallbackPath: storagePath,
      );

      final publicUrl = getPublicUrlForStoragePath(normalizedPath);

      _log('uploadProductImage', 'uploaded path: $normalizedPath');
      _log('uploadProductImage', 'publicUrl: $publicUrl');

      return publicUrl;
    } on StorageException catch (e, st) {
      _log(
        'uploadProductImage',
        'Storage status=${e.statusCode} message=${e.message} error=${e.error}',
        error: e,
        stack: st,
      );
      rethrow;
    } on ImageUploadException {
      rethrow;
    } on TimeoutException catch (e, st) {
      _log('uploadProductImage', 'timeout', error: e, stack: st);
      throw ImageUploadException(
        'انتهت مهلة رفع الصورة. حاول مرة أخرى',
        cause: e,
      );
    } catch (e, st) {
      _log('uploadProductImage', 'failed', error: e, stack: st);
      throw ImageUploadException(
        'تعذّر رفع الصورة. حاول مرة أخرى',
        cause: e,
      );
    }
  }
}
