import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Android aplikacija: obaveštenja preko Firebase (FCM). Podešavanja projekta su u android/app/google-services.json.
bool get fcmAvailable => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool _ready = false;

Future<FirebaseMessaging> _messaging() async {
  if (!_ready) {
    await Firebase.initializeApp();
    _ready = true;
  }
  return FirebaseMessaging.instance;
}

/// Traži dozvolu (Android 13+) i vraća token uređaja, ili null ako obaveštenja nisu dozvoljena.
Future<String?> fcmToken() async {
  try {
    final m = await _messaging();
    final s = await m.requestPermission();
    if (s.authorizationStatus == AuthorizationStatus.denied) return null;
    return await m.getToken();
  } catch (e) {
    debugPrint('FCM: $e');
    return null;
  }
}

/// Novi token (Firebase ga povremeno menja) — treba ga ponovo poslati serveru.
Future<void> onFcmTokenRefresh(void Function(String token) cb) async {
  try {
    (await _messaging()).onTokenRefresh.listen(cb);
  } catch (_) {}
}

Future<void> fcmDeleteToken() async {
  try {
    await (await _messaging()).deleteToken();
  } catch (_) {}
}
