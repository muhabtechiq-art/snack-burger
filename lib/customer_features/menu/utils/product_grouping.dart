import '../../../models/product_model.dart';

/// تجميع المنتجات حسب القسم مع ترتيب أبجدي للأقسام.
Map<String, List<ProductModel>> groupProductsByCategory(List<ProductModel> products) {
  final grouped = <String, List<ProductModel>>{};
  for (final product in products) {
    final label = _categoryLabel(product.category);
    grouped.putIfAbsent(label, () => []).add(product);
  }

  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return {for (final key in sortedKeys) key: grouped[key]!};
}

String _categoryLabel(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed.toLowerCase() == 'general') {
    return 'قائمة عامة';
  }
  return trimmed.replaceAll('_', ' ');
}

/// ترتيب الأقسام: يحافظ على ترتيب ظهورها في القائمة عند الإمكان.
List<MapEntry<String, List<ProductModel>>> orderedCategoryEntries(
  List<ProductModel> products,
) {
  final grouped = groupProductsByCategory(products);
  final seen = <String>{};
  final ordered = <MapEntry<String, List<ProductModel>>>[];

  for (final product in products) {
    final label = _categoryLabel(product.category);
    if (seen.add(label)) {
      ordered.add(MapEntry(label, grouped[label]!));
    }
  }

  return ordered;
}
