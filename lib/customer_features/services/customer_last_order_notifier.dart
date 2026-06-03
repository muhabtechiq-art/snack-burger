import 'package:flutter/foundation.dart';

import 'customer_order_session.dart';

/// يتتبّع وجود طلب حديث للزبون في جلسة المتصفح/الجهاز.
class CustomerLastOrderNotifier extends ChangeNotifier {
  CustomerLastOrderNotifier({required this.slug}) {
    refresh();
  }

  final String slug;
  String? _orderId;
  bool _loaded = false;

  String? get orderId => _orderId;
  bool get hasOrder => _orderId != null && _orderId!.isNotEmpty;
  bool get isLoaded => _loaded;

  Future<void> refresh() async {
    _orderId = await CustomerOrderSession.getLastOrderId(slug);
    _loaded = true;
    notifyListeners();
  }

  Future<void> recordOrder(String orderId) async {
    await CustomerOrderSession.saveLastOrderId(slug: slug, orderId: orderId);
    _orderId = orderId.trim();
    _loaded = true;
    notifyListeners();
  }
}
