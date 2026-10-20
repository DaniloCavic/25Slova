import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/announcement.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      // Dnevna nagrada i medalje se prikazuju preko celog ekrana.
      builder: (context, child) => AnnouncementOverlay(child: child!),
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
