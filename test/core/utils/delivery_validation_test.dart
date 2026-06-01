import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/core/utils/delivery_coordinates.dart';
import 'package:snack_burger/core/utils/iraqi_phone_validator.dart';

void main() {
  group('IraqiPhoneValidator', () {
    test('accepts 11-digit number starting with 0', () {
      expect(IraqiPhoneValidator.validate('07701234567'), isNull);
      expect(IraqiPhoneValidator.normalize('0770 123 4567'), '07701234567');
    });

    test('rejects invalid lengths and prefixes', () {
      expect(IraqiPhoneValidator.validate('7701234567'), isNotNull);
      expect(IraqiPhoneValidator.validate('0770123456'), isNotNull);
      expect(IraqiPhoneValidator.validate(''), isNotNull);
    });
  });

  group('DeliveryCoordinates', () {
    test('formats and parses lat,long string', () {
      const formatted = '33.315200,44.366100';
      final parsed = DeliveryCoordinates.parse(formatted);

      expect(parsed?.latitude, closeTo(33.3152, 0.0001));
      expect(parsed?.longitude, closeTo(44.3661, 0.0001));
      expect(
        DeliveryCoordinates.format(parsed?.latitude, parsed?.longitude),
        formatted,
      );
    });

    test('builds Google Maps search URL', () {
      expect(
        DeliveryCoordinates.googleMapsSearchUrl(
          latitude: 33.3152,
          longitude: 44.3661,
        ),
        'https://www.google.com/maps/search/?api=1&query=33.3152,44.3661',
      );
    });
  });
}
