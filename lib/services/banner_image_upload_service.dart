import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/image_compressor.dart';
import 'banner_image_diag_log.dart';
import 'image_pick_upload_service.dart';
import 'image_upload_exception.dart';

/// نتيجة ضغط صورة البانر للمعاينة داخل النموذج فقط.
class BannerImagePreviewResult {
  const BannerImagePreviewResult({
    required this.previewBytes,
    this.usedFallback = false,
  });

  final Uint8List previewBytes;
  final bool usedFallback;
}

/// اختيار وضغط ورفع صور البانر إلى Supabase Storage.
class BannerImageUploadService {
  BannerImageUploadService({
    ImagePicker? picker,
    ImagePickUploadService? productUploadService,
  })  : _picker = picker ?? ImagePicker(),
        _productUploadService = productUploadService ?? ImagePickUploadService();

  static const int previewMaxWidth = 1200;
  static const int previewMaxHeight = 1200;
  static const int previewQuality = 72;

  final ImagePicker _picker;
  final ImagePickUploadService _productUploadService;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<XFile?> pickBannerImageFromGallery() async {
    try {
      bannerImageDiag('pick_start', detail: 'service');
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2400,
        maxHeight: 2400,
      );
      bannerImageDiag('pick_done', detail: 'service selected=${picked != null}');
      return picked;
    } catch (e, st) {
      bannerImageDiag('pick_done', detail: 'service error=$e');
      debugPrint('BannerImageUploadService.pickBannerImageFromGallery: $e\n$st');
      return null;
    }
  }

  Future<Uint8List?> readAndCompress(XFile file) async {
    final path = file.path.trim();
    if (path.isNotEmpty) {
      bannerImageDiag('compress_start', detail: 'upload path');
      final fromFile = await ImageCompressor.compressFileForUpload(path);
      bannerImageDiag('compress_done', detail: 'upload path');
      if (fromFile != null && fromFile.isNotEmpty) return fromFile;
    }

    bannerImageDiag('read_bytes_start', detail: 'upload');
    final raw = await _productUploadService.readFileBytes(file);
    bannerImageDiag(
      'read_bytes_done',
      detail: 'upload bytes=${raw?.length ?? 0}',
    );
    if (raw == null || raw.isEmpty) return null;

    bannerImageDiag('compress_start', detail: 'upload bytes');
    final compressed = await ImageCompressor.compressForUpload(raw);
    bannerImageDiag('compress_done', detail: 'upload bytes');
    return compressed ?? raw;
  }

  /// يضغط صورة خفيفة للمعاينة داخل النموذج — لا تُستخدم للرفع النهائي.
  Future<BannerImagePreviewResult?> prepareBannerImagePreview(XFile file) async {
    final path = file.path.trim();
    Uint8List? preview;

    if (path.isNotEmpty) {
      bannerImageDiag('compress_start', detail: 'preview path');
      preview = await ImageCompressor.compressFileForUpload(
        path,
        minWidth: previewMaxWidth,
        minHeight: previewMaxHeight,
        quality: previewQuality,
      );
      bannerImageDiag('compress_done', detail: 'preview path');
    }

    if (preview == null || preview.isEmpty) {
      bannerImageDiag('read_bytes_start', detail: 'preview');
      final raw = await _productUploadService.readFileBytes(file);
      bannerImageDiag(
        'read_bytes_done',
        detail: 'preview bytes=${raw?.length ?? 0}',
      );
      if (raw == null || raw.isEmpty) return null;

      bannerImageDiag('compress_start', detail: 'preview bytes');
      preview = await ImageCompressor.compressForUpload(
        raw,
        minWidth: previewMaxWidth,
        minHeight: previewMaxHeight,
        quality: previewQuality,
      );
      bannerImageDiag('compress_done', detail: 'preview bytes');

      if (preview == null || preview.isEmpty) {
        debugPrint(
          '[BannerImageUploadService] WARNING prepareBannerImagePreview: '
          'compression failed — using original bytes for preview '
          '(${(raw.lengthInBytes / 1024).toStringAsFixed(1)} KB)',
        );
        return BannerImagePreviewResult(
          previewBytes: raw,
          usedFallback: true,
        );
      }
    }

    return BannerImagePreviewResult(previewBytes: preview);
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

  static String publicUrlWithCacheBust(String publicUrl) {
    final uri = Uri.parse(publicUrl.trim());
    final query = Map<String, String>.from(uri.queryParameters);
    query['v'] = DateTime.now().millisecondsSinceEpoch.toString();
    return uri.replace(queryParameters: query).toString();
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
      bannerImageDiag(
        'upload_start',
        detail: 'bannerId=$bannerId bytes=${bytes.length}',
      );
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

      final url = _productUploadService.getPublicUrlForStoragePath(normalizedPath);
      bannerImageDiag('upload_done', detail: 'bannerId=$bannerId');
      return url;
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
