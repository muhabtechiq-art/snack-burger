import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/image_compressor.dart';
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

  /// أقصى حجم مقبول للصورة على Windows (حيث لا يتوفر ضغط داخل التطبيق).
  static const int maxWindowsImageBytes = 2 * 1024 * 1024;

  final ImagePicker _picker;
  final ImagePickUploadService _productUploadService;

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Windows لا يدعم image_picker/flutter_image_compress بثبات — نتجنّبهما.
  static bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<XFile?> pickBannerImageFromGallery() async {
    if (_isWindows) {
      return _pickBannerImageOnWindows();
    }
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2400,
        maxHeight: 2400,
      );
      return picked;
    } catch (e, st) {
      debugPrint('BannerImageUploadService.pickBannerImageFromGallery: $e\n$st');
      return null;
    }
  }

  /// Windows: file_picker بدل image_picker (الأخير يتجمّد قبل فتح النافذة).
  Future<XFile?> _pickBannerImageOnWindows() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        return null;
      }
      final picked = result.files.single;
      final path = picked.path;
      if (path == null || path.trim().isEmpty) {
        debugPrint('[BannerImageUpload] windows: empty path');
        return null;
      }
      return XFile(path, name: picked.name);
    } catch (e, st) {
      debugPrint('[BannerImageUpload] windows pick failed: $e\n$st');
      return null;
    }
  }

  Future<Uint8List?> readAndCompress(XFile file) async {
    if (_isWindows) {
      return _readWindowsImageBytesOrThrow(file);
    }

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

  /// يضغط صورة خفيفة للمعاينة داخل النموذج — لا تُستخدم للرفع النهائي.
  Future<BannerImagePreviewResult?> prepareBannerImagePreview(XFile file) async {
    if (_isWindows) {
      final raw = await _readWindowsImageBytesOrThrow(file);
      if (raw == null || raw.isEmpty) return null;
      // لا ضغط على Windows — نعرض البايتات الأصلية المُتحقَّق من حجمها.
      return BannerImagePreviewResult(previewBytes: raw, usedFallback: true);
    }

    final path = file.path.trim();
    Uint8List? preview;

    if (path.isNotEmpty) {
      preview = await ImageCompressor.compressFileForUpload(
        path,
        minWidth: previewMaxWidth,
        minHeight: previewMaxHeight,
        quality: previewQuality,
      );
    }

    if (preview == null || preview.isEmpty) {
      final raw = await _productUploadService.readFileBytes(file);
      if (raw == null || raw.isEmpty) return null;

      preview = await ImageCompressor.compressForUpload(
        raw,
        minWidth: previewMaxWidth,
        minHeight: previewMaxHeight,
        quality: previewQuality,
      );

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

  /// مسار Windows الآمن: قراءة البايتات الأصلية + فحص الحجم فقط بدون أي plugin.
  Future<Uint8List?> _readWindowsImageBytesOrThrow(XFile file) async {
    final raw = await _productUploadService.readFileBytes(file);
    if (raw == null || raw.isEmpty) {
      debugPrint('[BannerImageUpload] read bytes empty (windows)');
      return null;
    }
    if (raw.length > maxWindowsImageBytes) {
      throw const ImageUploadException(
        'الصورة كبيرة جدًا. اختر صورة أصغر من 2MB.',
      );
    }
    return raw;
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
