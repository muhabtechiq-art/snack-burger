import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/core/utils/price_utils.dart';

void main() {
  group('PriceUtils.normalizePrice', () {
    test('parses int and double', () {
      expect(PriceUtils.normalizePrice(6000), 6000);
      expect(PriceUtils.normalizePrice(6000.0), 6000);
      expect(PriceUtils.normalizePrice(7000.9), 7001);
    });

    test('strips separators and decimals from strings', () {
      expect(PriceUtils.normalizePrice('6.000'), 6000);
      expect(PriceUtils.normalizePrice('6,000'), 6000);
      expect(PriceUtils.normalizePrice('7000.0'), 7000);
      expect(PriceUtils.normalizePrice('18.000'), 18000);
    });

    test('same normalized key for equivalent prices', () {
      expect(
        PriceUtils.normalizedPriceKey(7000),
        PriceUtils.normalizedPriceKey(7000.0),
      );
      expect(
        PriceUtils.normalizedPriceKey('7000'),
        PriceUtils.normalizedPriceKey('7000.0'),
      );
    });
  });

  group('PriceUtils.formatPrice', () {
    test('formats thousands with dots', () {
      expect(PriceUtils.formatPrice(6000), '6.000');
      expect(PriceUtils.formatPrice(18000), '18.000');
      expect(PriceUtils.formatPrice(2500), '2.500');
    });
  });

  group('PriceUtils.suspiciousPriceSuggestion', () {
    test('suggests lower price for very large values', () {
      expect(
        PriceUtils.suspiciousPriceSuggestion(70000),
        '7.000',
      );
    });

    test('returns null for typical menu prices', () {
      expect(PriceUtils.suspiciousPriceSuggestion(7000), isNull);
      expect(PriceUtils.suspiciousPriceSuggestion(18000), isNull);
    });
  });

  group('PriceUtils.variantDuplicateKey', () {
    test('treats 7000 and 7000.0 as duplicates', () {
      final a = PriceUtils.variantDuplicateKey(
        productId: 'p1',
        name: 'وسط',
        price: 7000,
      );
      final b = PriceUtils.variantDuplicateKey(
        productId: 'p1',
        name: 'وسط',
        price: 7000.0,
      );
      expect(a, b);
    });
  });
}
