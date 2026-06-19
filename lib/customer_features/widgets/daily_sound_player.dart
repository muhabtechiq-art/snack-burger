import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/customer_menu_theme.dart';

/// زر صوت اليوم — تشغيل/إيقاف فقط، بدون تشغيل تلقائي.
class DailySoundPlayer extends StatefulWidget {
  const DailySoundPlayer({
    super.key,
    required this.soundUrl,
    required this.defaultVolume,
    required this.loop,
    this.title,
  });

  final String soundUrl;
  final double defaultVolume;
  final bool loop;
  final String? title;

  /// ارتفاع شريط التنقل السفلي في واجهة المنيو.
  static const double bottomNavHeight = 64;

  /// هامش بين الزر وشريط التنقل.
  static const double bottomMargin = 12;

  static const double fabSize = 44;

  @override
  State<DailySoundPlayer> createState() => _DailySoundPlayerState();
}

class _DailySoundPlayerState extends State<DailySoundPlayer> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSubscription;

  bool _isPlaying = false;
  bool _loading = false;
  bool _ignorePlayerState = false;
  String? _error;

  static void _log(String message) => debugPrint('[DailySound] $message');

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant DailySoundPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.soundUrl != widget.soundUrl) {
      unawaited(_disposePlayer());
      _patchState(() {
        _isPlaying = false;
        _loading = false;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    unawaited(_disposePlayer());
    super.dispose();
  }

  void _patchState(VoidCallback fn) {
    if (!mounted) return;
    fn();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _disposePlayer() async {
    _stateSubscription?.cancel();
    _stateSubscription = null;

    final player = _player;
    _player = null;
    if (player == null) return;

    try {
      await player.stop();
      await player.dispose();
    } catch (_) {
      try {
        await player.dispose();
      } catch (_) {
        // ignored
      }
    }
  }

  void _attachStateListener(AudioPlayer player) {
    _stateSubscription?.cancel();
    _stateSubscription = player.onPlayerStateChanged.listen((state) {
      _log('player state = ${state.name}');
      if (!mounted || _ignorePlayerState) return;

      if (state == PlayerState.completed && !widget.loop) {
        _patchState(() => _isPlaying = false);
        return;
      }

      if (state == PlayerState.playing) {
        _patchState(() => _isPlaying = true);
        return;
      }

      if (state == PlayerState.paused || state == PlayerState.stopped) {
        _patchState(() => _isPlaying = false);
      }
    });
  }

  Future<AudioPlayer> _ensurePlayer() async {
    if (_player != null) return _player!;

    await AudioPlayer.global.ensureInitialized();
    final player = AudioPlayer();
    await player.setAudioContext(
      AudioContextConfig(
        focus: AudioContextConfigFocus.gain,
        respectSilence: false,
      ).build(),
    );
    await player.setReleaseMode(
      widget.loop ? ReleaseMode.loop : ReleaseMode.release,
    );

    _attachStateListener(player);
    _player = player;
    return player;
  }

  Future<void> _onFabPressed() async {
    if (_loading) return;

    if (_isPlaying) {
      await _stop();
    } else {
      await _play();
    }
  }

  Future<void> _play() async {
    _log('play pressed');
    _ignorePlayerState = true;
    _patchState(() {
      _loading = true;
      _error = null;
    });

    try {
      final player = await _ensurePlayer();
      await player.setReleaseMode(
        widget.loop ? ReleaseMode.loop : ReleaseMode.release,
      );
      final volume = widget.defaultVolume.clamp(0.0, 1.0);
      await player.setVolume(volume);
      await player.play(UrlSource(widget.soundUrl));
      _patchState(() => _isPlaying = true);
    } catch (error) {
      _log('play failed error=$error');
      _patchState(() {
        _error = 'تعذّر تشغيل الصوت';
        _isPlaying = false;
      });
    } finally {
      _ignorePlayerState = false;
      _patchState(() => _loading = false);
    }
  }

  Future<void> _stop() async {
    _log('stop pressed');
    _ignorePlayerState = true;
    _patchState(() {
      _loading = true;
      _error = null;
      _isPlaying = false;
    });

    try {
      final player = _player;
      if (player != null) {
        await player.stop();
      }
    } catch (error) {
      _log('stop failed error=$error');
      _patchState(() => _error = 'تعذّر إيقاف الصوت');
    } finally {
      _ignorePlayerState = false;
      _patchState(() {
        _loading = false;
        _isPlaying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom +
        DailySoundPlayer.bottomNavHeight +
        DailySoundPlayer.bottomMargin;

    return PositionedDirectional(
      bottom: bottomInset,
      start: 16,
      child: _SoundFab(
        size: DailySoundPlayer.fabSize,
        isPlaying: _isPlaying,
        loading: _loading,
        error: _error,
        onTap: () => unawaited(_onFabPressed()),
      ),
    );
  }
}

class _SoundFab extends StatelessWidget {
  const _SoundFab({
    required this.size,
    required this.isPlaying,
    required this.loading,
    required this.error,
    required this.onTap,
  });

  final double size;
  final bool isPlaying;
  final bool loading;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = isPlaying ? '⏹' : '🔊';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          elevation: 5,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          color: CustomerMenuTheme.surfaceWhite,
          shape: CircleBorder(
            side: BorderSide(
              color: CustomerMenuTheme.mustard.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: InkWell(
            onTap: loading ? null : onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color:
                              CustomerMenuTheme.mutedRed.withValues(alpha: 0.85),
                        ),
                      )
                    : Text(
                        icon,
                        style: const TextStyle(fontSize: 20, height: 1),
                      ),
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Material(
              color: CustomerMenuTheme.surfaceWhite.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  error!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
