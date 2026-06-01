import 'package:flutter/foundation.dart';

import '../models/order_model.dart';
import '../models/product_model.dart';

/// سلة مشتريات المستأجر الحالي.
class CartNotifier extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList(growable: false);

  int get itemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice =>
      _items.values.fold(0.0, (sum, item) => sum + item.lineTotal);

  int quantityFor(String productId) =>
      _items.values
          .where((item) => item.productId == productId)
          .fold(0, (sum, item) => sum + item.quantity);

  void addProduct(
    ProductModel product, {
    List<CartItemAddon> selectedAddons = const [],
  }) {
    final unitPrice =
        product.price + selectedAddons.fold(0.0, (sum, addon) => sum + addon.lineTotal);
    final lineId = _buildLineId(product.id, selectedAddons);
    final existing = _items[lineId];
    if (existing != null) {
      _items[lineId] = CartItem(
        lineId: existing.lineId,
        productId: existing.productId,
        name: existing.name,
        quantity: existing.quantity + 1,
        baseUnitPrice: existing.baseUnitPrice,
        unitPrice: existing.unitPrice,
        selectedAddons: existing.selectedAddons,
      );
    } else {
      _items[lineId] = CartItem(
        lineId: lineId,
        productId: product.id,
        name: product.name,
        quantity: 1,
        baseUnitPrice: product.price,
        unitPrice: unitPrice,
        selectedAddons: List<CartItemAddon>.unmodifiable(selectedAddons),
      );
    }
    notifyListeners();
  }

  void increment(String lineId) {
    final existing = _items[lineId];
    if (existing == null) return;
    _items[lineId] = CartItem(
      lineId: existing.lineId,
      productId: existing.productId,
      name: existing.name,
      quantity: existing.quantity + 1,
      baseUnitPrice: existing.baseUnitPrice,
      unitPrice: existing.unitPrice,
      selectedAddons: existing.selectedAddons,
    );
    notifyListeners();
  }

  void decrement(String lineId) {
    final existing = _items[lineId];
    if (existing == null) return;
    if (existing.quantity <= 1) {
      _items.remove(lineId);
    } else {
      _items[lineId] = CartItem(
        lineId: existing.lineId,
        productId: existing.productId,
        name: existing.name,
        quantity: existing.quantity - 1,
        baseUnitPrice: existing.baseUnitPrice,
        unitPrice: existing.unitPrice,
        selectedAddons: existing.selectedAddons,
      );
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// تصفير السلة بعد إتمام الطلب.
  void clearCart() => clear();

  void incrementAddon(String lineId, int addonIndex) {
    _updateAddonQuantity(lineId, addonIndex, delta: 1);
  }

  void decrementAddon(String lineId, int addonIndex) {
    _updateAddonQuantity(lineId, addonIndex, delta: -1);
  }

  void _updateAddonQuantity(String lineId, int addonIndex, {required int delta}) {
    final existing = _items[lineId];
    if (existing == null) return;
    if (addonIndex < 0 || addonIndex >= existing.selectedAddons.length) return;

    final nextAddons = existing.selectedAddons.toList(growable: true);
    final currentAddon = nextAddons[addonIndex];
    final nextQty = currentAddon.quantity + delta;
    if (nextQty <= 0) {
      nextAddons.removeAt(addonIndex);
    } else {
      nextAddons[addonIndex] = currentAddon.copyWith(quantity: nextQty);
    }

    final nextUnitPrice = existing.baseUnitPrice +
        nextAddons.fold<double>(0, (sum, addon) => sum + addon.lineTotal);
    final nextLineId = _buildLineId(existing.productId, nextAddons);

    _items.remove(lineId);
    final duplicate = _items[nextLineId];
    if (duplicate != null) {
      _items[nextLineId] = CartItem(
        lineId: duplicate.lineId,
        productId: duplicate.productId,
        name: duplicate.name,
        quantity: duplicate.quantity + existing.quantity,
        baseUnitPrice: duplicate.baseUnitPrice,
        unitPrice: duplicate.unitPrice,
        selectedAddons: duplicate.selectedAddons,
      );
    } else {
      _items[nextLineId] = CartItem(
        lineId: nextLineId,
        productId: existing.productId,
        name: existing.name,
        quantity: existing.quantity,
        baseUnitPrice: existing.baseUnitPrice,
        unitPrice: nextUnitPrice,
        selectedAddons: List<CartItemAddon>.unmodifiable(nextAddons),
      );
    }
    notifyListeners();
  }

  String _buildLineId(String productId, List<CartItemAddon> addons) {
    if (addons.isEmpty) return productId;
    final normalized = addons
        .map(
          (e) =>
              '${e.name.trim().toLowerCase()}:${e.price.toStringAsFixed(2)}:q${e.quantity}',
        )
        .toList()
      ..sort();
    return '$productId|${normalized.join('|')}';
  }
}
