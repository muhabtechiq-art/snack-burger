import 'product_model.dart' show parseModelDate;

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
    return PromoBannerModel(
      id: data['id']?.toString() ?? '',
      restaurantId: (data['restaurant_id'] ?? data['restaurantId'] ?? '')
          .toString()
          .trim(),
      imageUrl: (data['image_url'] ?? data['imageUrl'] ?? '').toString().trim(),
      title: (data['title'] ?? '').toString().trim(),
      isActive: data['is_active'] == true || data['isActive'] == true,
      sortOrder: _readInt(data['sort_order'] ?? data['sortOrder']),
      createdAt: parseModelDate(data['created_at'] ?? data['createdAt']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
