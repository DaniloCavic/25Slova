import 'dart:js_interop';

@JS('slovaPush.supported')
external bool _supported();

@JS('slovaPush.permission')
external String _permission();

@JS('slovaPush.subscribe')
external JSPromise<JSString> _subscribe(String vapidKey, bool ask);

bool pushSupported() {
  try {
    return _supported();
  } catch (_) {
    return false;
  }
}

String pushPermission() {
  try {
    return _permission();
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> pushSubscribe(String vapidKey, {bool ask = false}) async {
  try {
    return (await _subscribe(vapidKey, ask).toDart).toDart;
  } catch (_) {
    return '';
  }
}

@JS('slovaPush.subscribeOnFirstTap')
external JSPromise<JSString> _subscribeOnFirstTap(String vapidKey);

Future<String> pushSubscribeOnFirstTap(String vapidKey) async {
  try {
    return (await _subscribeOnFirstTap(vapidKey).toDart).toDart;
  } catch (_) {
    return '';
  }
}
