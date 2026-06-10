import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/image_compressor.dart';
import 'image_pick_upload_service.dart';
import 'image_upload_exception.dart';

/// اختيار وضغط ورفع صور البانر إلى Supabase Storage.
class BannerImageUploadService {
  BannerImageUploadService({
    ImagePicker? picker,
    ImagePickUploadService? productUploadService,
  })  : _picker = picker ?? ImagePicker(),
        _productUploadService = productUploadService ?? ImagePickUploadService();

  final ImagePicker _picker;
  final ImagePickUploadService _productUploadService;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<XFile?> pickBannerImageFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2400,
        maxHeight: 2400,
      );
    } catch (e, st) {
      debugPrint('BannerImageUploadService.pickBannerImageFromGallery: $e\n$st');
      return null;
    }
  }

  Future<Uint8List?> readAndCompress(XFile file) async {
    final path = file.path.trim();
    if (path.isNotEmpty) {
      final fromFile = await ImageCompressor.compressFileForUpload(path);
      if (fromFile != null && fromFile.isNotEmpty) return fromFile;
    }

    final raw = await _productUploadService.readFileBytes(file);
    if (raw == null || raw.isEmpty) return null;

    final compressed = await ImageCompressor.compressForUpload(raw);
    return compressed ?? raw;
  }

  static String bannerStoragePath({
    required String restaurantId,
    required String bannerId,
  }) {
    final safeRestaurant = restaurantId.trim().replaceAll(RegExp(r'[^\w\-]'), '_');
    final safeBanner = bannerId.trim().replaceAll(RegExp(r'[^\w\-]'), '_');
    if (safeRestaurant.isEmpty || safeBanner.isEmpty) {
      throw const ImageUploadException('مسار تخزين البانر غير صالح');
    }
    return '$safeRestaurant/banners/$safeBanner.jpg';
  }

  Future<String> uploadBannerImage({
    required String restaurantId,
    required String bannerId,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw const ImageUploadException('ملف البانر فارغ أو تالف');
    }

    final storagePath = bannerStoragePath(
      restaurantId: restaurantId,
      bannerId: bannerId,
    );

    try {
      final storage = _supabase.storage.from(ImagePickUploadService.bucketName);
      final uploadedKey = await storage.uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final normalizedPath = ImagePickUploadService.normalizeUploadedKey(
        uploadedKey: uploadedKey,
        fallbackPath: storagePath,
      );

      return _productUploadService.getPublicUrlForStoragePath(normalizedPath);
    } on StorageException catch (e, st) {
      debugPrint(
        'BannerImageUploadService.uploadBannerImage: '
        'status=${e.statusCode} message=${e.message}\n$st',
      );
      rethrow;
    } catch (e, st) {
      debugPrint('BannerImageUploadService.uploadBannerImage: $e\n$st');
      throw ImageUploadException(
        'تعذّر رفع صورة البانر. حاول مرة أخرى',
        cause: e,
      );
    }
  }
}
