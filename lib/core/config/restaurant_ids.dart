/// معرّفات المطاعم في Supabase.
///
/// **جدول `orders`:** عمود `restaurant_id` من نوع UUID — ضع هنا المعرف
/// الفعلي من Supabase عند توفره. حتى ذلك الحين يُستخدم `slug` للربط.
abstract final class RestaurantIds {
  /// المطعم: Snack Burger — slug في الرابط: `/#/snack_burger`
  static const String snackBurgerSlug = 'snack_burger';

  /// UUID المطعم في Supabase — املأه عندما يتوفر (مثال: `a1b2c3d4-...`).
  /// إذا كان null يُرسل الطلب بدون `restaurant_id` ويعتمد على `slug`.
  static const String? snackBurgerUuid = null;

  /// للتوافق مع الكود القديم (slug — ليس UUID).
  static const String snackBurger = snackBurgerSlug;
}
