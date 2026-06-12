import '../core/theme/tenant_palette.dart';
import '../core/utils/model_parse_validation.dart';

/// بيانات المطعم (مستأجر / جدول Supabase: `restaurants`).
class RestaurantModel {
  const RestaurantModel({
    required this.id,
    required this.slug,
    required this.name,
    this.logoUrl,
    this.bannerUrl,
    required this.primaryColorHex,
    required this.accentColorHex,
    this.whatsappNumber,
    this.orderRoutingMode = 'whatsapp',
    this.isActive = true,
  });

  /// معرف المطعم في Supabase.
  final String id;

  /// المعرف في المسار، مثل `snack_burger` في `/#/snack_burger`.
  final String slug;

  final String name;
  final String? logoUrl;
  final String? bannerUrl;

  /// لون أساسي، مثال: `#8B0000`.
  final String primaryColorHex;

  /// لون مميز، مثال: `#E1AD01`.
  final String accentColorHex;

  final String? whatsappNumber;

  /// وضع توجيه الطلبات (سلسلة مرنة: whatsapp, dashboard, webhook, ...).
  final String orderRoutingMode;

  final bool isActive;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'slug': slug,
      'username': slug,
      'name': name,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'primaryColor': primaryColorHex,
      'accentColor': accentColorHex,
      'whatsappNumber': whatsappNumber,
      'orderRoutingMode': orderRoutingMode,
      'isActive': isActive,
    };
  }

  factory RestaurantModel.fromMap(Map<String, dynamic> map) {
    _validateMandatoryFields(map);
    final slug = (map['slug'] ?? map['username'] ?? '') as String;
    return RestaurantModel(
      id: map['id']?.toString() ?? '',
      slug: slug,
      name: map['name'] as String? ?? '',
      logoUrl: readStringField(map, [
        'logoUrl',
        'logo_url',
        'logo',
        'logoURL',
      ]),
      bannerUrl: readStringField(map, [
        'bannerUrl',
        'banner_url',
        'bannerImage',
        'banner',
        'coverUrl',
        'coverImage',
      ]),
      primaryColorHex: readMapColorField(map, [
            'primaryColor',
            'primary_color',
            'primaryColorHex',
          ]) ??
          '#8B0000',
      accentColorHex: readMapColorField(map, [
            'accentColor',
            'accent_color',
            'accentColorHex',
            'secondaryColor',
          ]) ??
          '#E1AD01',
      whatsappNumber: readStringField(map, [
        'whatsappNumber',
        'whatsapp_number',
      ]),
      orderRoutingMode:
          readStringField(map, ['orderRoutingMode', 'order_routing_mode']) ??
              'whatsapp',
      isActive: map['isActive'] as bool? ?? map['is_active'] as bool? ?? true,
    );
  }

  static void _validateMandatoryFields(Map<String, dynamic> map) {
    final missing = ModelParseValidation.collectMissing(
      map,
      const {
        'id': ['id'],
        'slug': ['slug', 'username'],
        'name': ['name'],
      },
    );
    if (!ModelParseValidation.hasAnyValue(map, [
      'primaryColor',
      'primary_color',
      'primaryColorHex',
    ])) {
      missing.add('primary_color');
    }
    if (!ModelParseValidation.hasAnyValue(map, [
      'accentColor',
      'accent_color',
      'accentColorHex',
      'secondaryColor',
    ])) {
      missing.add('accent_color');
    }
    ModelParseValidation.warnMissingFields(
      modelName: 'RestaurantModel',
      source: map,
      missingFields: missing,
    );
  }

  RestaurantModel copyWith({
    String? id,
    String? slug,
    String? name,
    String? logoUrl,
    String? bannerUrl,
    String? primaryColorHex,
    String? accentColorHex,
    String? whatsappNumber,
    String? orderRoutingMode,
    bool? isActive,
  }) {
    return RestaurantModel(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      orderRoutingMode: orderRoutingMode ?? this.orderRoutingMode,
      isActive: isActive ?? this.isActive,
    );
  }
}
