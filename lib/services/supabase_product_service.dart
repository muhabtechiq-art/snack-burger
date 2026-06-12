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
  static const String variantsTableName = 'product_variants';

  static const String defaultRestaurantId = 'snack_burger';

  static const Duration _streamReconnectBaseDelay = Duration(seconds: 1);
  static const Duration _streamReconnectMaxDelay = Duration(seconds: 20);

  /// استعلام منتجات مع join للإضافات والأحجام (PostgREST embed).
  static const String _selectWithRelations =
      '*, $addonsTableName(*), $variantsTableName(*)';

  static SupabaseClient get _client => Supabase.instance.client;

  /// يُحمّل الإضافات ثم الأحجام لقائمة منتجات (مسار مشترك للقراءة).
  /// عند [relationsEmbedded] يُفترض أن nested select ملأ addons/variants مسبقاً.
  static Future<List<ProductModel>> _enrichProductsWithRelations(
    List<ProductModel> products, {
    bool relationsEmbedded = false,
  }) async {
    List<ProductModel> enriched;
    if (relationsEmbedded) {
      enriched = products;
      debugPrint(
        '[SupabaseProductService] enrich: تخطّي جلب منفصل — '
        'embed موجود (${products.length} منتج)',
      );
    } else {
      enriched = await _attachVariantsToProducts(
        await _attachAddonsToProducts(products),
      );
    }
    final withVariants = enriched.where((product) => product.hasVariants).length;
    debugPrint(
      '[SupabaseProductService] enrich: ${enriched.length} منتج، '
      '$withVariants بأحجام',
    );
    return enriched;
  }

  static String _productIdKey(dynamic id) => _asString(id);

  static bool _productIdsMatch(String a, String b) {
    if (a == b) return true;
    final aInt = int.tryParse(a);
    final bInt = int.tryParse(b);
    return aInt != null && bInt != null && aInt == bInt;
  }

  static String _readVariantProductId(Map<String, dynamic> map) {
    for (final key in ['product_id', 'products_id', 'productId']) {
      final value = map[key];
      if (value == null) continue;
      final text = _productIdKey(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static List<ProductVariant>? _lookupVariantsForProduct(
    Map<String, List<ProductVariant>> grouped,
    String productId,
  ) {
    final key = _productIdKey(productId);
    final direct = grouped[key];
    if (direct != null && direct.isNotEmpty) return direct;

    for (final entry in grouped.entries) {
      if (_productIdsMatch(entry.key, key) && entry.value.isNotEmpty) {
        return entry.value;
      }
    }
    return null;
  }

  /// يجلب صفوف الأحجام — inFilter ثم fallback لجلب الكل ومطابقة محلية.
  static Future<List<dynamic>> _fetchVariantRowsForProductIds(
    List<String> productIds,
  ) async {
    final serialized = _serializedProductIds(productIds);
    debugPrint(
      '[SupabaseProductService] inFilter product_ids=$serialized raw=$productIds',
    );

    final filtered = await _client
        .from(variantsTableName)
        .select()
        .inFilter('product_id', serialized);

    final filteredRows = filtered as List;
    if (filteredRows.isNotEmpty) {
      return filteredRows;
    }

    debugPrint(
      '[SupabaseProductService] inFilter=0 — جلب كل product_variants '
      'للمطابقة المحلية',
    );

    final allRows = await _client.from(variantsTableName).select();
    final all = allRows as List;
    debugPrint(
      '[SupabaseProductService] إجمالي product_variants في الجدول=${all.length}',
    );

    for (final entry in all.take(5)) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      debugPrint(
        '  صف variant: product_id=${map['product_id']} '
        'name=${map['name'] ?? map['label'] ?? map['size']} '
        'keys=${map.keys.toList()}',
      );
    }

    if (all.isEmpty) return const [];

    final wanted = productIds.map(_productIdKey).toSet();
    return all.where((entry) {
      if (entry is! Map) return false;
      final map = Map<String, dynamic>.from(entry);
      final pid = _readVariantProductId(map);
      if (pid.isEmpty) return false;
      for (final id in wanted) {
        if (_productIdsMatch(pid, id)) return true;
      }
      return false;
    }).toList(growable: false);
  }

  static List<ProductVariant> _resolveVariantsForProduct({
    required ProductModel product,
    List<ProductVariant>? fromTable,
  }) {
    if (fromTable != null && fromTable.isNotEmpty) return fromTable;
    if (product.variants.isNotEmpty) return product.variants;
    return const [];
  }

  static List<String> _nonEmptyProductIds(List<ProductModel> products) {
    return products
        .map((product) => product.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  static List<dynamic> _serializedProductIds(List<String> productIds) {
    return productIds
        .map(ProductIdGenerator.serializeForSupabase)
        .where((id) => id != null)
        .toList(growable: false);
  }

  static ProductModel _copyProductRelations(
    ProductModel product, {
    List<ProductAddon>? addons,
    List<ProductVariant>? variants,
  }) {
    return ProductModel(
      id: product.id,
      restaurantId: product.restaurantId,
      name: product.name,
      description: product.description,
      price: product.price,
      imageUrl: product.imageUrl,
      category: product.category,
      addons: addons ?? product.addons,
      variants: variants ?? product.variants,
      isAvailable: product.isAvailable,
      createdAt: product.createdAt,
    );
  }

  static Future<List<ProductModel>> fetchProducts({
    String? restaurantId,
  }) async {
    try {
      debugPrint('[SupabaseProductService] جلب المنتجات من $tableName...');
      final fetchResult = await _fetchProductRowsWithRelations();
      final products = _parseAndFilter(fetchResult.rows, restaurantId);
      return _enrichProductsWithRelations(
        products,
        relationsEmbedded: fetchResult.relationsEmbedded,
      );
    } catch (e, stack) {
      debugPrint('[SupabaseProductService] fetchProducts فشل: $e\n$stack');
      rethrow;
    }
  }

  /// نتيجة جلب صفوف المنتجات — يُعلَم هل nested embed نجح.
  static Future<({List<Map<String, dynamic>> rows, bool relationsEmbedded})>
      _fetchProductRowsWithRelations() async {
    try {
      final rows = await _client.from(tableName).select(_selectWithRelations);
      debugPrint(
        '[SupabaseProductService] nested select: '
        '${(rows as List).length} صف',
      );
      return (
        rows: List<Map<String, dynamic>>.from(rows),
        relationsEmbedded: true,
      );
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseProductService] nested select فشل — fallback select(*): '
        '${e.message}',
      );
      final rows = await _client.from(tableName).select();
      return (
        rows: List<Map<String, dynamic>>.from(rows),
        relationsEmbedded: false,
      );
    }
  }

  static Stream<List<ProductModel>> watchProducts({
    String? restaurantId,
  }) {
    return _resilientProductsStream(
      restaurantId: restaurantId,
      streamTag: 'watchProducts(restaurantId=$restaurantId)',
    );
  }

  static Stream<List<ProductModel>> _productsSourceStream({
    required String? restaurantId,
  }) {
    return _client
        .from(tableName)
        .stream(primaryKey: const ['id'])
        .asyncMap((rows) async {
          final products = _parseAndFilter(rows, restaurantId);
          return _enrichProductsWithRelations(products);
        });
  }

  /// اشتراك Realtime مع إلغاء آمن وإعادة اتصال عند انقطاع WebSocket (مثلاً 1006).
  static Stream<List<ProductModel>> _resilientProductsStream({
    required String? restaurantId,
    required String streamTag,
  }) {
    return Stream<List<ProductModel>>.multi((controller) {
      StreamSubscription<List<ProductModel>>? subscription;
      bool closed = false;
      int reconnectAttempt = 0;
      DateTime lastDataAt = DateTime.now();
      late Future<void> Function() subscribe;

      Duration reconnectDelayForAttempt(int attempt) {
        final seconds = 1 << (attempt - 1).clamp(0, 4);
        final delay = Duration(seconds: seconds);
        if (delay > _streamReconnectMaxDelay) return _streamReconnectMaxDelay;
        if (delay < _streamReconnectBaseDelay) return _streamReconnectBaseDelay;
        return delay;
      }

      Future<void> scheduleReconnect(String reason, {Object? error}) async {
        reconnectAttempt += 1;
        final delay = reconnectDelayForAttempt(reconnectAttempt);
        debugPrint(
          '[SupabaseProductService] $streamTag reconnect ($reason) '
          'attempt=$reconnectAttempt delay=${delay.inMilliseconds}ms'
          '${error != null ? ' error=$error' : ''}',
        );
        await Future<void>.delayed(delay);
        if (!closed) {
          unawaited(subscribe());
        }
      }

      subscribe = () async {
        if (closed) return;
        await subscription?.cancel();
        subscription = null;
        subscription = _productsSourceStream(restaurantId: restaurantId).listen(
          (products) {
            if (closed) return;
            reconnectAttempt = 0;
            lastDataAt = DateTime.now();
            controller.add(products);
          },
          onError: (Object error, StackTrace stackTrace) async {
            debugPrint(
              '[SupabaseProductService] $streamTag error: $error\n$stackTrace',
            );
            if (closed) return;
            await subscription?.cancel();
            subscription = null;
            await scheduleReconnect('on_error', error: error);
          },
          onDone: () async {
            if (closed) return;
            final idleFor = DateTime.now().difference(lastDataAt);
            if (idleFor > const Duration(seconds: 30)) {
              debugPrint('[SupabaseProductService] $streamTag idle before close');
            }
            await subscription?.cancel();
            subscription = null;
            await scheduleReconnect('on_done');
          },
          cancelOnError: false,
        );
      };

      unawaited(subscribe());

      controller.onCancel = () async {
        closed = true;
        await subscription?.cancel();
        subscription = null;
      };
    });
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
          .maybeSingle()
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              debugPrint('[SupabaseProductService] fetchProductById: timed out');
              return null;
            },
          );
      if (row == null) return null;

      final product = _mapRowToProduct(Map<String, dynamic>.from(row));
      if (product == null) return null;

      final enriched = await _enrichProductsWithRelations([product]);
      return enriched.isEmpty ? product : enriched.first;
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

    String? savedId;
    try {
      savedId = await _trySaveViaRpc(
        payload: payload,
        addons: product.addons,
      );
      debugPrint(
        '[SupabaseProductService] تم حفظ المنتج (RPC): $savedId '
        'addons=${product.addons.length}',
      );
    } on PostgrestException catch (e) {
      if (!_isRpcUnavailable(e)) rethrow;
      debugPrint(
        '[SupabaseProductService] RPC غير متاح — fallback محلي: ${e.message}',
      );
    }

    savedId ??= await _saveProductWithClientRollback(
      payload: payload,
      addons: product.addons,
      resolvedImageUrl: resolvedImageUrl,
    );

    await _persistProductVariants(
      productId: savedId,
      variants: product.variants,
    );

    debugPrint(
      '[SupabaseProductService] تم حفظ المنتج: $savedId '
      'variants=${product.variants.length}',
    );
    return savedId;
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

  static dynamic _serializeProductId(String productId) {
    return ProductIdGenerator.serializeForSupabase(productId);
  }

  static PostgrestException _rlsDeniedException(
    PostgrestException source,
    String message,
  ) {
    return PostgrestException(
      message: message,
      code: source.code,
      details: source.details,
      hint: source.hint,
    );
  }

  static bool _isMissingTableError(PostgrestException error, String tableName) {
    return error.code == 'PGRST205' || error.message.contains(tableName);
  }

  /// عمود أو جدول غير متوافق مع schema cache (PGRST204).
  static bool _isPostgrestSchemaMismatch(PostgrestException error) {
    return error.code == 'PGRST204' ||
        error.code == 'PGRST205' ||
        error.message.contains('schema cache');
  }

  /// حذف صفوف فرعية لمنتج. يُرجع false إذا تُخطّى (مثلاً جدول غير موجود).
  static Future<bool> _deleteChildRowsForProduct({
    required String tableName,
    required dynamic serializedProductId,
    required String logContext,
    required String rlsDeleteMessage,
    bool allowMissingTable = false,
  }) async {
    try {
      await _client
          .from(tableName)
          .delete()
          .eq('product_id', serializedProductId);
      return true;
    } on PostgrestException catch (e, st) {
      debugPrint(
        '[SupabaseProductService] delete $logContext فشل: '
        '${e.code} ${e.message}\n$st',
      );
      if (e.code == '42501') {
        throw _rlsDeniedException(e, rlsDeleteMessage);
      }
      if (allowMissingTable && _isMissingTableError(e, tableName)) {
        debugPrint(
          '[SupabaseProductService] جدول $tableName غير موجود — تخطّي',
        );
        return false;
      }
      rethrow;
    }
  }

  static Future<void> _insertChildRows({
    required String tableName,
    required List<Map<String, dynamic>> rows,
    required String logContext,
    required String rlsInsertMessage,
  }) async {
    if (rows.isEmpty) return;

    try {
      await _client.from(tableName).insert(rows);
    } on PostgrestException catch (e, st) {
      debugPrint(
        '[SupabaseProductService] insert $logContext فشل: '
        '${e.code} ${e.message}\n$st',
      );
      if (e.code == '42501') {
        throw _rlsDeniedException(e, rlsInsertMessage);
      }
      rethrow;
    }
  }

  /// يستبدل إضافات المنتج في `product_addons` بعد حفظ المنتج.
  static Future<void> _saveProductAddons({
    required String productId,
    required List<ProductAddon> addons,
    bool skipDelete = false,
  }) async {
    final serializedProductId = _serializeProductId(productId);

    if (!skipDelete) {
      await _deleteChildRowsForProduct(
        tableName: addonsTableName,
        serializedProductId: serializedProductId,
        logContext: 'addons',
        rlsDeleteMessage:
            'لا توجد صلاحية لحذف الإضافات — فعّل سياسات DELETE على product_addons',
      );
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

    await _insertChildRows(
      tableName: addonsTableName,
      rows: rows,
      logContext: 'addons',
      rlsInsertMessage:
          'لا توجد صلاحية لحفظ الإضافات — فعّل سياسات INSERT على product_addons',
    );

    debugPrint(
      '[SupabaseProductService] حُفظت ${rows.length} إضافة للمنتج $productId',
    );
  }

  /// يحفظ الأحجام في `product_variants` و/أو عمود `products.variants` (jsonb).
  static Future<void> _persistProductVariants({
    required String productId,
    required List<ProductVariant> variants,
  }) async {
    final savedToTable = await _saveProductVariantsInTable(
      productId: productId,
      variants: variants,
    );
    if (!savedToTable) {
      debugPrint(
        '[SupabaseProductService] جدول product_variants غير متاح — '
        'حفظ الأحجام في products.variants (jsonb)',
      );
    }
    await _syncVariantsJsonbOnProduct(
      productId: productId,
      variants: variants,
    );
  }

  static Future<void> _syncVariantsJsonbOnProduct({
    required String productId,
    required List<ProductVariant> variants,
  }) async {
    try {
      await _client.from(tableName).update({
        'variants': variants.map((variant) => variant.toMap()).toList(growable: false),
      }).eq('id', _serializeProductId(productId));
      debugPrint(
        '[SupabaseProductService] variants jsonb → product $productId '
        'count=${variants.length}',
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' || e.message.contains('variants')) {
        debugPrint(
          '[SupabaseProductService] عمود products.variants غير موجود — '
          'نفّذ supabase/product_variants_table_schema.sql في Supabase',
        );
        return;
      }
      rethrow;
    } catch (e, stack) {
      debugPrint(
        '[SupabaseProductService] _syncVariantsJsonbOnProduct فشل: $e\n$stack',
      );
    }
  }

  /// يستبدل أحجام المنتج في `product_variants` بعد حفظ المنتج.
  /// يُرجع true إذا نجح الحفظ في الجدول، false إذا الجدول غير موجود.
  static Future<bool> _saveProductVariantsInTable({
    required String productId,
    required List<ProductVariant> variants,
  }) async {
    final serializedProductId = _serializeProductId(productId);

    final deleted = await _deleteChildRowsForProduct(
      tableName: variantsTableName,
      serializedProductId: serializedProductId,
      logContext: 'variants',
      rlsDeleteMessage:
          'لا توجد صلاحية لحذف الأحجام — فعّل سياسات DELETE على product_variants',
      allowMissingTable: true,
    );
    if (!deleted) {
      debugPrint(
        '[SupabaseProductService] جدول product_variants غير موجود — تخطّي حفظ الأحجام',
      );
      return false;
    }

    final validVariants = variants
        .where((variant) => variant.name.trim().isNotEmpty)
        .toList(growable: false);

    if (validVariants.isEmpty) {
      debugPrint(
        '[SupabaseProductService] لا أحجام لحفظها للمنتج $productId',
      );
      return true;
    }

    final rows = validVariants
        .asMap()
        .entries
        .map(
          (entry) => <String, dynamic>{
            'product_id': serializedProductId,
            'name': entry.value.name.trim(),
            'price': entry.value.price,
            'sort_order': entry.key + 1,
          },
        )
        .toList(growable: false);

    try {
      await _insertChildRows(
        tableName: variantsTableName,
        rows: rows,
        logContext: 'variants',
        rlsInsertMessage:
            'لا توجد صلاحية لحفظ الأحجام — فعّل سياسات INSERT على product_variants',
      );
    } on PostgrestException catch (e) {
      if (_isPostgrestSchemaMismatch(e)) {
        debugPrint(
          '[SupabaseProductService] product_variants غير متوافق: ${e.message}',
        );
        return false;
      }
      rethrow;
    }

    debugPrint(
      '[SupabaseProductService] حُفظت ${rows.length} أحجام للمنتج $productId',
    );
    return true;
  }

  /// يُحمّل الإضافات من `product_addons` ويربطها بالمنتجات (للبث المباشر).
  static Future<List<ProductModel>> _attachAddonsToProducts(
    List<ProductModel> products,
  ) async {
    if (products.isEmpty) return products;

    final productIds = _nonEmptyProductIds(products);
    if (productIds.isEmpty) return products;

    try {
      final rows = await _client
          .from(addonsTableName)
          .select()
          .inFilter('product_id', _serializedProductIds(productIds));

      final addonsByProduct = _groupAddonsByProductId(rows);
      return products
          .map(
            (product) => _copyProductRelations(
              product,
              addons: addonsByProduct[_asString(product.id)] ?? const [],
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

  /// يُحمّل الأحجام/المتغيرات من `product_variants` ويربطها بالمنتجات.
  static Future<List<ProductModel>> _attachVariantsToProducts(
    List<ProductModel> products,
  ) async {
    if (products.isEmpty) return products;

    final productIds = _nonEmptyProductIds(products);
    if (productIds.isEmpty) return products;

    try {
      final rows = await _fetchVariantRowsForProductIds(productIds);

      debugPrint(
        '[SupabaseProductService] product_variants: ${rows.length} صف '
        'لـ ${productIds.length} منتج',
      );

      final variantsByProduct = _groupVariantsByProductId(rows);
      return products
          .map(
            (product) {
              final fromTable = _lookupVariantsForProduct(
                variantsByProduct,
                product.id,
              );
              final variants = _resolveVariantsForProduct(
                product: product,
                fromTable: fromTable,
              );
              if (variants.isEmpty && product.variants.isEmpty) {
                debugPrint(
                  '[SupabaseProductService] لا أحجام للمنتج id=${product.id} '
                  'name=${product.name}',
                );
              }
              return _copyProductRelations(product, variants: variants);
            },
          )
          .toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseProductService] _attachVariantsToProducts: ${e.message}',
      );
      return products;
    } catch (e, stack) {
      debugPrint(
        '[SupabaseProductService] _attachVariantsToProducts فشل: $e\n$stack',
      );
      return products;
    }
  }

  static Map<String, List<ProductVariant>> _groupVariantsByProductId(
    dynamic rows,
  ) {
    final grouped = <String, List<ProductVariant>>{};
    if (rows is! List) return grouped;

    final sortedRows = List<dynamic>.from(rows)
      ..sort((a, b) {
        if (a is! Map || b is! Map) return 0;
        final aOrder = (a['sort_order'] as num?)?.toInt() ?? 0;
        final bOrder = (b['sort_order'] as num?)?.toInt() ?? 0;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        return _readDouble(a['price']).compareTo(_readDouble(b['price']));
      });

    for (final entry in sortedRows) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final productId = _readVariantProductId(map);
      if (productId.isEmpty) {
        debugPrint(
          '[SupabaseProductService] تخطي variant بدون product_id — '
          'keys=${map.keys.toList()}',
        );
        continue;
      }

      final variant = ProductVariant.fromMap(map);
      if (variant.name.isEmpty) {
        debugPrint(
          '[SupabaseProductService] تخطي variant بدون اسم — '
          'product_id=$productId keys=${map.keys.toList()}',
        );
        continue;
      }

      grouped.putIfAbsent(productId, () => <ProductVariant>[]).add(variant);
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

    final variants = _parseVariantsFromRow(normalized);
    if (variants.isNotEmpty) {
      debugPrint(
        '[SupabaseProductService] nested/jsonb variants للمنتج $id: '
        '${variants.length}',
      );
    }

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
      variants: variants,
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

  static List<ProductVariant> _parseVariantsFromRow(Map<String, dynamic> row) {
    final nested = row['product_variants'];
    if (nested is List && nested.isNotEmpty) {
      return ProductVariant.listFromDynamic(nested);
    }
    return ProductVariant.listFromDynamic(row['variants']);
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
