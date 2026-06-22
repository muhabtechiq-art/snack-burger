import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/services/supabase_banner_service.dart';

void main() {
  group('SupabaseBannerService.bannersServerFilterLabel', () {
    test('returns restaurant_id=eq label for normalized id', () {
      expect(
        SupabaseBannerService.bannersServerFilterLabel('snack_burger'),
        'restaurant_id=eq.snack_burger',
      );
    });

    test('trims and lowercases restaurant id in label', () {
      expect(
        SupabaseBannerService.bannersServerFilterLabel('  Snack_Burger  '),
        'restaurant_id=eq.snack_burger',
      );
    });

    test('returns none when restaurant id is empty', () {
      expect(
        SupabaseBannerService.bannersServerFilterLabel(''),
        'none',
      );
      expect(
        SupabaseBannerService.bannersServerFilterLabel('   '),
        'none',
      );
    });
  });
}
