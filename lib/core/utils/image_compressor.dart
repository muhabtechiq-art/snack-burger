import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// ضغط الصور قبل الرفع — يعتمد على [flutter_image_compress].
abstract final class ImageCompressor {
  ImageCompressor._();

  static const int defaultMinWidth = 1600;
  static const int defaultMinHeight = 900;
  static const int defaultQuality = 82;

  /// يعيد JPEG مضغوطاً من مسار ملف (أسرع على الأجهزة المحمولة وسطح المكتب).
  static Future<Uint8List?> compressFileForUpload(
    String filePath, {
    int minWidth = defaultMinWidth,
    int minHeight = defaultMinHeight,
    int quality = defaultQuality,
  }) async {
    final path = filePath.trim();
    if (path.isEmpty) return null;

    try {
      final result = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (result == null || result.isEmpty) return null;
      return result;
    } catch (e, st) {
      debugPrint('ImageCompressor.compressFileForUpload: $e\n$st');
      return null;
    }
  }

  /// يعيد JPEG مضغوطاً من bytes — fallback عند غياب مسار الملف.
  static Future<Uint8List?> compressForUpload(
    Uint8List input, {
    int minWidth = defaultMinWidth,
    int minHeight = defaultMinHeight,
    int quality = defaultQuality,
  }) async {
    if (input.isEmpty) return null;

    try {
      final result = await FlutterImageCompress.compressWithList(
        input,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (result.isEmpty) return null;
      return result;
    } catch (e, st) {
      debugPrint('ImageCompressor.compressForUpload: $e\n$st');
      return null;
    }
  }
}
