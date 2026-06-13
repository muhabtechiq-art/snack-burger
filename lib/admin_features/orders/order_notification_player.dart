import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// تشغيل تنبيه صوتي عند وصول طلب معلق جديد.
abstract final class OrderNotificationPlayer {
  OrderNotificationPlayer._();

  static const String _assetPath = 'sounds/alert.mp3';
  static const Duration _playTimeout = Duration(seconds: 8);

  static AudioPlayer _player = AudioPlayer();
  static bool _userGesturePrimed = false;
  static Future<void>? _initFuture;
  static Future<void> _playQueue = Future<void>.value();

  /// تهيئة الصوت بعد أول تفاعل من المستخدم (Web/Android autoplay policy).
  static Future<void> prepareOnUserGesture() {
    if (_userGesturePrimed) return Future<void>.value();
    _userGesturePrimed = true;
    return _primeAudioContext();
  }

  static Future<void> _primeAudioContext() async {
    try {
      await _ensureInitialized();
      await _player.setVolume(0);
      await _player.stop();
      await _player.play(AssetSource(_assetPath));
      await _player.stop();
      await _player.setVolume(1);
      debugPrint('[QA][OrderSound] audio primed via user gesture');
    } catch (error, stack) {
      debugPrint(
        '[QA][OrderSound] audio prime failed (autoplay/user gesture): $error\n$stack',
      );
    }
  }

  /// مرة واحدة لكل طلب — لا يُعاد عند إعادة بناء الواجهة.
  static Future<void> playNewPendingOrder() {
    _playQueue = _playQueue
        .then((_) => _playNewPendingOrderInternal())
        .timeout(
          _playTimeout,
          onTimeout: () {
            debugPrint(
              '[QA][OrderSound] playing sound failed error=queue step timeout',
            );
          },
        )
        .catchError((Object error) {
          debugPrint(
            '[QA][OrderSound] playing sound failed error=$error',
          );
        });
    return _playQueue;
  }

  static Future<void> _ensureInitialized() {
    return _ensureInitializedFor(_player);
  }

  static Future<void> _ensureInitializedFor(AudioPlayer player) {
    return _initFuture ??= _initializePlayer(player).catchError((Object error) {
      _initFuture = null;
      throw error;
    });
  }

  static Future<void> _initializePlayer(AudioPlayer player) async {
    await AudioPlayer.global.ensureInitialized();
    await player.setAudioContext(
      AudioContextConfig(
        focus: AudioContextConfigFocus.duckOthers,
        respectSilence: false,
      ).build(),
    );
    await player.setReleaseMode(ReleaseMode.stop);
  }

  static Future<void> _playWithCurrentPlayer() async {
    await _ensureInitialized().timeout(_playTimeout);
    await _player.stop();
    await _player.play(AssetSource(_assetPath)).timeout(_playTimeout);
  }

  static Future<void> _playNewPendingOrderInternal() async {
    debugPrint('[QA][OrderSound] playing sound start');
    try {
      await _playWithCurrentPlayer();
      debugPrint('[QA][OrderSound] playing sound success');
    } catch (firstError) {
      debugPrint(
        '[QA][OrderSound] playing sound failed error=$firstError',
      );
      try {
        _recreatePlayer();
        await _playWithCurrentPlayer();
        debugPrint('[QA][OrderSound] playing sound success');
      } catch (retryError) {
        debugPrint(
          '[QA][OrderSound] playing sound failed error=$retryError',
        );
      }
    }
  }

  static void _recreatePlayer() {
    debugPrint('[QA][OrderSound] recreating AudioPlayer');
    final oldPlayer = _player;
    _player = AudioPlayer();
    _initFuture = null;
    unawaited(oldPlayer.dispose());
  }

  /// يُستدعى فقط عند تسجيل الخروج أو إيقاف لوحة الإدارة.
  static Future<void> dispose() async {
    _initFuture = null;
    _playQueue = Future<void>.value();
    _userGesturePrimed = false;
    await _player.dispose();
    _player = AudioPlayer();
    debugPrint('[QA][OrderSound] AudioPlayer disposed');
  }
}
