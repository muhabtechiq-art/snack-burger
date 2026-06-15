import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:snack_burger/core/config/app_env_loader.dart';
import 'package:snack_burger/core/config/supabase_env.dart';
import 'package:snack_burger/services/supabase_product_service.dart';

/// نقطة دخول لمرة واحدة — يتطلب جلسة إدارة (ليس anon فقط):
/// flutter run -t tool/variants_cleanup_runner.dart -d windows
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnvLoader.load();
  SupabaseEnv.ensureConfigured();
  await Supabase.initialize(
    url: SupabaseEnv.url,
    anonKey: SupabaseEnv.anonKey,
  );

  final report = await SupabaseProductService.cleanupDuplicateVariantRows();
  debugPrint(
    'Cleanup finished: deleted=${report.totalDeleted} '
    'products=${report.productsAffected}',
  );
  exit(report.hasChanges ? 0 : 0);
}
