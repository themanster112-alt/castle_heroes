import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class GameSound {
  static final muted = ValueNotifier(false);
  static void toggle() => muted.value = !muted.value;
}

class SoundToggleButton extends StatelessWidget {
  const SoundToggleButton({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: GameSound.muted,
    builder: (context, muted, _) => IconButton(
      tooltip: muted ? 'تشغيل الصوت' : 'كتم الصوت',
      onPressed: GameSound.toggle,
      icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
    ),
  );
}

/// One shared player keeps menu taps from creating overlapping sounds.
class MenuAudio {
  static AudioPlayer? _player;
  static bool _starting = false;

  static Future<void> initialize() async {
    try {
      final player = _player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(AssetSource('audio/menu_click.m4a'));
      GameSound.muted.addListener(_applyMute);
      await player.setVolume(GameSound.muted.value ? 0 : 1);
    } catch (error) {
      debugPrint('Menu sound unavailable: $error');
    }
  }

  static void _applyMute() {
    final player = _player;
    if (player != null) {
      unawaited(player.setVolume(GameSound.muted.value ? 0 : 1));
    }
  }

  static Future<void> playClick() async {
    final player = _player;
    if (player == null || _starting || GameSound.muted.value) return;
    _starting = true;
    try {
      await player.seek(Duration.zero);
      await player.resume();
    } catch (error) {
      debugPrint('Menu sound unavailable: $error');
    } finally {
      _starting = false;
    }
  }
}
