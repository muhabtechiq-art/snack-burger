import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/admin_features/banners/banner_sort_order.dart';
import 'package:snack_burger/models/promo_banner_model.dart';

PromoBannerModel _banner(String id) {
  return PromoBannerModel(
    id: id,
    restaurantId: 'snack_burger',
    imageUrl: 'https://example.com/$id.jpg',
    title: id,
    isActive: true,
    sortOrder: 0,
    createdAt: DateTime.utc(2024, 1, 1),
  );
}

void main() {
  group('reorderBannersList', () {
    test('moves item down the list', () {
      final banners = [_banner('a'), _banner('b'), _banner('c')];
      final reordered = reorderBannersList(banners, 0, 2);

      expect(reordered.map((b) => b.id).toList(), ['b', 'a', 'c']);
    });

    test('moves item up the list', () {
      final banners = [_banner('a'), _banner('b'), _banner('c')];
      final reordered = reorderBannersList(banners, 2, 0);

      expect(reordered.map((b) => b.id).toList(), ['c', 'a', 'b']);
    });
  });

  group('sortOrdersForBannerList', () {
    test('assigns zero-based order indexes', () {
      expect(
        sortOrdersForBannerList([_banner('a'), _banner('b')]),
        [0, 1],
      );
    });
  });
}
