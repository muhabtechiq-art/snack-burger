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
      expect(IraqiPhoneValidator.validate('0770123456'), isNotNull);
      expect(IraqiPhoneValidator.validate(''), isNotNull);
    });

    test('accepts 10-digit mobile after normalize adds leading zero', () {
      expect(IraqiPhoneValidator.validate('7701234567'), isNull);
    });

    test('normalize handles +964 prefix and phonesMatch', () {
      expect(
        IraqiPhoneValidator.normalize('+964 770 123 4567'),
        '07701234567',
      );
      expect(
        IraqiPhoneValidator.phonesMatch('9647701234567', '07701234567'),
        isTrue,
      );
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
      const latitude = 33.3152;
      const longitude = 44.3661;

      final url = DeliveryCoordinates.googleMapsSearchUrl(
        latitude: latitude,
        longitude: longitude,
      );

      expect(url, contains('query='));
      final queryPart = url.split('query=').last;
      final parts = queryPart.split(',');
      expect(parts.length, 2);
      expect(double.parse(parts[0]), closeTo(latitude, 0.000001));
      expect(double.parse(parts[1]), closeTo(longitude, 0.000001));
    });
  });
}
