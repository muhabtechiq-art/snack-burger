/// ترجمة عرضية لأسماء الأقسام — UI فقط، بدون تغيير بيانات Supabase.
String englishCategoryLabel(String arabicCategory) {
  const labels = <String, String>{
    'برجر': 'Burgers',
    'بيتزا': 'Pizza',
    'شاورما': 'Shawarma',
    'مقبلات': 'Appetizers',
    'مشروبات': 'Drinks',
    'حلويات': 'Desserts',
    'ساندwich': 'Sandwiches',
    'ساندويتش': 'Sandwiches',
    'وجبات': 'Meals',
    'قائمة عامة': 'Menu',
  };
  return labels[arabicCategory.trim()] ?? _fallbackEnglish(arabicCategory);
}

String _fallbackEnglish(String arabic) {
  final trimmed = arabic.trim();
  if (trimmed.isEmpty) return 'Menu';
  if (RegExp(r'^[A-Za-z0-9\s\-&]+$').hasMatch(trimmed)) {
    return trimmed;
  }
  return 'Category';
}
