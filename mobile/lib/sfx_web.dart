import 'dart:js_interop';

@JS('slovaSfx.play')
external void _play(String name, double volume);

/// Web: zvuk preko Web Audio (vidi web/index.html), bez <audio> elemenata.
bool playWebSfx(String name, double volume) {
  try {
    _play(name, volume);
    return true;
  } catch (_) {
    return false;
  }
}
