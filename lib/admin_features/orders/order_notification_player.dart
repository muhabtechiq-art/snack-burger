import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// تشغيل تنبيه صوتي عند وصول طلب معلق جديد.
abstract final class OrderNotificationPlayer {
  OrderNotificationPlayer._();

  static const String _assetPath = 'sounds/alert.mp3';

  static final AudioPlayer _player = AudioPlayer();
  static bool _assetMissingLogged = false;

  /// مرة واحدة لكل دفعة طلبات جديدة (لا يُعاد عند إعادة بناء الواجهة).
  static Future<void> playNewPendingOrder() async {
    try {
      await _player.stop();
      await _player.play(AssetSource(_assetPath));
    } catch (e, stack) {
      if (!_assetMissingLogged) {
        _assetMissingLogged = true;
        debugPrint(
          '[OrderNotificationPlayer] ضع assets/$_assetPath — $e\n$stack',
        );
      }
    }
  }
}
