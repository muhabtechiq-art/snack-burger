import 'saved_delivery_location_model.dart';

/// بيانات موقع التوصيل من RPC حسب `phone_number`.
class CustomerDeliveryProfile {
  const CustomerDeliveryProfile({
    required this.phoneNumber,
    required this.hasSavedLocation,
    this.savedLocation,
  });

  final String phoneNumber;
  final bool hasSavedLocation;
  final SavedDeliveryLocation? savedLocation;

  /// يعرض نافذة التأكيد عند وجود عنوان محفوظ صالح.
  bool get shouldConfirmSavedAddress =>
      hasSavedLocation && savedLocation != null;

  static CustomerDeliveryProfile fromRpcRow(
    Map<String, dynamic> row, {
    required String phoneNumber,
  }) {
    final hasSaved = row['has_saved_location'] == true;
    final saved = hasSaved
        ? SavedDeliveryLocation.fromProfileRow(row, phoneNumber: phoneNumber)
        : null;

    return CustomerDeliveryProfile(
      phoneNumber: phoneNumber,
      hasSavedLocation: hasSaved,
      savedLocation: saved,
    );
  }
}
