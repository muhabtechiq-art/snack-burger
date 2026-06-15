import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/core/config/app_settings_defaults.dart';
import 'package:snack_burger/models/app_settings_model.dart';

void main() {
  test('defaults match AppSettingsDefaults', () {
    final settings = AppSettingsModel.defaults();

    expect(settings.maintenanceMode, AppSettingsDefaults.maintenanceMode);
    expect(settings.maintenanceTitle, AppSettingsDefaults.maintenanceTitle);
    expect(settings.phone1, AppSettingsDefaults.phone1);
    expect(settings.phone2, AppSettingsDefaults.phone2);
  });

  test('fromMap reads snake_case fields', () {
    final settings = AppSettingsModel.fromMap({
      'id': 'global',
      'maintenance_mode': true,
      'maintenance_title': 'عنوان',
      'maintenance_message': 'رسالة',
      'phone_1': '07700000000',
      'phone_2': '07800000000',
    });

    expect(settings.maintenanceMode, isTrue);
    expect(settings.maintenanceTitle, 'عنوان');
    expect(settings.phone1, '07700000000');
  });
}
