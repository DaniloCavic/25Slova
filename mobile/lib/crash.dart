import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'push/push_fcm.dart' show fcmAvailable;

/// Izveštaji o rušenju (Firebase Crashlytics) — samo Android aplikacija.
/// Vide se u Firebase konzoli → Crashlytics.
Future<void> initCrashReporting() async {
  if (!fcmAvailable) return;
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    final c = FirebaseCrashlytics.instance;
    await c.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = c.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      c.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Crashlytics: $e');
  }
}

/// Uz izveštaj o grešci ide i korisničko ime igrača (lakše je pronaći šta mu se desilo).
void setCrashUser(String? username) {
  if (!fcmAvailable) return;
  try {
    FirebaseCrashlytics.instance.setUserIdentifier(username ?? '');
  } catch (_) {}
}
