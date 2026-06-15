import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/admin_features/products/admin_product_search.dart';
import 'package:snack_burger/models/product_model.dart';

ProductModel _product({
  required String id,
  required String name,
  String category = 'برجر',
  double price = 5000,
}) {
  return ProductModel(
    id: id,
    restaurantId: 'r1',
    name: name,
    price: price,
    category: category,
    createdAt: DateTime(2024, 1, 1),
  );
}

List<ProductModel> _manyProducts(int count) {
  return List<ProductModel>.generate(
    count,
    (i) => _product(
      id: 'p$i',
      name: i.isEven ? 'برجر لحم $i' : 'دجاج مشوي $i',
      category: i % 3 == 0 ? 'برجر' : i % 3 == 1 ? 'دجاج' : 'مشروبات',
      price: 3000 + (i * 100),
    ),
  );
}

void main() {
  group('AdminProductSearch', () {
    final catalog = [
      _product(id: '1', name: 'برجر كلاسيك', category: 'برجر', price: 7500),
      _product(id: '2', name: 'دجاج مقرمش', category: 'دجاج', price: 6000),
      _product(id: '3', name: 'عصير برتقال', category: 'مشروبات', price: 2000),
    ];

    test('normalizeQuery trims and lowercases', () {
      expect(AdminProductSearch.normalizeQuery('  برجر  '), 'برجر');
      expect(AdminProductSearch.normalizeQuery('ABC'), 'abc');
    });

    test('empty query returns full catalog copy', () {
      final results = AdminProductSearch.filter(catalog, '');
      expect(results.length, catalog.length);
      expect(identical(results, catalog), isFalse);
    });

    test('matches product name', () {
      final results = AdminProductSearch.filter(catalog, 'برجر');
      expect(results.map((p) => p.id).toList(), ['1']);
    });

    test('matches category', () {
      final results = AdminProductSearch.filter(catalog, 'دجاج');
      expect(results.map((p) => p.id).toList(), ['2']);
    });

    test('matches price digits', () {
      final results = AdminProductSearch.filter(catalog, '2000');
      expect(results.map((p) => p.id).toList(), ['3']);
    });

    test('no match returns empty list', () {
      final results = AdminProductSearch.filter(catalog, 'بيتزا');
      expect(results, isEmpty);
    });

    test('filters 250 products quickly', () {
      final products = _manyProducts(250);
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 20; i++) {
        AdminProductSearch.filter(products, 'برجر');
        AdminProductSearch.filter(products, '7500');
        AdminProductSearch.filter(products, 'دجاج');
      }

      stopwatch.stop();
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(500),
        reason: '20 filter passes over 250 items should stay under 500ms',
      );
    });

    test('edit/delete target stays correct after filter', () {
      final products = _manyProducts(200);
      final results = AdminProductSearch.filter(products, 'برجر لحم 42');
      expect(results.length, 1);
      expect(results.single.id, 'p42');
    });
  });
}
