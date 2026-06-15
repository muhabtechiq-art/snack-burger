import 'package:flutter/foundation.dart';

import '../core/utils/price_utils.dart';
import '../core/theme/tenant_palette.dart';
import '../core/utils/model_parse_validation.dart';

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
    this.variants = const [],
    this.variantsSource,
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
  final List<ProductVariant> variants;

  /// مصدر الأحجام عند الجلب: `jsonb` أو `table` (للتشخيص في واجهة الزبون).
  final String? variantsSource;
  final bool isAvailable;
  final DateTime createdAt;

  bool get hasAddons => addons.isNotEmpty;

  bool get hasVariants => variants.isNotEmpty;

  /// يحتاج المودال عند وجود أحجام أو إضافات.
  bool get requiresConfiguration => hasVariants || hasAddons;

  /// سعر العرض في القائمة — أقل حجم أو السعر الثابت.
  double get displayPrice {
    if (!hasVariants) return price;
    return variants.map((v) => v.price).reduce(
          (a, b) => a < b ? a : b,
        );
  }

  /// السعر الأساسي للوجبة حسب الحجم المختار (إن وُجد).
  double resolveBasePrice({ProductVariant? selectedVariant}) {
    if (hasVariants) {
      return selectedVariant?.price ?? variants.first.price;
    }
    return price;
  }

  ProductModel copyWith({
    List<ProductVariant>? variants,
    String? variantsSource,
  }) {
    return ProductModel(
      id: id,
      restaurantId: restaurantId,
      name: name,
      description: description,
      price: price,
      imageUrl: imageUrl,
      category: category,
      addons: addons,
      variants: variants ?? this.variants,
      variantsSource: variantsSource ?? this.variantsSource,
      isAvailable: isAvailable,
      createdAt: createdAt,
    );
  }

  /// خريطة جاهزة للحفظ في Supabase
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
      'variants': variants.map((e) => e.toMap()).toList(),
      if (variantsSource != null) 'variantsSource': variantsSource,
      'isAvailable': isAvailable,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    _validateMandatoryFields(map);
    return ProductModel(
      id: map['id'] as String? ?? '',
      restaurantId: (map['restaurantId'] ?? map['restaurant_id'] ?? '') as String? ?? '',
      name: readStringField(map, ['name', 'title', 'productName']) ?? '',
      description: map['description'] as String?,
      price: _readDouble(map['price']),
      imageUrl: readStringField(map, [
        'imageUrl',
        'image',
        'imageURL',
        'photoUrl',
        'photo',
      ]),
      category: map['category'] as String? ?? 'general',
      addons: ProductAddon.listFromDynamic(map['addons']),
      variants: ProductVariant.deduplicate(
        ProductVariant.listFromDynamic(map['variants']),
      ),
      variantsSource: map['variantsSource'] as String?,
      isAvailable: map['isAvailable'] as bool? ?? true,
      createdAt: parseModelDate(map['createdAt'] ?? map['created_at']),
    );
  }

  static void _validateMandatoryFields(Map<String, dynamic> map) {
    ModelParseValidation.warnMissingFields(
      modelName: 'ProductModel',
      source: map,
      missingFields: ModelParseValidation.collectMissing(
        map,
        const {
          'id': ['id'],
          'name': ['name', 'title', 'productName'],
          'restaurant_id': ['restaurantId', 'restaurant_id'],
          'created_at': ['createdAt', 'created_at'],
        },
      ),
    );
  }
}

class ProductVariant {
  const ProductVariant({
    this.id,
    required this.name,
    required this.price,
  });

  final String? id;
  final String name;
  final double price;

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'name': name,
        'price': PriceUtils.normalizePrice(price),
      };

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: _readOptionalId(map),
      name: _readVariantName(map),
      price: _readDouble(
        map['price'] ?? map['unit_price'] ?? map['amount'] ?? map['cost'],
      ),
    );
  }

  static String? _readOptionalId(Map<String, dynamic> map) {
    final raw = map['id'];
    if (raw == null) return null;
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// يزيل التكرار — أولاً حسب [id]، ثم حسب الاسم + السعر.
  static List<ProductVariant> deduplicate(List<ProductVariant> raw) {
    if (raw.length <= 1) return List<ProductVariant>.from(raw);

    final seenIds = <String>{};
    final seenKeys = <String>{};
    final result = <ProductVariant>[];

    for (final variant in raw) {
      final id = variant.id?.trim();
      if (id != null && id.isNotEmpty) {
        if (!seenIds.add(id)) continue;
        result.add(variant);
        continue;
      }

      final key =
          '${variant.name.trim().toLowerCase()}|'
          '${PriceUtils.normalizedPriceKey(variant.price)}';
      if (!seenKeys.add(key)) continue;
      result.add(
        ProductVariant(
          id: variant.id,
          name: variant.name,
          price: PriceUtils.normalizePriceAsDouble(variant.price),
        ),
      );
    }

    return result;
  }

  /// يزيل التكرار — يُسجّل في debug فقط عند وجود تكرار فعلي.
  static List<ProductVariant> deduplicateForProduct({
    required String productId,
    required List<ProductVariant> raw,
  }) {
    if (raw.isEmpty) return const [];

    final deduped = deduplicate(raw);
    if (kDebugMode && raw.length != deduped.length) {
      debugPrint(
        '[ProductVariants] productId=$productId '
        'fromSupabase=${raw.length} afterDedup=${deduped.length}',
      );
    }
    return deduped;
  }

  /// مفتاح التكرار: product_id + name + price (يُستخدم في التنظيف).
  static String duplicateGroupKey({
    required String name,
    required double price,
  }) {
    return '${name.trim().toLowerCase()}|${PriceUtils.normalizedPriceKey(price)}';
  }

  static String _readVariantName(Map<String, dynamic> map) {
    for (final key in [
      'name',
      'label',
      'size_name',
      'variant_name',
      'size',
      'title',
      'variant',
    ]) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static List<ProductVariant> listFromDynamic(dynamic raw) {
    if (raw is! List) return const [];
    final parsed = <ProductVariant>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        final variant = ProductVariant.fromMap(entry);
        if (variant.name.isNotEmpty) parsed.add(variant);
      } else if (entry is Map) {
        final variant = ProductVariant.fromMap(Map<String, dynamic>.from(entry));
        if (variant.name.isNotEmpty) parsed.add(variant);
      }
    }
    return parsed;
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
        'price': PriceUtils.normalizePrice(price),
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

double _readDouble(dynamic v) => PriceUtils.normalizePriceAsDouble(v);

/// يدعم `String` (ISO)، `int` (ms)، و Timestamp من JSONB عند تمرير خريطة بعد التحويل في المستودع.
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
