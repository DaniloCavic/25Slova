bool pushSupported() => false;

/// granted | denied | default | unsupported
String pushPermission() => 'unsupported';

/// Vraća pretplatu kao JSON tekst ili '' ako nije dozvoljeno.
Future<String> pushSubscribe(String vapidKey, {bool ask = false}) async => '';
