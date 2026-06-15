import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// تحميل `.env` — assets أولاً، ثم ملف محلي على Desktop عند فشل Hot Restart.
abstract final class AppEnvLoader {
  AppEnvLoader._();

  static Future<void> load() async {
    if (dotenv.isInitialized) return;

    try {
      await dotenv.load(fileName: '.env');
      return;
    } on FileNotFoundError {
      if (!kDebugMode) rethrow;
    }

    final file = _findLocalEnvFile();
    if (file == null) {
      throw StateError(
        'Missing .env — copy .env.example to .env in the project root '
        'and ensure it is listed under flutter.assets in pubspec.yaml.',
      );
    }

    dotenv.testLoad(fileInput: await file.readAsString());
    if (kDebugMode) {
      debugPrint('[AppEnvLoader] loaded .env from ${file.path}');
    }
  }

  static File? _findLocalEnvFile() {
    if (kIsWeb) return null;

    final candidates = <File>[
      File('.env'),
      File('${Directory.current.path}${Platform.pathSeparator}.env'),
    ];

    try {
      final executable = Platform.resolvedExecutable;
      final exeDir = File(executable).parent;
      candidates.add(
        File(
          '${exeDir.path}${Platform.pathSeparator}data'
          '${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}.env',
        ),
      );
    } catch (_) {}

    for (final file in candidates) {
      if (file.existsSync()) return file;
    }
    return null;
  }
}
