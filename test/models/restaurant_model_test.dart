import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/models/restaurant_model.dart';

void main() {
  const baseMap = <String, dynamic>{
    'id': 'snack_burger',
    'slug': 'snack_burger',
    'name': 'Snack Burger',
    'primary_color': '#8B0000',
    'accent_color': '#E1AD01',
  };

  test('fromMap without restaurant_uuid leaves restaurantUuid null', () {
    final restaurant = RestaurantModel.fromMap(baseMap);

    expect(restaurant.id, 'snack_burger');
    expect(restaurant.slug, 'snack_burger');
    expect(restaurant.restaurantUuid, isNull);
  });

  test('fromMap reads restaurant_uuid snake_case', () {
    final restaurant = RestaurantModel.fromMap({
      ...baseMap,
      'restaurant_uuid': 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890',
    });

    expect(
      restaurant.restaurantUuid,
      'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    );
  });

  test('fromMap reads restaurantUuid camelCase', () {
    final restaurant = RestaurantModel.fromMap({
      ...baseMap,
      'restaurantUuid': '11111111-2222-3333-4444-555555555555',
    });

    expect(
      restaurant.restaurantUuid,
      '11111111-2222-3333-4444-555555555555',
    );
  });

  test('fromMap ignores invalid restaurant_uuid without throwing', () {
    final restaurant = RestaurantModel.fromMap({
      ...baseMap,
      'restaurant_uuid': 'not-a-uuid',
    });

    expect(restaurant.restaurantUuid, isNull);
    expect(restaurant.name, 'Snack Burger');
  });

  test('toMap includes restaurant_uuid when set', () {
    const uuid = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
    final restaurant = RestaurantModel.fromMap({
      ...baseMap,
      'restaurant_uuid': uuid,
    });

    expect(restaurant.toMap()['restaurant_uuid'], uuid);
  });
}
