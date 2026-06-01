import 'product_model.dart' show parseModelDate;

/// حالة الطلب.
enum OrderStatus {
  pending,
  accepted,
  completed,
  rejected;

  static OrderStatus fromString(String? raw) {
    switch (raw) {
      case 'accepted':
        return OrderStatus.accepted;
      case 'completed':
        return OrderStatus.completed;
      case 'rejected':
        return OrderStatus.rejected;
      default:
        return OrderStatus.pending;
    }
  }

  String get asFirestoreValue => name;
}

class CartItem {
  const CartItem({
    required this.lineId,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.baseUnitPrice,
    required this.unitPrice,
    this.selectedAddons = const [],
  });

  final String lineId;
  final String productId;
  final String name;
  final int quantity;
  final double baseUnitPrice;
  final double unitPrice;
  final List<CartItemAddon> selectedAddons;

  String get addonsLabel => selectedAddons.map((e) => e.name).join('، ');
  String get addonsSummary =>
      selectedAddons.map((e) => '${e.name} x${e.quantity}').join('، ');
  String get printableName =>
      selectedAddons.isEmpty ? name : '$name (+$addonsSummary)';

  double get lineTotal => quantity * unitPrice;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'lineId': lineId,
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'baseUnitPrice': baseUnitPrice,
        'unitPrice': unitPrice,
        'selectedAddons': selectedAddons.map((e) => e.toMap()).toList(),
        'addons': selectedAddons.map((e) => e.toMap()).toList(),
      };

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      lineId: map['lineId'] as String? ?? (map['productId'] as String? ?? ''),
      productId: map['productId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      baseUnitPrice:
          (map['baseUnitPrice'] as num?)?.toDouble() ??
          (map['unitPrice'] as num?)?.toDouble() ??
          0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      selectedAddons: CartItemAddon.listFromDynamic(
        map['selectedAddons'] ?? map['addons'] ?? map['add_ons'],
      ),
    );
  }
}

class CartItemAddon {
  const CartItemAddon({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  final String name;
  final double price;
  final int quantity;

  double get lineTotal => price * quantity;

  CartItemAddon copyWith({
    String? name,
    double? price,
    int? quantity,
  }) {
    return CartItemAddon(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'price': price,
        'quantity': quantity,
      };

  factory CartItemAddon.fromMap(Map<String, dynamic> map) {
    return CartItemAddon(
      name: (map['name'] as String? ?? '').trim(),
      price: (map['price'] as num?)?.toDouble() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  static List<CartItemAddon> listFromDynamic(dynamic raw) {
    if (raw is! List) return const [];
    final parsed = <CartItemAddon>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        final addon = CartItemAddon.fromMap(entry);
        if (addon.name.isNotEmpty) parsed.add(addon);
      } else if (entry is Map) {
        final addon = CartItemAddon.fromMap(Map<String, dynamic>.from(entry));
        if (addon.name.isNotEmpty) parsed.add(addon);
      }
    }
    return parsed;
  }
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.restaurantId,
    required this.tableNumber,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.orderTime,
  });

  final String id;
  final String restaurantId;
  final String tableNumber;
  final List<CartItem> items;
  final double totalPrice;
  final OrderStatus status;
  final DateTime orderTime;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'restaurantId': restaurantId,
      'tableNumber': tableNumber,
      'items': items.map((e) => e.toMap()).toList(),
      'totalPrice': totalPrice,
      'status': status.asFirestoreValue,
      'orderTime': orderTime.toUtc().toIso8601String(),
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    final items = <CartItem>[];
    if (rawItems is List) {
      for (final e in rawItems) {
        if (e is Map<String, dynamic>) items.add(CartItem.fromMap(e));
        if (e is Map) items.add(CartItem.fromMap(Map<String, dynamic>.from(e)));
      }
    }
    return OrderModel(
      id: map['id'] as String? ?? '',
      restaurantId: map['restaurantId'] as String? ?? '',
      tableNumber: map['tableNumber'] as String? ?? '',
      items: items,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0,
      status: OrderStatus.fromString(map['status'] as String?),
      orderTime: parseModelDate(map['orderTime']),
    );
  }
}
