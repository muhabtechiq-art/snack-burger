import 'product_model.dart' show parseModelDate;

import '../core/utils/model_parse_validation.dart';

/// بانر ترويجي في المنيو — صف من جدول `banners`.
class PromoBannerModel {
  const PromoBannerModel({
    required this.id,
    required this.restaurantId,
    required this.imageUrl,
    required this.title,
    required this.isActive,
    this.sortOrder = 0,
    required this.createdAt,
  });

  final String id;
  final String restaurantId;
  final String imageUrl;
  final String title;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  PromoBannerModel copyWith({
    String? id,
    String? restaurantId,
    String? imageUrl,
    String? title,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return PromoBannerModel(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'restaurant_id': restaurantId,
      'image_url': imageUrl,
      'title': title.trim(),
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'image_url': imageUrl,
      'title': title.trim(),
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }

  static PromoBannerModel fromSupabase(Map<String, dynamic> data) {
    _validateMandatoryFields(data);
    return PromoBannerModel(
      id: data['id']?.toString() ?? '',
      restaurantId: (data['restaurant_id'] ?? data['restaurantId'] ?? '')
          .toString()
          .trim(),
      imageUrl: (data['image_url'] ?? data['imageUrl'] ?? '').toString().trim(),
      title: (data['title'] ?? '').toString().trim(),
      isActive: _readBool(data['is_active'] ?? data['isActive']),
      sortOrder: _readInt(data['sort_order'] ?? data['sortOrder']),
      createdAt: parseModelDate(data['created_at'] ?? data['createdAt']),
    );
  }

  static void _validateMandatoryFields(Map<String, dynamic> data) {
    ModelParseValidation.warnMissingFields(
      modelName: 'PromoBannerModel',
      source: data,
      missingFields: ModelParseValidation.collectMissing(
        data,
        const {
          'id': ['id'],
          'restaurant_id': ['restaurant_id', 'restaurantId'],
          'image_url': ['image_url', 'imageUrl'],
          'title': ['title'],
          'created_at': ['created_at', 'createdAt'],
        },
      ),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(dynamic value, {bool defaultValue = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return defaultValue;
  }
}
