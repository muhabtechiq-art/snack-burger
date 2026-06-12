import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// تشغيل تنبيه صوتي عند وصول طلب معلق جديد.
abstract final class OrderNotificationPlayer {
  OrderNotificationPlayer._();

  static const String _assetPath = 'sounds/alert.mp3';

  static final AudioPlayer _player = AudioPlayer();
  static bool _assetMissingLogged = false;
  static Future<void>? _initFuture;
  static Future<void> _playQueue = Future<void>.value();

  /// مرة واحدة لكل دفعة طلبات جديدة (لا يُعاد عند إعادة بناء الواجهة).
  static Future<void> playNewPendingOrder() {
    _playQueue = _playQueue.then((_) => _playNewPendingOrderInternal());
    return _playQueue;
  }

  static Future<void> _ensureInitialized() {
    return _initFuture ??= _initializePlayer().catchError((Object error) {
      _initFuture = null;
      throw error;
    });
  }

  static Future<void> _initializePlayer() async {
    await AudioPlayer.global.ensureInitialized();
    await _player.setAudioContext(
      AudioContextConfig(
        focus: AudioContextConfigFocus.duckOthers,
        respectSilence: false,
      ).build(),
    );
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setSourceAsset(_assetPath);
  }

  static Future<void> _playNewPendingOrderInternal() async {
    try {
      await _ensureInitialized();
      await _playPreparedAlert();
    } catch (_) {
      _initFuture = null;
      try {
        await _ensureInitialized();
        await _playPreparedAlert();
      } catch (retryError, retryStack) {
        _logAssetMissingOnce(retryError, retryStack);
      }
    }
  }

  static Future<void> _playPreparedAlert() async {
    if (_player.state == PlayerState.playing ||
        _player.state == PlayerState.paused) {
      await _player.stop();
    }
    await _player.seek(Duration.zero);
    await _player.resume();
  }

  static void _logAssetMissingOnce(Object e, StackTrace stack) {
    if (!_assetMissingLogged) {
      _assetMissingLogged = true;
      debugPrint(
        '[OrderNotificationPlayer] ضع assets/$_assetPath — $e\n$stack',
      );
    }
  }
}
