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
    expect(settings.dailySoundEnabled, AppSettingsDefaults.dailySoundEnabled);
    expect(settings.dailySoundVolume, AppSettingsDefaults.dailySoundVolume);
    expect(settings.dailySoundLoop, AppSettingsDefaults.dailySoundLoop);
  });

  test('fromMap reads snake_case fields', () {
    final settings = AppSettingsModel.fromMap({
      'id': 'global',
      'maintenance_mode': true,
      'maintenance_title': 'عنوان',
      'maintenance_message': 'رسالة',
      'phone_1': '07700000000',
      'phone_2': '07800000000',
      'daily_sound_enabled': true,
      'daily_sound_url': 'https://example.com/sound.mp3',
      'daily_sound_title': 'welcome.mp3',
      'daily_sound_volume': 0.5,
      'daily_sound_loop': true,
    });

    expect(settings.maintenanceMode, isTrue);
    expect(settings.maintenanceTitle, 'عنوان');
    expect(settings.phone1, '07700000000');
    expect(settings.dailySoundEnabled, isTrue);
    expect(settings.dailySoundUrl, 'https://example.com/sound.mp3');
    expect(settings.dailySoundTitle, 'welcome.mp3');
    expect(settings.dailySoundVolume, 0.5);
    expect(settings.dailySoundLoop, isTrue);
    expect(settings.hasDailySound, isTrue);
  });

  test('hasDailySound is false when disabled or url empty', () {
    expect(
      AppSettingsModel.defaults().hasDailySound,
      isFalse,
    );
    expect(
      AppSettingsModel.defaults()
          .copyWith(dailySoundEnabled: true)
          .hasDailySound,
      isFalse,
    );
    expect(
      AppSettingsModel.defaults()
          .copyWith(
            dailySoundEnabled: true,
            dailySoundUrl: 'https://example.com/a.mp3',
          )
          .hasDailySound,
      isTrue,
    );
  });

  test('toUpdateMap includes daily sound fields', () {
    final map = AppSettingsModel.defaults()
        .copyWith(
          dailySoundEnabled: true,
          dailySoundUrl: 'https://example.com/a.mp3',
          dailySoundTitle: 'a.mp3',
          dailySoundVolume: 0.3,
          dailySoundLoop: false,
        )
        .toUpdateMap();

    expect(map['daily_sound_enabled'], isTrue);
    expect(map['daily_sound_url'], 'https://example.com/a.mp3');
    expect(map['daily_sound_title'], 'a.mp3');
    expect(map['daily_sound_volume'], 0.3);
    expect(map['daily_sound_loop'], isFalse);
  });
}
