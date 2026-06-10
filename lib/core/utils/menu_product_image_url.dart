/// روابط صور المنيو — نسخة مصغّرة لـ Supabase Storage عند الإمكان.
abstract final class MenuProductImageUrl {
  MenuProductImageUrl._();

  static String? normalizeImageUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri.toString();
  }

  /// يبني رابطاً أصغر للعرض في بطاقات المنيو (Supabase Image Transform).
  /// إن لم يكن الرابط من Storage، يُعاد الرابط الأصلي.
  static String? thumbnail(
    String? rawUrl, {
    int width = 320,
    int height = 320,
    int quality = 78,
  }) {
    final normalized = normalizeImageUrl(rawUrl);
    if (normalized == null) return null;

    final uri = Uri.tryParse(normalized);
    if (uri == null) return normalized;

    const objectSegment = '/storage/v1/object/public/';
    const renderSegment = '/storage/v1/render/image/public/';

    if (!uri.path.contains(objectSegment)) {
      return normalized;
    }

    final renderPath = uri.path.replaceFirst(objectSegment, renderSegment);
    return uri
        .replace(
          path: renderPath,
          queryParameters: <String, String>{
            'width': '$width',
            'height': '$height',
            'resize': 'cover',
            'quality': '$quality',
          },
        )
        .toString();
  }
}
