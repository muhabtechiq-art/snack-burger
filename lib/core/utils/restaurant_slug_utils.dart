/// تطبيع slug المطعم — نفس القواعد في الحفظ و«طلباتي» والاستعلام.
String normalizeRestaurantSlug(String slug) =>
    slug.trim().toLowerCase().replaceAll('-', '_');
