import 'package:flutter/foundation.dart';

import 'customer_order_session.dart';

/// يتتبّع جلسة الزبون: رقم الهاتف وآخر طلب (لكل مطعم).
class CustomerLastOrderNotifier extends ChangeNotifier {
  CustomerLastOrderNotifier({required this.slug}) {
    refresh();
  }

  final String slug;
  String? _orderId;
  String? _phone;
  bool _loaded = false;

  String? get orderId => _orderId;
  String? get customerPhone => _phone;
  bool get hasOrder => _orderId != null && _orderId!.isNotEmpty;
  bool get hasPhone => _phone != null && _phone!.isNotEmpty;
  bool get canOpenMyOrders => hasPhone;
  bool get isLoaded => _loaded;

  Future<void> refresh() async {
    _orderId = await CustomerOrderSession.getLastOrderId(slug);
    _phone = await CustomerOrderSession.getCustomerPhone(slug);
    _loaded = true;
    notifyListeners();
  }

  Future<void> recordOrder({
    required String orderId,
    required String phoneNumber,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedPhone = phoneNumber.trim();
    if (normalizedOrderId.isNotEmpty) {
      await CustomerOrderSession.saveLastOrderId(
        slug: slug,
        orderId: normalizedOrderId,
      );
      _orderId = normalizedOrderId;
    }
    if (normalizedPhone.isNotEmpty) {
      await CustomerOrderSession.saveCustomerPhone(
        slug: slug,
        phoneNumber: normalizedPhone,
      );
      _phone = normalizedPhone;
    }
    _loaded = true;
    notifyListeners();
  }
}
