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
        ])
          RadioListTile<String>(
            title: Text(label),
            secondary: Icon(icon),
            value: mode,
            groupValue: app.themeMode,
            onChanged: (m) => app.setThemeMode(m!),
          ),
        const Divider(),
        const ListTile(title: Text('Obaveštenja', style: TextStyle(fontWeight: FontWeight.bold))),
        const _PushTile(),
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

/// Uključivanje obaveštenja: kada si na potezu, kada osvojiš medalju i podsetnik za dnevnu nagradu (11:00).
class _PushTile extends StatefulWidget {
  const _PushTile();
  @override
  State<_PushTile> createState() => _PushTileState();
}

class _PushTileState extends State<_PushTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final state = app.pushPermissionState;
    final on = state == 'granted';
    final subtitle = switch (state) {
      'granted' => 'Uključena: kada si na potezu, kada osvojiš medalju i u 11:00 ako dnevna nagrada još nije preuzeta.',
      'denied' => 'Blokirana u podešavanjima telefona. Uključi ih tamo za 25 Slova.',
      'unsupported' => 'Na iPhone-u: dodaj igru na početni ekran (Share → Add to Home Screen) i otvori je odatle. '
          'U Android aplikaciji obaveštenja stižu uskoro.',
      _ => 'Dodirni da uključiš — telefon će pitati za dozvolu.',
    };
    return ListTile(
      leading: Icon(on ? Icons.notifications_active : Icons.notifications_off_outlined),
      title: Text(on ? 'Obaveštenja su uključena' : 'Uključi obaveštenja'),
      subtitle: Text(subtitle),
      trailing: _busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
          : on
              ? TextButton(
                  onPressed: () async {
                    await app.api.post('/push/test');
                  },
                  child: const Text('Probaj'))
              : null,
      onTap: on || state == 'unsupported' || _busy
          ? null
          : () async {
              setState(() => _busy = true);
              final err = await app.enablePush();
              if (!context.mounted) return;
              setState(() => _busy = false);
              if (err != null) {
                showError(context, err);
              } else {
                app.toast('Obaveštenja su uključena 🔔');
              }
            },
    );
  }
}
