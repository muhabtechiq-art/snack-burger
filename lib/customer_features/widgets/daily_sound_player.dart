import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../theme/customer_menu_theme.dart';

/// زر صوت اليوم — لا يُحمّل الملف إلا بعد ضغط المستخدم (بدون تشغيل تلقائي).
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

  @override
  State<DailySoundPlayer> createState() => _DailySoundPlayerState();
}

class _DailySoundPlayerState extends State<DailySoundPlayer> {
  AudioPlayer? _player;
  bool _expanded = false;
  bool _playing = false;
  bool _loading = false;
  double _volume = 0.3;
  String? _error;

  @override
  void initState() {
    super.initState();
    _volume = widget.defaultVolume.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(covariant DailySoundPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.soundUrl != widget.soundUrl) {
      unawaited(_stopAndDisposePlayer());
      if (mounted) {
        setState(() {
          _expanded = false;
          _playing = false;
          _loading = false;
          _error = null;
        });
      }
    }
    if (oldWidget.defaultVolume != widget.defaultVolume && _player == null) {
      setState(() => _volume = widget.defaultVolume.clamp(0.0, 1.0));
    }
  }

  @override
  void dispose() {
    unawaited(_stopAndDisposePlayer());
    super.dispose();
  }

  Future<void> _stopAndDisposePlayer() async {
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.stop();
      await player.dispose();
    } catch (_) {
      // ignored
    }
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
    await player.setVolume(_volume);

    player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playing = state == PlayerState.playing;
        if (state == PlayerState.completed && !widget.loop) {
          _playing = false;
        }
      });
    });

    _player = player;
    return player;
  }

  Future<void> _openAndPlay() async {
    if (_loading) return;

    setState(() {
      _expanded = true;
      _error = null;
    });

    if (_playing) return;

    setState(() => _loading = true);
    try {
      final player = await _ensurePlayer();
      await player.setReleaseMode(
        widget.loop ? ReleaseMode.loop : ReleaseMode.release,
      );
      await player.setVolume(_volume);
      await player.play(UrlSource(widget.soundUrl));
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'تعذّر تشغيل الصوت');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePlayPause() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final player = await _ensurePlayer();
      if (_playing) {
        await player.pause();
      } else {
        await player.setReleaseMode(
          widget.loop ? ReleaseMode.loop : ReleaseMode.release,
        );
        await player.setVolume(_volume);
        await player.play(UrlSource(widget.soundUrl));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'تعذّر تشغيل الصوت');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onVolumeChanged(double value) async {
    setState(() => _volume = value);
    final player = _player;
    if (player != null) {
      await player.setVolume(value);
    }
  }

  Future<void> _collapse() async {
    await _stopAndDisposePlayer();
    if (!mounted) return;
    setState(() {
      _expanded = false;
      _playing = false;
      _loading = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return Material(
        elevation: 3,
        shadowColor: Colors.black26,
        color: CustomerMenuTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: _openAndPlay,
          borderRadius: BorderRadius.circular(24),
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Text('🔊', style: TextStyle(fontSize: 22)),
          ),
        ),
      );
    }

    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      color: CustomerMenuTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'صوت اليوم',
                  style: TextStyle(
                    color: CustomerMenuTheme.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: _loading ? null : _togglePlayPause,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: CustomerMenuTheme.ink,
                        ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: _collapse,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: CustomerMenuTheme.ink,
                  ),
                ),
              ],
            ),
            SizedBox(
              width: 180,
              child: Row(
                children: [
                  Icon(
                    _volume <= 0.01
                        ? Icons.volume_off_rounded
                        : Icons.volume_down_rounded,
                    size: 18,
                    color: CustomerMenuTheme.ink.withValues(alpha: 0.7),
                  ),
                  Expanded(
                    child: Slider(
                      value: _volume,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      onChanged: _onVolumeChanged,
                      activeColor: CustomerMenuTheme.ink,
                    ),
                  ),
                  Icon(
                    Icons.volume_up_rounded,
                    size: 18,
                    color: CustomerMenuTheme.ink.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
