import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sfx_stub.dart' if (dart.library.js_interop) 'sfx_web.dart';

/// Zvučni efekti igre (assets/sounds, napravljeni skriptom tool/make_sounds.py).
enum Sfx { tap, place, turn, tick, lifeLost, start, win, lose, draw, coin, medal }

class Sound {
  Sound._();

  static bool enabled = true;
  static final Map<Sfx, List<AudioPlayer>> _pool = {};
  static final Map<Sfx, int> _next = {};

  static String _file(Sfx s) => switch (s) {
        Sfx.lifeLost => 'sounds/life_lost.wav',
        _ => 'sounds/${s.name}.wav',
      };

  /// Kratki zvuci koji se brzo ponavljaju imaju više „plejera“ da se ne seku.
  static int _voices(Sfx s) => switch (s) {
        Sfx.tap || Sfx.tick || Sfx.place => 3,
        _ => 1,
      };

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = !(prefs.getBool('soundOff') ?? false);
    } catch (_) {}
  }

  static Future<void> setEnabled(bool on) async {
    enabled = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundOff', !on);
    if (on) play(Sfx.tap);
  }

  static Future<void> play(Sfx s) async {
    if (!enabled) return;
    if (kIsWeb) {
      playWebSfx(_file(s).substring(7).replaceAll('.wav', ''), s == Sfx.tick ? 0.6 : 1.0);
      return;
    }
    try {
      final players = _pool.putIfAbsent(s, () {
        return List.generate(_voices(s), (_) {
          final p = AudioPlayer();
          p.setReleaseMode(ReleaseMode.stop);
          // Zvuci igre ne prekidaju muziku na telefonu.
          if (!kIsWeb) {
            p
                .setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build())
                .catchError((_) {});
          }
          return p;
        });
      });
      final i = (_next[s] ?? 0) % players.length;
      _next[s] = i + 1;
      final p = players[i];
      await p.stop();
      await p.play(AssetSource(_file(s)), volume: s == Sfx.tick ? 0.6 : 1.0);
    } catch (e) {
      debugPrint('Zvuk ${s.name}: $e');
    }
  }
}
