import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/core/utils/restaurant_slug_utils.dart';

void main() {
  group('normalizeRestaurantSlug', () {
    test('trims, lowercases, and replaces hyphens with underscores', () {
      expect(normalizeRestaurantSlug(' Snack-Burger '), 'snack_burger');
      expect(normalizeRestaurantSlug('snack_burger'), 'snack_burger');
      expect(normalizeRestaurantSlug('snack-burger'), 'snack_burger');
    });
  });
}
