import 'package:flutter_dotenv/flutter_dotenv.dart';

/// إعدادات Supabase من ملف `.env` (لا تُخزَّن المفاتيح في الكود).
abstract final class SupabaseEnv {
  SupabaseEnv._();

  static const String urlKey = 'SUPABASE_URL';
  static const String anonKeyKey = 'SUPABASE_ANON_KEY';

  static String get url => dotenv.env[urlKey]?.trim() ?? '';

  static String get anonKey => dotenv.env[anonKeyKey]?.trim() ?? '';

  /// يتحقق من وجود القيم قبل [Supabase.initialize].
  static void ensureConfigured() {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Missing $urlKey or $anonKeyKey. '
        'Copy .env.example to .env and fill in your Supabase project values.',
      );
    }
  }
}
