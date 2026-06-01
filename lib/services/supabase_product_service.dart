import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/product_id_generator.dart';
import '../models/product_model.dart';

/// منتجات المنيو — جدول `products` + `product_addons` في Supabase.
abstract final class SupabaseProductService {
  SupabaseProductService._();

  static const String tableName = 'products';
  static const String addonsTableName = 'product_addons';

  static const String defaultRestaurantId = 'snack_burger';

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<ProductModel>> fetchProducts({
    String? restaurantId,
  }) async {
    try {
      debugPrint('[SupabaseProductService] جلب المنتجات من $tableName...');
      final rows = await _client.from(tableName).select();
      final products = _parseAndFilter(rows, restaurantId);
      return _attachAddonsToProducts(products);
    } catch (e, stack) {
      debugPrint('[SupabaseProductService] fetchProducts فشل: $e\n$stack');
      rethrow;
    }
  }

  static Stream<List<ProductModel>> watchProducts({
    String? restaurantId,
  }) {
    return _client
        .from(tableName)
        .stream(primaryKey: const ['id'])
        .asyncMap((rows) async {
          final products = _parseAndFilter(rows, restaurantId);
          return _attachAddonsToProducts(products);
        })
        .asBroadcastStream();
  }

  static Future<List<String>> fetchDistinctCategories({
    String? restaurantId,
  }) async {
    final products = await fetchProducts(restaurantId: restaurantId);
    final categories = <String>{};
    for (final product in products) {
      final label = product.category.trim();
      if (label.isEmpty || label.toLowerCase() == 'general') continue;
      categories.add(label);
    }
    return categories.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  static Future<ProductModel?> fetchProductById(String productId) async {
    if (productId.trim().isEmpty) return null;

    try {
      final row = await _client
          .from(tableName)
          .select()
          .eq('id', productId)
          .maybeSingle();
      if (row == null) return null;

      final product = _mapRowToProduct(Map<String, dynamic>.from(row));
      if (product == null) return null;

      final withAddons = await _attachAddonsToProducts([product]);
      return withAddons.isEmpty ? product : withAddons.first;
    } catch (e, stack) {
      debugPrint('[SupabaseProductService] fetchProductById فشل: $e\n$stack');
      rethrow;
    }
  }

  static Future<String> saveProduct({
    required ProductModel product,
    String? imageUrl,
  }) async {
    final id = product.id.trim().isNotEmpty
        ? product.id.trim()
        : ProductIdGenerator.newId();
    final resolvedImageUrl = _resolveImageUrlForSave(
      explicitUrl: imageUrl,
      fallbackUrl: product.imageUrl,
    );

    final restaurantId = product.restaurantId.trim().isNotEmpty
        ? product.restaurantId.trim()
        : defaultRestaurantId;

    await _assertNoDuplicateProduct(
      restaurantId: restaurantId,
      name: product.name.trim(),
      price: product.price,
      excludeProductId: id,
    );

    final payload = _buildProductSavePayload(
      id: id,
      product: product,
      resolvedImageUrl: resolvedImageUrl,
      restaurantId: restaurantId,
    );

    try {
      final savedId = await _trySaveViaRpc(
        payload: payload,
        addons: product.addons,
      );
      debugPrint(
        '[SupabaseProductService] تم حفظ المنتج (RPC): $savedId '
        'addons=${product.addons.length}',
      );
      return savedId;
    } on PostgrestException catch (e) {
      if (!_isRpcUnavailable(e)) rethrow;
      debugPrint(
        '[SupabaseProductService] RPC غير متاح — fallback محلي: ${e.message}',
      );
    }

    return _saveProductWithClientRollback(
      payload: payload,
      addons: product.addons,
      resolvedImageUrl: resolvedImageUrl,
    );
  }

  /// payload المنتج — منفصل عن الإضافات؛ لا يُغيّر حقول الحفظ الأساسية.
  static Map<String, dynamic> _buildProductSavePayload({
    required String id,
    required ProductModel product,
    required String? resolvedImageUrl,
    required String restaurantId,
  }) {
    return <String, dynamic>{
      'id': ProductIdGenerator.serializeForSupabase(id),
      'name': product.name.trim(),
      'price': product.price,
      'description': product.description,
      'category': product.category.trim().isNotEmpty
          ? product.category.trim()
          : 'general',
      'image_url': resolvedImageUrl,
      'restaurant_id': restaurantId,
    };
  }

  static List<Map<String, dynamic>> _serializeAddonsForSave(
    List<ProductAddon> addons,
  ) {
    return addons
        .where((addon) => addon.name.trim().isNotEmpty)
        .map(
          (addon) => <String, dynamic>{
            'name': addon.name.trim(),
            'price': addon.price,
          },
        )
        .toList(growable: false);
  }

  static bool _isRpcUnavailable(PostgrestException error) {
    if (error.code == 'PGRST202') return true;
    final message = error.message.toLowerCase();
    return message.contains('save_product_with_addons') ||
        message.contains('could not find the function');
  }

  /// Transaction حقيقية عبر PostgreSQL RPC.
  static Future<String> _trySaveViaRpc({
    required Map<String, dynamic> payload,
    required List<ProductAddon> addons,
  }) async {
    final result = await _client.rpc(
      'save_product_with_addons',
      params: {
        'p_product': payload,
        'p_addons': _serializeAddonsForSave(addons),
      },
    );
    final savedId = _asString(result);
    if (savedId.isEmpty) {
      throw StateError('RPC save_product_with_addons returned empty id');
    }
    return savedId;
  }

  /// fallback: حفظ المنتج مرة واحدة ثم الإضافات؛ Rollback بحذف المنتج الجديد فقط.
  static Future<String> _saveProductWithClientRollback({
    required Map<String, dynamic> payload,
    required List<ProductAddon> addons,
    required String? resolvedImageUrl,
  }) async {
    final serializedId = payload['id'];
    final isNewProduct = await _productExists(serializedId) == false;

    try {
      final row = await _client
          .from(tableName)
          .upsert(payload)
          .select('id')
          .single();

      final savedId = row['id']?.toString() ?? _asString(serializedId);
      if (savedId.isEmpty) {
        throw StateError('Missing product id after save');
      }

      try {
        await _saveProductAddons(
          productId: savedId,
          addons: addons,
          skipDelete: isNewProduct,
        );
      } catch (addonError) {
        if (isNewProduct) {
          await _rollbackNewProduct(savedId);
        }
        rethrow;
      }

      debugPrint(
        '[SupabaseProductService] تم حفظ المنتج: $savedId '
        'image_url=$resolvedImageUrl addons=${addons.length}',
      );
      return savedId;
    } catch (e, stack) {
      debugPrint('[SupabaseProductService] saveProduct فشل: $e\n$stack');
      rethrow;
    }
  }

  static Future<bool> _productExists(dynamic productId) async {
    if (productId == null) return false;
    final row = await _client
        .from(tableName)
        .select('id')
        .eq('id', productId)
        .maybeSingle();
    return row != null;
  }

  static Future<void> _rollbackNewProduct(String productId) async {
    try {
      await _client
          .from(tableName)
          .delete()
          .eq('id', ProductIdGenerator.serializeForSupabase(productId));
      debugPrint('[SupabaseProductService] Rollback: حُذف المنتج $productId');
    } catch (e, stack) {
      debugPrint('[SupabaseProductService] Rollback failed: $e\n$stack');
    }
  }

  static Future<void> deleteProduct(String productId) async {
    final id = productId.trim();
    if (id.isEmpty) {
      throw ArgumentError('productId is required');
    }

    try {
      await _client.from(tableName).delete().eq('id', id);
      debugPrint('[SupabaseProductService] تم حذف المنتج: $id');
    } catch (e, stack) {
      debugPrint('[SupabaseProductService] deleteProduct فشل: $e\n$stack');
      rethrow;
    }
  }

  static Future<void> _assertNoDuplicateProduct({
    required String restaurantId,
    required String name,
    required double price,
    required String excludeProductId,
  }) async {
    if (name.isEmpty) return;

    try {
      final rows = await _client
          .from(tableName)
          .select('id')
          .eq('restaurant_id', restaurantId)
          .eq('name', name)
          .eq('price', price);

      for (final entry in rows) {
        final map = Map<String, dynamic>.from(entry as Map);
        final existingId = _asString(map['id']);
        if (existingId.isEmpty) continue;
        if (existingId == excludeProductId) continue;

        throw PostgrestException(
          message: 'duplicate_product',
          code: '23505',
        );
      }
    } on PostgrestException {
      rethrow;
    } catch (e, stack) {
      debugPrint('[SupabaseProductService] duplicate check failed: $e\n$stack');
      // لا نمنع الحفظ إذا فشل فحص التكرار لسبب تقني.
    }
  }

  /// يستبدل إضافات المنتج في `product_addons` بعد حفظ المنتج.
  static Future<void> _saveProductAddons({
    required String productId,
    required List<ProductAddon> addons,
    bool skipDelete = false,
  }) async {
    final serializedProductId =
        ProductIdGenerator.serializeForSupabase(productId);

    if (!skipDelete) {
      try {
        await _client
            .from(addonsTableName)
            .delete()
            .eq('product_id', serializedProductId);
      } on PostgrestException catch (e, st) {
        debugPrint(
          '[SupabaseProductService] delete addons فشل: ${e.code} ${e.message}\n$st',
        );
        if (e.code == '42501') {
          throw PostgrestException(
            message:
                'لا توجد صلاحية لحذف الإضافات — فعّل سياسات DELETE على product_addons',
            code: e.code,
            details: e.details,
            hint: e.hint,
          );
        }
        rethrow;
      }
    }

    final validAddons = addons
        .where((addon) => addon.name.trim().isNotEmpty)
        .toList(growable: false);

    if (validAddons.isEmpty) {
      debugPrint('[SupabaseProductService] لا إضافات لحفظها للمنتج $productId');
      return;
    }

    final rows = validAddons
        .map(
          (addon) => <String, dynamic>{
            'product_id': serializedProductId,
            'name': addon.name.trim(),
            'price': addon.price,
          },
        )
        .toList(growable: false);

    try {
      await _client.from(addonsTableName).insert(rows);
    } on PostgrestException catch (e, st) {
      debugPrint(
        '[SupabaseProductService] insert addons فشل: ${e.code} ${e.message}\n$st',
      );
      if (e.code == '42501') {
        throw PostgrestException(
          message:
              'لا توجد صلاحية لحفظ الإضافات — فعّل سياسات INSERT على product_addons',
          code: e.code,
          details: e.details,
          hint: e.hint,
        );
      }
      rethrow;
    }

    debugPrint(
      '[SupabaseProductService] حُفظت ${rows.length} إضافة للمنتج $productId',
    );
  }

  /// يُحمّل الإضافات من `product_addons` ويربطها بالمنتجات (للبث المباشر).
  static Future<List<ProductModel>> _attachAddonsToProducts(
    List<ProductModel> products,
  ) async {
    if (products.isEmpty) return products;

    final productIds = products.map((p) => p.id).where((id) => id.isNotEmpty).toList();
    if (productIds.isEmpty) return products;

    try {
      final rows = await _client
          .from(addonsTableName)
          .select()
          .inFilter(
            'product_id',
            productIds
                .map(ProductIdGenerator.serializeForSupabase)
                .toList(growable: false),
          );

      final addonsByProduct = _groupAddonsByProductId(rows);
      return products
          .map(
            (product) => ProductModel(
              id: product.id,
              restaurantId: product.restaurantId,
              name: product.name,
              description: product.description,
              price: product.price,
              imageUrl: product.imageUrl,
              category: product.category,
              addons: addonsByProduct[_asString(product.id)] ?? const [],
              isAvailable: product.isAvailable,
              createdAt: product.createdAt,
            ),
          )
          .toList(growable: false);
    } catch (e, stack) {
      debugPrint('[SupabaseProductService] _attachAddonsToProducts فشل: $e\n$stack');
      return products;
    }
  }

  static Map<String, List<ProductAddon>> _groupAddonsByProductId(dynamic rows) {
    final grouped = <String, List<ProductAddon>>{};
    if (rows is! List) return grouped;

    for (final entry in rows) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final productId = _asString(map['product_id']);
      if (productId.isEmpty) continue;

      final addon = ProductAddon.fromMap(map);
      if (addon.name.isEmpty) continue;

      grouped.putIfAbsent(productId, () => <ProductAddon>[]).add(addon);
    }

    for (final addons in grouped.values) {
      addons.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    return grouped;
  }

  static String? _resolveImageUrlForSave({
    required String? explicitUrl,
    required String? fallbackUrl,
  }) {
    for (final candidate in [explicitUrl, fallbackUrl]) {
      if (candidate == null) continue;
      final trimmed = candidate.trim();
      if (trimmed.isEmpty) continue;

      final lower = trimmed.toLowerCase();
      if (lower.contains('copied') || lower.contains('clipboard')) {
        continue;
      }
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
    }
    return null;
  }

  static List<ProductModel> _parseAndFilter(
    dynamic rows,
    String? restaurantId,
  ) {
    final rawRows = (rows as List<dynamic>).cast<Map<String, dynamic>>();
    debugPrint('[SupabaseProductService] ${rawRows.length} صفاً من Supabase');

    final products = rawRows
        .map(_mapRowToProduct)
        .whereType<ProductModel>()
        .toList(growable: false);

    return List<ProductModel>.unmodifiable(
      _filterByRestaurant(products, restaurantId),
    );
  }

  static List<ProductModel> _filterByRestaurant(
    List<ProductModel> products,
    String? restaurantId,
  ) {
    if (restaurantId == null || restaurantId.isEmpty) {
      return products;
    }
    return products.where((p) => p.restaurantId == restaurantId).toList();
  }

  static ProductModel? _mapRowToProduct(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);

    final id = _asString(normalized['id']);
    final name = _asString(normalized['name']);
    if (id.isEmpty || name.isEmpty) {
      return null;
    }

    if (_isExplicitlyUnavailable(normalized)) {
      return null;
    }

    final rowRestaurantId = _asString(
      normalized['restaurant_id'] ?? normalized['restaurantId'],
    );

    return ProductModel(
      id: id,
      restaurantId:
          rowRestaurantId.isNotEmpty ? rowRestaurantId : defaultRestaurantId,
      name: name,
      description: _nullableString(normalized['description']),
      price: _readDouble(normalized['price']),
      imageUrl: _nullableString(
        normalized['image_url'] ?? normalized['imageUrl'],
      ),
      category: _asString(normalized['category']).isNotEmpty
          ? _asString(normalized['category'])
          : 'general',
      addons: _parseAddonsFromRow(normalized),
      isAvailable: normalized['is_available'] as bool? ??
          normalized['isAvailable'] as bool? ??
          true,
      createdAt: parseModelDate(
        normalized['created_at'] ?? normalized['createdAt'],
      ),
    );
  }

  static List<ProductAddon> _parseAddonsFromRow(Map<String, dynamic> row) {
    final nested = row['product_addons'];
    if (nested is List && nested.isNotEmpty) {
      return ProductAddon.listFromDynamic(nested);
    }
    return ProductAddon.listFromDynamic(row['addons']);
  }

  static bool _isExplicitlyUnavailable(Map<String, dynamic> data) {
    if (data['is_available'] == false) return true;
    if (data['isAvailable'] == false) return true;
    if (data['available'] == false) return true;
    return false;
  }

  static String _asString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String? _nullableString(dynamic value) {
    final text = _asString(value);
    return text.isEmpty ? null : text;
  }

  static double _readDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
  }
}
