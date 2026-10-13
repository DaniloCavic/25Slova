import 'package:flutter/material.dart';
import '../widgets/common.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'rules_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const ScreenTitle('Podešavanja')),
      body: ListView(children: [
        const ListTile(title: Text('Izgled', style: TextStyle(fontWeight: FontWeight.bold))),
        for (final (mode, label, icon) in [
          ('dark', 'Tamni režim', Icons.dark_mode),
          ('light', 'Svetli režim', Icons.light_mode),
          ('system', 'Prema podešavanju telefona', Icons.brightness_auto),
        ])
          RadioListTile<String>(
            title: Text(label),
            secondary: Icon(icon),
            value: mode,
            groupValue: app.themeMode,
            onChanged: (m) => app.setThemeMode(m!),
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.menu_book),
          title: const Text('Pravila igre'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RulesScreen())),
        ),
        const ListTile(
          leading: Icon(Icons.privacy_tip_outlined),
          title: Text('Politika privatnosti i uslovi korišćenja'),
          subtitle: Text('Biće objavljeni pre izlaska u prodavnice.'),
        ),
        const ListTile(
          leading: Icon(Icons.support_agent),
          title: Text('Podrška'),
          subtitle: Text('podrska@25slova.rs'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Odjava'),
          onTap: () => app.logout(),
        ),
      ]),
    );
  }
}
