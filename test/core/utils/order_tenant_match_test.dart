import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/core/utils/order_tenant_match.dart';
import 'package:snack_burger/models/delivery_order_model.dart';
import 'package:snack_burger/services/supabase_order_service.dart';

DeliveryOrder _order({
  required String id,
  String slug = '',
  String restaurantId = '',
}) {
  return DeliveryOrder(
    id: id,
    restaurantId: restaurantId,
    slug: slug,
    customerName: 'Customer',
    customerPhone: '07701234567',
    address: 'Address',
    items: const [],
    totalPrice: 5000,
    status: 'pending',
    createdAt: DateTime.utc(2026, 6, 19),
  );
}

void main() {
  setUp(OrderTenantMatch.resetWarningsForTest);

  const activeSlug = 'snack_burger';
  const activeUuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

  group('OrderTenantMatch.matches', () {
    test('matches by order.slug', () {
      final order = _order(
        id: '1',
        slug: 'snack_burger',
        restaurantId: activeUuid,
      );

      expect(
        OrderTenantMatch.matches(
          order,
          activeSlug: activeSlug,
          activeRestaurantUuid: activeUuid,
        ),
        isTrue,
      );
    });

    test('matches by order.restaurant_id UUID', () {
      final order = _order(
        id: '2',
        slug: '',
        restaurantId: activeUuid,
      );

      expect(
        OrderTenantMatch.matches(
          order,
          activeSlug: activeSlug,
          activeRestaurantUuid: activeUuid,
        ),
        isTrue,
      );
    });

    test('legacy text restaurant_id equals active slug', () {
      final order = _order(
        id: '3',
        slug: '',
        restaurantId: 'snack_burger',
      );

      expect(
        OrderTenantMatch.matches(
          order,
          activeSlug: activeSlug,
        ),
        isTrue,
      );
    });

    test('does not match another tenant slug and uuid', () {
      final order = _order(
        id: '4',
        slug: 'other_restaurant',
        restaurantId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      );

      expect(
        OrderTenantMatch.matches(
          order,
          activeSlug: activeSlug,
          activeRestaurantUuid: activeUuid,
        ),
        isFalse,
      );
    });

    test('does not match all tenants when slug and restaurant_id are empty', () {
      final order = _order(id: '5');

      expect(
        OrderTenantMatch.matches(
          order,
          activeSlug: activeSlug,
          activeRestaurantUuid: activeUuid,
        ),
        isFalse,
      );
    });

    test('UUID restaurant_id does not match slug-only active scope', () {
      final order = _order(
        id: '6',
        slug: '',
        restaurantId: activeUuid,
      );

      expect(
        OrderTenantMatch.matches(
          order,
          activeSlug: activeSlug,
        ),
        isFalse,
      );
    });
  });

  group('DeliveryOrder.matchesActiveTenant', () {
    test('delegates to OrderTenantMatch', () {
      final order = _order(
        id: '7',
        slug: 'snack_burger',
        restaurantId: activeUuid,
      );

      expect(
        order.matchesActiveTenant(
          activeSlug: activeSlug,
          activeRestaurantUuid: activeUuid,
        ),
        isTrue,
      );
    });
  });

  group('SupabaseOrderService.orderMatchesSlug', () {
    test('accepts optional restaurantUuid', () {
      final order = _order(
        id: '8',
        slug: '',
        restaurantId: activeUuid,
      );

      expect(
        SupabaseOrderService.orderMatchesSlug(
          order,
          activeSlug,
          restaurantUuid: activeUuid,
        ),
        isTrue,
      );
    });

    test('slug-only scope still works when restaurantUuid is null', () {
      final order = _order(
        id: '10',
        slug: activeSlug,
        restaurantId: activeUuid,
      );

      expect(
        SupabaseOrderService.orderMatchesSlug(order, activeSlug),
        isTrue,
      );
    });
  });
}
