// sound_service.dart — Tiny wrapper around audioplayers for the game's SFX.
//
// One reusable low-latency player per sound so effects can fire rapidly
// (coins, claims) without allocation churn. Callers gate on the player's
// sound setting before calling — this service just plays. Every call is
// best-effort: audio must never crash gameplay.

import 'package:audioplayers/audioplayers.dart';

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final Map<String, AudioPlayer> _players = {};

  Future<void> _play(String file, {double volume = 1.0}) async {
    try {
      final player = _players.putIfAbsent(
        file,
        () => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency),
      );
      await player.stop(); // restart if it's still playing
      await player.setVolume(volume);
      await player.play(AssetSource('sfx/$file'));
    } catch (_) {
      // Silence is always an acceptable fallback for a sound effect.
    }
  }

  Future<void> tap() => _play('tap.wav', volume: 0.5);
  Future<void> coin() => _play('coin.wav', volume: 0.8);
  Future<void> treasure() => _play('treasure.wav', volume: 0.9);
  Future<void> claim() => _play('claim.wav');
  Future<void> levelUp() => _play('levelup.wav');
}
