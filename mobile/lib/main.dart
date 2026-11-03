import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import 'push/push.dart' show iosStandalone;
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/announcement.dart';
import 'widgets/challenge_overlay.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // iPhone sa igrom na početnom ekranu ne otvara tastaturu za skriveno polje za unos;
  // sa uključenom pristupačnošću (semantics) polja su prava HTML polja i tastatura radi.
  if (iosStandalone()) SemanticsBinding.instance.ensureSemantics();
  final state = AppState()..init();
  runApp(ChangeNotifierProvider.value(value: state, child: const SlovaApp()));
}

class SlovaApp extends StatelessWidget {
  const SlovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    // Pri promeni režima (tamni/svetli) aplikacija se ponovo iscrtava novim bojama.
    final themeVersion = context.select<AppState, int>((s) => s.themeVersion);
    return MaterialApp(
      key: ValueKey(themeVersion),
      title: '25 Slova',
      // Boja trake sa satom i baterijom (iPhone / web) — ista tamnoplava u oba režima.
      color: const Color(0xFF102552),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: app.navigatorKey,
      scaffoldMessengerKey: app.messengerKey,
      // Dnevna nagrada, medalje i izazovi prijatelja se prikazuju preko celog ekrana.
      // Dodir van polja za unos zatvara tastaturu (i sledeći dodir na polje je ponovo otvara).
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: AnnouncementOverlay(child: ChallengeOverlay(child: child!)),
      ),
      home: Selector<AppState, AuthStatus>(
        selector: (_, s) => s.status,
        builder: (_, status, __) => switch (status) {
          AuthStatus.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
          AuthStatus.loggedOut => const LoginScreen(),
          AuthStatus.loggedIn => const HomeScreen(),
        },
      ),
    );
  }
}
