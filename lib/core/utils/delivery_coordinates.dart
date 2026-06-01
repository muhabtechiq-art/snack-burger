/// تنسيق وقراءة إحداثيات التوصيل وروابط Google Maps.
abstract final class DeliveryCoordinates {
  DeliveryCoordinates._();

  static String? format(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    return '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
  }

  static ({double latitude, double longitude})? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final parts = raw.split(',');
    if (parts.length != 2) return null;

    final latitude = double.tryParse(parts[0].trim());
    final longitude = double.tryParse(parts[1].trim());
    if (latitude == null || longitude == null) return null;

    return (latitude: latitude, longitude: longitude);
  }

  static String googleMapsSearchUrl({
    required double latitude,
    required double longitude,
  }) {
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }
}
