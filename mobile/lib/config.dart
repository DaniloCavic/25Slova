import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;

/// Adresa servera. Za produkciju se zadaje pri izgradnji:
///   flutter build apk --dart-define=API_URL=https://api.25slova.rs
/// U razvoju: Android emulator vidi računar kao 10.0.2.2, iOS simulator kao localhost.
/// Za pravi telefon u istoj mreži: --dart-define=API_URL=http://192.168.x.x:3000
const _fromEnv = String.fromEnvironment('API_URL');
const productionUrl = 'https://25slova-production.up.railway.app';

String get apiBaseUrl {
  if (_fromEnv.isNotEmpty) return _fromEnv;
  // Web verzija se servira sa istog servera, pa koristi istu adresu.
  if (kIsWeb && kReleaseMode) return Uri.base.origin;
  // Izgrađena (release) aplikacija se uvek povezuje na pravi server.
  if (kReleaseMode) return productionUrl;
  if (kIsWeb) return 'http://localhost:3000';
  return defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
}

String? absoluteUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  return path.startsWith('http') ? path : '$apiBaseUrl$path';
}
