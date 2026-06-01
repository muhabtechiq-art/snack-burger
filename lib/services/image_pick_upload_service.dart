import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'image_upload_exception.dart';

/// اختيار صورة من المعرض ورفعها إلى Supabase Storage.
class ImagePickUploadService {
  ImagePickUploadService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const String bucketName = 'product-images';

  final ImagePicker _picker;

  SupabaseClient get _supabase => Supabase.instance.client;

  static String productImageStoragePath({
    required String restaurantId,
    required String productId,
    required String fileName,
  }) {
    final safeRestaurant = restaurantId.trim().replaceAll(RegExp(r'[^\w\-]'), '_');
    final safeProduct = productId.trim().replaceAll(RegExp(r'[^\w\-]'), '_');
    final safeName = fileName.trim().replaceAll(RegExp(r'[^\w.\-]'), '_');

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
    var key = uploadedKey.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final bucketPrefix = '$bucketName/';

    if (key.startsWith(bucketPrefix)) {
      key = key.substring(bucketPrefix.length);
    }

    return key.isNotEmpty ? key : fallbackPath;
  }

  /// يبني الرابط العام من Supabase بعد الرفع — لا يستخدم الحافظة أو نصوص يدوية.
  String getPublicUrlForStoragePath(String storagePath) {
    final path = storagePath.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (path.isEmpty) {
      throw const ImageUploadException('مسار الصورة فارغ بعد الرفع');
    }

    final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(path);
    return validatePublicUrl(publicUrl);
  }

  /// يتحقق أن الرابط HTTP حقيقي وليس نص إشعار أو لصق خاطئ.
  static String validatePublicUrl(String url) {
    final trimmed = url.trim();
    final lower = trimmed.toLowerCase();

    if (trimmed.isEmpty) {
      throw const ImageUploadException('تعذّر الحصول على رابط الصورة العام');
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      throw const ImageUploadException('رابط الصورة غير صالح');
    }
    if (lower.contains('copied') || lower.contains('clipboard')) {
      throw const ImageUploadException(
        'رابط الصورة غير صالح — يُجلب تلقائياً من Supabase بعد الرفع',
      );
    }

    return trimmed;
  }

  Future<XFile?> pickProductImageFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
    } catch (e, st) {
      debugPrint('ImagePickUploadService.pickProductImageFromGallery: $e\n$st');
      return null;
    }
  }

  Future<Uint8List?> readFileBytes(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        debugPrint('ImagePickUploadService.readFileBytes: empty file');
        return null;
      }
      return bytes;
    } catch (e, st) {
      debugPrint('ImagePickUploadService.readFileBytes: $e\n$st');
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
    if (trimmed.isNotEmpty &&
        !trimmed.toLowerCase().contains('copied') &&
        !trimmed.toLowerCase().contains('clipboard')) {
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

      debugPrint('[ImagePickUploadService] uploaded path: $normalizedPath');
      debugPrint('[ImagePickUploadService] publicUrl: $publicUrl');

      return publicUrl;
    } on StorageException catch (e, st) {
      debugPrint(
        'ImagePickUploadService.uploadProductImage Storage: '
        'status=${e.statusCode} message=${e.message} error=${e.error}\n$st',
      );
      rethrow;
    } on ImageUploadException {
      rethrow;
    } on TimeoutException catch (e, st) {
      debugPrint('ImagePickUploadService.uploadProductImage timeout: $e\n$st');
      throw ImageUploadException(
        'انتهت مهلة رفع الصورة. حاول مرة أخرى',
        cause: e,
      );
    } catch (e, st) {
      debugPrint('ImagePickUploadService.uploadProductImage: $e\n$st');
      throw ImageUploadException(
        'تعذّر رفع الصورة. حاول مرة أخرى',
        cause: e,
      );
    }
  }
}
