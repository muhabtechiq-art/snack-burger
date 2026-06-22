/// خطأ أثناء رفع صورة المنتج إلى Supabase Storage.
class ImageUploadException implements Exception {
  const ImageUploadException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ImageUploadException: $message';
}

/// رسالة موحّدة عند فشل رفع صورة المنتج.
const String productImageUploadFailureMessage =
    'فشل رفع الصورة، تحقق من الاتصال أو حجم الصورة';
