/// خطأ أثناء رفع صورة المنتج إلى Supabase Storage.
class ImageUploadException implements Exception {
  const ImageUploadException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ImageUploadException: $message';
}
