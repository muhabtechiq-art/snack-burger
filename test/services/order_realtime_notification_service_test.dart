import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snack_burger/services/order_realtime_notification_service.dart';

void main() {
  group('OrderRealtimeNotificationService.buildSlugInsertFilter', () {
    test('builds slug=eq filter for normalized slug', () {
      final filter = OrderRealtimeNotificationService.buildSlugInsertFilter(
        'snack_burger',
      );

      expect(filter.column, 'slug');
      expect(filter.type, PostgresChangeFilterType.eq);
      expect(filter.value, 'snack_burger');
      expect(filter.toString(), 'slug=eq.snack_burger');
    });

    test('trims and lowercases slug before filtering', () {
      final filter = OrderRealtimeNotificationService.buildSlugInsertFilter(
        '  Snack_Burger  ',
      );

      expect(filter.value, 'snack_burger');
      expect(filter.toString(), 'slug=eq.snack_burger');
    });

    test('throws when slug is empty', () {
      expect(
        () => OrderRealtimeNotificationService.buildSlugInsertFilter(''),
        throwsArgumentError,
      );
    });
  });
}
