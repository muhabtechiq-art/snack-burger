import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/product_id_generator.dart';
import '../services/supabase_product_service.dart';
import 'snack_burger_seed_catalog.dart';

/// نتيجة تشغيل التعبئة من مهمة VS Code أو `--dart-define`.
enum SeedRunResult {
  /// لم يُطلب التشغيل — يستمر التطبيق بشكل طبيعي.
  notRequested,

  /// طُلب التشغيل لكن التعبئة مكتملة مسبقاً.
  alreadyCompleted,

  /// اكتملت التعبئة وحُفظت العلامة في SharedPreferences.
  completed,
}

/// تعبئة لمرة واحدة لـ 50 منتجاً في Supabase.
///
/// **الاستخدام:** من VS Code → Terminal → Run Task → `run-seeder`
/// (أو `flutter run --dart-define=SNACK_BURGER_RUN_SEEDER=true`).
abstract final class SnackBurgerProductSeeder {
  SnackBurgerProductSeeder._();

  static const String seedTriggerEnvKey = 'SNACK_BURGER_RUN_SEEDER';
  static const String seedTriggerDefineKey = 'SNACK_BURGER_RUN_SEEDER';

  static const String _completedPrefsKey =
      'snack_burger_product_seed_completed_v1';

  /// معرّفات ثابتة لتجنّب التصادم مع المنتجات اليدوية.
  static const int _seedIdBase = 910_000_001;

  /// يُفعَّل عبر `--dart-define` أو متغير البيئة (مهمة `run-seeder`).
  static bool get isSeedRequested {
    const fromDefine = bool.fromEnvironment(
      seedTriggerDefineKey,
      defaultValue: false,
    );
    if (fromDefine) return true;

    if (kIsWeb) return false;

    final fromEnv = Platform.environment[seedTriggerEnvKey]?.trim().toLowerCase();
    return fromEnv == 'true' || fromEnv == '1';
  }

  /// يُستدعى من [main] بعد تهيئة Supabase.
  ///
  /// إذا طُلبت التعبئة، يُنفَّذ ثم يُرجع نتيجة تُوجب إغلاق التطبيق.
  static Future<SeedRunResult> runIfRequested() async {
    if (!isSeedRequested) return SeedRunResult.notRequested;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_completedPrefsKey) == true) {
      debugPrint(
        '[SnackBurgerProductSeeder] التعبئة مكتملة مسبقاً — لا إعادة تنفيذ.',
      );
      return SeedRunResult.alreadyCompleted;
    }

    await seedProducts();
    await prefs.setBool(_completedPrefsKey, true);
    debugPrint('[SnackBurgerProductSeeder] انتهت التعبئة — حُفظت حالة النجاح.');
    return SeedRunResult.completed;
  }

  /// يُغلق العملية بعد مهمة التعبئة دون تشغيل الواجهة.
  static Never exitAfterSeedRun(SeedRunResult result) {
    final code = switch (result) {
      SeedRunResult.notRequested => 0,
      SeedRunResult.alreadyCompleted => 0,
      SeedRunResult.completed => 0,
    };
    debugPrint('[SnackBurgerProductSeeder] إنهاء العملية (code=$code).');
    exit(code);
  }

  /// يُدخل المنتجات والإضافات مع فحص الأسماء وتخطّي التكرار.
  @visibleForTesting
  static Future<void> seedProducts() async {
    final client = Supabase.instance.client;
    final restaurantId = SupabaseProductService.defaultRestaurantId;
    final existingNames = await _loadExistingProductNames(
      client: client,
      restaurantId: restaurantId,
    );

    var inserted = 0;
    var skipped = 0;
    var failed = 0;

    debugPrint(
      '[SnackBurgerProductSeeder] بدء التعبئة — '
      '${snackBurgerSeedCatalog.length} منتج، '
      '${existingNames.length} اسم موجود مسبقاً.',
    );

    for (var index = 0; index < snackBurgerSeedCatalog.length; index++) {
      final seed = snackBurgerSeedCatalog[index];
      final name = seed.name.trim();

      if (name.isEmpty) {
        failed++;
        debugPrint('[SnackBurgerProductSeeder] تخطي: اسم فارغ عند الفهرس $index');
        continue;
      }

      if (existingNames.contains(name)) {
        skipped++;
        debugPrint('[SnackBurgerProductSeeder] تخطي (مكرر): $name');
        continue;
      }

      final productId = _seedIdBase + index;

      try {
        final row = await client
            .from(SupabaseProductService.tableName)
            .insert(<String, dynamic>{
              'id': ProductIdGenerator.serializeForSupabase('$productId'),
              'name': name,
              'price': seed.price,
              'description': seed.description,
              'category': seed.category.trim().isNotEmpty
                  ? seed.category.trim()
                  : 'general',
              'image_url': seed.imageUrl,
              'restaurant_id': restaurantId,
            })
            .select('id')
            .single();

        final savedProductId = row['id'];
        if (savedProductId == null) {
          throw StateError('insert products لم يُرجع product_id');
        }

        if (seed.addons.isNotEmpty) {
          final addonRows = seed.addons
              .where((addon) => addon.name.trim().isNotEmpty)
              .map(
                (addon) => <String, dynamic>{
                  'product_id': savedProductId,
                  'name': addon.name.trim(),
                  'price': addon.price,
                },
              )
              .toList(growable: false);

          if (addonRows.isNotEmpty) {
            await client
                .from(SupabaseProductService.addonsTableName)
                .insert(addonRows);
          }
        }

        existingNames.add(name);
        inserted++;
        debugPrint(
          '[SnackBurgerProductSeeder] ✓ $name (id=$savedProductId, '
          'addons=${seed.addons.length})',
        );
      } catch (error, stack) {
        failed++;
        debugPrint(
          '[SnackBurgerProductSeeder] ✗ فشل "$name": $error\n$stack',
        );
      }
    }

    debugPrint(
      '[SnackBurgerProductSeeder] ملخص: أُدخل=$inserted، '
      'تخطي=$skipped، فشل=$failed',
    );
  }

  static Future<Set<String>> _loadExistingProductNames({
    required SupabaseClient client,
    required String restaurantId,
  }) async {
    final rows = await client
        .from(SupabaseProductService.tableName)
        .select('name')
        .eq('restaurant_id', restaurantId);

    return rows
        .map((row) => (row['name'] as String?)?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
  }
}
