import 'package:flutter/foundation.dart';

/// سجلات تشخيص زمنية لمسار صورة البانر — لا تغيّر التنفيذ.
void bannerImageDiag(String stage, {String? detail}) {
  final suffix = detail == null || detail.isEmpty ? '' : ' $detail';
  debugPrint(
    '[BannerImageDiag] $stage ${DateTime.now().toIso8601String()}$suffix',
  );
}
