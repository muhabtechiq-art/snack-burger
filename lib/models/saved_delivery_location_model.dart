import '../core/utils/delivery_coordinates.dart';

/// موقع توصيل محفوظ من جدول profiles.
class SavedDeliveryLocation {
  const SavedDeliveryLocation({
    required this.phoneNumber,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final String phoneNumber;
  final double latitude;
  final double longitude;

  /// `last_delivery_address` من profiles.
  final String? address;

  String get addressLabel {
    final trimmed = address?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return 'عنوانك المحفوظ';
  }

  String get googleMapsUrl => DeliveryCoordinates.googleMapsSearchUrl(
        latitude: latitude,
        longitude: longitude,
      );

  static SavedDeliveryLocation? fromProfileRow(
    Map<String, dynamic> row, {
    required String phoneNumber,
  }) {
    final hasSaved = row['has_saved_location'] == true;
    if (!hasSaved) return null;

    final latitude = (row['last_latitude'] as num?)?.toDouble();
    final longitude = (row['last_longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;

    final address = row['last_delivery_address']?.toString().trim();

    return SavedDeliveryLocation(
      phoneNumber: phoneNumber,
      latitude: latitude,
      longitude: longitude,
      address: address != null && address.isNotEmpty ? address : null,
    );
  }
}
