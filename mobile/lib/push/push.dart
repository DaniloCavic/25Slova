// Obaveštenja na telefonu. Na webu (iPhone dodat na početni ekran, pregledač) radi Web Push;
// u Android aplikaciji za sada nema (potreban je Firebase).
export 'push_stub.dart' if (dart.library.js_interop) 'push_web.dart';
