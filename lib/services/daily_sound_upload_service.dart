import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خطأ أثناء اختيار أو رفع ملف صوت اليوم.
class DailySoundUploadException implements Exception {
  const DailySoundUploadException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// اختيار ملف صوتي ورفعه إلى Supabase Storage (bucket: daily-sounds).
class DailySoundUploadService {
  DailySoundUploadService();

  static const String bucketName = 'daily-sounds';
  static const int maxBytes = 5 * 1024 * 1024;
  static const Set<String> allowedExtensions = {'mp3', 'm4a', 'aac'};
  static const String _logTag = 'DailySoundUploadService';

  static final RegExp _pathSegmentPattern = RegExp(r'[^\w\-]');
  static final RegExp _fileNamePattern = RegExp(r'[^\w.\-]');
  static final RegExp _outerSlashesPattern = RegExp(r'^/+|/+$');

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
    debugPrint(
      '$_logTag.$method: $message\n$error${stack != null ? '\n$stack' : ''}',
    );
  }

  static String _sanitizePathSegment(String value, RegExp pattern) {
    return value.trim().replaceAll(pattern, '_');
  }

  static String _stripOuterSlashes(String path) {
    return path.trim().replaceAll(_outerSlashesPattern, '');
  }

  static String storagePath({
    required String restaurantSlug,
    required String fileName,
  }) {
    final safeSlug = _sanitizePathSegment(restaurantSlug, _pathSegmentPattern);
    final safeName = _sanitizePathSegment(fileName, _fileNamePattern);
    if (safeSlug.isEmpty || safeName.isEmpty) {
      throw const DailySoundUploadException('مسار التخزين غير صالح');
    }
    return '$safeSlug/$safeName';
  }

  static String contentTypeForFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    return 'audio/mpeg';
  }

  static bool isAllowedExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return false;
    final ext = fileName.substring(dot + 1).toLowerCase();
    return allowedExtensions.contains(ext);
  }

  static String validatePublicUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw const DailySoundUploadException('تعذّر الحصول على رابط الملف');
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      throw const DailySoundUploadException('رابط الملف غير صالح');
    }
    return trimmed;
  }

  String getPublicUrlForStoragePath(String storagePath) {
    final path = _stripOuterSlashes(storagePath);
    if (path.isEmpty) {
      throw const DailySoundUploadException('مسار الملف فارغ بعد الرفع');
    }
    return validatePublicUrl(
      _supabase.storage.from(bucketName).getPublicUrl(path),
    );
  }

  static String? storagePathFromPublicUrl(String publicUrl) {
    final uri = Uri.tryParse(publicUrl.trim());
    if (uri == null) return null;

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(bucketName);
    if (bucketIndex < 0 || bucketIndex >= segments.length - 1) return null;

    return segments.sublist(bucketIndex + 1).join('/');
  }

  /// يختار ملفاً صوتياً من الجهاز (mp3 / m4a / aac — حد 5MB).
  Future<DailySoundPickResult?> pickAudioFile() async {
    try {
      final result = await FilePicker.platform
          .pickFiles(
            type: FileType.custom,
            allowedExtensions: allowedExtensions.toList(),
            withData: true,
            allowMultiple: false,
          )
          .timeout(
            const Duration(minutes: 2),
            onTimeout: () {
              _log('pickAudioFile', 'timed out');
              return null;
            },
          );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.single;
      final name = file.name.trim();
      if (name.isEmpty) {
        throw const DailySoundUploadException('اسم الملف غير صالح');
      }
      if (!isAllowedExtension(name)) {
        throw const DailySoundUploadException(
          'نوع الملف غير مدعوم. استخدم mp3 أو m4a أو aac',
        );
      }

      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw const DailySoundUploadException('تعذّر قراءة الملف');
      }
      if (bytes.length > maxBytes) {
        throw const DailySoundUploadException(
          'حجم الملف كبير جداً. الحد الأقصى 5 ميغابايت',
        );
      }

      return DailySoundPickResult(fileName: name, bytes: bytes);
    } on DailySoundUploadException {
      rethrow;
    } catch (e, st) {
      _log('pickAudioFile', 'failed', error: e, stack: st);
      throw DailySoundUploadException(
        'تعذّر اختيار الملف. حاول مرة أخرى',
        cause: e,
      );
    }
  }

  Future<DailySoundUploadResult> uploadDailySound({
    required String restaurantSlug,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw const DailySoundUploadException('ملف الصوت فارغ');
    }
    if (bytes.length > maxBytes) {
      throw const DailySoundUploadException(
        'حجم الملف كبير جداً. الحد الأقصى 5 ميغابايت',
      );
    }
    if (!isAllowedExtension(fileName)) {
      throw const DailySoundUploadException(
        'نوع الملف غير مدعوم. استخدم mp3 أو m4a أو aac',
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final resolvedName = '${timestamp}_$fileName';
    final path = storagePath(
      restaurantSlug: restaurantSlug,
      fileName: resolvedName,
    );

    try {
      final storage = _supabase.storage.from(bucketName);
      final uploadedKey = await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: contentTypeForFileName(resolvedName),
          upsert: true,
        ),
      );

      var normalizedPath = _stripOuterSlashes(uploadedKey);
      final bucketPrefix = '$bucketName/';
      if (normalizedPath.startsWith(bucketPrefix)) {
        normalizedPath = normalizedPath.substring(bucketPrefix.length);
      }
      if (normalizedPath.isEmpty) normalizedPath = path;

      final publicUrl = getPublicUrlForStoragePath(normalizedPath);
      _log('uploadDailySound', 'uploaded path: $normalizedPath');

      return DailySoundUploadResult(
        publicUrl: publicUrl,
        fileName: fileName,
        storagePath: normalizedPath,
      );
    } on StorageException catch (e, st) {
      _log(
        'uploadDailySound',
        'Storage status=${e.statusCode} message=${e.message}',
        error: e,
        stack: st,
      );
      throw DailySoundUploadException(
        'تعذّر رفع الملف. حاول مرة أخرى',
        cause: e,
      );
    } on DailySoundUploadException {
      rethrow;
    } on TimeoutException catch (e, st) {
      _log('uploadDailySound', 'timeout', error: e, stack: st);
      throw DailySoundUploadException(
        'انتهت مهلة رفع الملف. حاول مرة أخرى',
        cause: e,
      );
    } catch (e, st) {
      _log('uploadDailySound', 'failed', error: e, stack: st);
      throw DailySoundUploadException(
        'تعذّر رفع الملف. حاول مرة أخرى',
        cause: e,
      );
    }
  }

  Future<void> deleteByPublicUrl(String publicUrl) async {
    final path = storagePathFromPublicUrl(publicUrl);
    if (path == null || path.isEmpty) return;

    try {
      await _supabase.storage.from(bucketName).remove([path]);
      _log('deleteByPublicUrl', 'removed path: $path');
    } catch (e, st) {
      _log('deleteByPublicUrl', 'failed (ignored)', error: e, stack: st);
    }
  }
}

class DailySoundPickResult {
  const DailySoundPickResult({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

class DailySoundUploadResult {
  const DailySoundUploadResult({
    required this.publicUrl,
    required this.fileName,
    required this.storagePath,
  });

  final String publicUrl;
  final String fileName;
  final String storagePath;
}
