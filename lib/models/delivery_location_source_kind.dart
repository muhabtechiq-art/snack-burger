/// مصدر إحداثيات التوصيل للطلب — داخلي (لا يُرسل لـ Supabase إن لم يكن العمود موجوداً).
enum DeliveryLocationSourceKind {
  savedHome,
  temporaryNew,
  updatedHome,
  manualMarker,
  gps;

  String get logValue => switch (this) {
        DeliveryLocationSourceKind.savedHome => 'saved_home',
        DeliveryLocationSourceKind.temporaryNew => 'temporary_new',
        DeliveryLocationSourceKind.updatedHome => 'updated_home',
        DeliveryLocationSourceKind.manualMarker => 'manual_marker',
        DeliveryLocationSourceKind.gps => 'gps',
      };

  String get displayLabel => switch (this) {
        DeliveryLocationSourceKind.savedHome => 'الموقع المحفوظ (البيت)',
        DeliveryLocationSourceKind.temporaryNew => 'موقع جديد — هذه الطلبية فقط',
        DeliveryLocationSourceKind.updatedHome => 'تحديث الموقع المحفوظ',
        DeliveryLocationSourceKind.manualMarker => 'موقع محدد يدوياً على الخريطة',
        DeliveryLocationSourceKind.gps => 'موقع GPS حالي',
      };
}

/// نية الزبون قبل فتح الخريطة (عند وجود موقع محفوظ).
enum OrderLocationIntent {
  none,
  orderOnly,
  updateSaved,
}
