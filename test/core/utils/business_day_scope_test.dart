import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/core/utils/business_day_scope.dart';
import 'package:snack_burger/models/business_day_model.dart';

void main() {
  test('reportDateFor uses opened_at local calendar date', () {
    final day = BusinessDayModel(
      id: 'day-1',
      restaurantId: 'snack_burger',
      slug: 'snack_burger',
      status: 'open',
      openedAt: DateTime(2024, 6, 4, 1, 30),
    );

    expect(
      BusinessDayScope.reportDateFor(day),
      DateTime(2024, 6, 4),
    );
  });

  test('orderBelongsToBusinessDay matches ids only', () {
    expect(
      BusinessDayScope.orderBelongsToBusinessDay(
        orderBusinessDayId: 'abc',
        businessDayId: 'abc',
      ),
      isTrue,
    );
    expect(
      BusinessDayScope.orderBelongsToBusinessDay(
        orderBusinessDayId: null,
        businessDayId: 'abc',
      ),
      isFalse,
    );
    expect(
      BusinessDayScope.orderBelongsToBusinessDay(
        orderBusinessDayId: 'old',
        businessDayId: 'new',
      ),
      isFalse,
    );
  });
}
