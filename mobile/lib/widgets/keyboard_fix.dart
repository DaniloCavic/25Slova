import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import '../push/push.dart' show iosStandalone;

/// iPhone (igra na početnom ekranu) otvara tastaturu samo za pravo HTML polje za unos.
/// Dok je ekran sa poljem za unos otvoren, uključujemo pristupačnost (semantics) — tada su
/// polja prava HTML polja. Na ostalim ekranima je isključena, da skrolovanje i promena
/// izgleda ostanu brzi.
mixin KeyboardFix<T extends StatefulWidget> on State<T> {
  SemanticsHandle? _keyboardFix;

  @override
  void initState() {
    super.initState();
    if (iosStandalone()) _keyboardFix = SemanticsBinding.instance.ensureSemantics();
  }

  @override
  void dispose() {
    _keyboardFix?.dispose();
    _keyboardFix = null;
    super.dispose();
  }
}
