bool pushSupported() => false;

/// granted | denied | default | unsupported
String pushPermission() => 'unsupported';

/// Vraća pretplatu kao JSON tekst ili '' ako nije dozvoljeno.
Future<String> pushSubscribe(String vapidKey, {bool ask = false}) async => '';

/// Posle prvog dodira na ekran traži dozvolu i pretplatu (iPhone traži da to bude posle dodira).
Future<String> pushSubscribeOnFirstTap(String vapidKey) async => '';
