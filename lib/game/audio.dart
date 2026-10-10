import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

class AudioEngine {
  final AudioPlayer _bgmPlayer = AudioPlayer();
  bool _enabled = true;
  bool muted = false;
  bool _bgmStarted = false;
  int _area = 0;
  String? _playingBgm;
  double volume = 0.25;
  double bgmVolume = 0.35;

  AudioContext _noFocusContext() => AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const <AVAudioSessionOptions>{
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      );

  void unlock() {
    _enabled = true;
    if (!_bgmStarted) unawaited(_startBgm());
  }

  void setArea(int area) {
    _area = area.clamp(0, 4).toInt();
    if (_bgmStarted) unawaited(_startBgm());
  }

  Future<void> setMuted(bool value) async {
    muted = value;
    try {
      if (muted) {
        await _bgmPlayer.pause();
      } else if (_bgmStarted) {
        await _startBgm();
      }
    } catch (_) {
      // Audio is optional and must never block gameplay.
    }
  }

  Future<void> _startBgm() async {
    final track = 'bgm${_area + 1}.mp3';
    _bgmStarted = true;
    try {
      if (_playingBgm != track) {
        await _bgmPlayer.setAudioContext(_noFocusContext());
        await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
        await _bgmPlayer.setVolume(bgmVolume);
        await _bgmPlayer.setSource(AssetSource('audio/$track'));
        _playingBgm = track;
      }
      if (!muted && _bgmPlayer.state != PlayerState.playing) {
        await _bgmPlayer.resume();
      }
    } catch (_) {
      // BGM is optional and must never block gameplay.
      _bgmStarted = false;
    }
  }

  Future<void> _play(String filename, {double volumeScale = 1}) async {
    if (!_enabled || muted) return;
    final player = AudioPlayer();
    try {
      await player.setAudioContext(_noFocusContext());
      await player.setVolume((volume * volumeScale).clamp(0, 1).toDouble());
      player.onPlayerComplete.listen((_) {
        unawaited(player.dispose());
      });
      await player.play(AssetSource('audio/$filename'));
    } catch (_) {
      // SFX is optional and should never interrupt gameplay.
      await player.dispose();
    }
  }

  void place() => unawaited(_play('place.mp3'));
  void hit() => unawaited(_play('hit.mp3'));
  void jump() => unawaited(_play('jump.mp3'));
  void win() => unawaited(_play('win.mp3'));
  void swipe() => unawaited(_play('swipe.mp3'));
  void click() => unawaited(_play('click.mp3'));
  void coin() => unawaited(_play('coin.mp3'));
  void unlockSfx() => unawaited(_play('unlock.mp3'));

  Future<void> dispose() async {
    await _bgmPlayer.dispose();
  }
}
