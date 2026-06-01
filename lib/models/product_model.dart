import '../core/theme/tenant_palette.dart';

/// منتج مرتبط دائماً بمطعم واحد (`restaurantId`).
class ProductModel {
  const ProductModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    required this.category,
    this.addons = const [],
    this.isAvailable = true,
    required this.createdAt,
  });

  final String id;
  final String restaurantId;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final String category;
  final List<ProductAddon> addons;
  final bool isAvailable;
  final DateTime createdAt;

  bool get hasAddons => addons.isNotEmpty;

  /// خريطة جاهزة للحفظ في Firestore (يُفضَّل تخزين `createdAt` كـ Timestamp في الطبقة الخدمية).
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'addons': addons.map((e) => e.toMap()).toList(),
      'isAvailable': isAvailable,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String? ?? '',
      restaurantId: (map['restaurantId'] ?? map['restaurant_id'] ?? '') as String? ?? '',
      name: readFirestoreStringField(map, ['name', 'title', 'productName']) ?? '',
      description: map['description'] as String?,
      price: _readDouble(map['price']),
      imageUrl: readFirestoreStringField(map, [
        'imageUrl',
        'image',
        'imageURL',
        'photoUrl',
        'photo',
      ]),
      category: map['category'] as String? ?? 'general',
      addons: ProductAddon.listFromDynamic(map['addons']),
      isAvailable: map['isAvailable'] as bool? ?? true,
      createdAt: parseModelDate(map['createdAt']),
    );
  }
}

class ProductAddon {
  const ProductAddon({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  final String name;
  final double price;
  final int quantity;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'price': price,
        'quantity': quantity,
      };

  factory ProductAddon.fromMap(Map<String, dynamic> map) {
    return ProductAddon(
      name: (map['name'] as String? ?? '').trim(),
      price: _readDouble(map['price']),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  static List<ProductAddon> listFromDynamic(dynamic raw) {
    if (raw is! List) return const [];
    final parsed = <ProductAddon>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        final addon = ProductAddon.fromMap(entry);
        if (addon.name.isNotEmpty) parsed.add(addon);
      } else if (entry is Map) {
        final addon = ProductAddon.fromMap(Map<String, dynamic>.from(entry));
        if (addon.name.isNotEmpty) parsed.add(addon);
      }
    }
    return parsed;
  }
}

double _readDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

/// يدعم `String` (ISO)، `int` (ms)، و Firestore [Timestamp] عند تمرير خريطة بعد التحويل في المستودع.
DateTime parseModelDate(dynamic v) {
  if (v == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  if (v is DateTime) return v;
  if (v is String) {
    return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
  try {
    final dynamic ts = v;
    final sec = ts.seconds;
    final nan = ts.nanoseconds;
    if (sec is int && nan is int) {
      return DateTime.fromMillisecondsSinceEpoch(sec * 1000 + nan ~/ 1000000, isUtc: true);
    }
  } catch (_) {}
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
