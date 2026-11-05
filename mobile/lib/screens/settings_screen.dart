import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../widgets/common.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'rules_screen.dart';
import '../sound.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const ScreenTitle('Podešavanja')),
      body: ListView(children: [
        const ListTile(title: Text('Izgled', style: TextStyle(fontWeight: FontWeight.bold))),
        RadioGroup<String>(
          groupValue: app.themeMode,
          onChanged: (m) => app.setThemeMode(m!),
          child: Column(children: [
            for (final (mode, label, icon) in [
              ('dark', 'Tamni režim', Icons.dark_mode),
              ('light', 'Svetli režim', Icons.light_mode),
            ])
              RadioListTile<String>(title: Text(label), secondary: Icon(icon), value: mode),
          ]),
        ),
        const Divider(),
        const _PushTile(),
        const _SoundTile(),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.menu_book),
          title: const Text('Pravila igre'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RulesScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Politika privatnosti'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => launchUrl(Uri.parse('$productionUrl/privatnost'), mode: LaunchMode.externalApplication),
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

/// Obaveštenja — podrazumevano uključena, igrač ih može isključiti.
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
    return SwitchListTile(
      secondary: Icon(app.pushOn ? Icons.notifications_active : Icons.notifications_off_outlined),
      title: const Text('Obaveštenja'),
      value: app.pushOn,
      onChanged: _busy
          ? null
          : (v) async {
              setState(() => _busy = true);
              final err = await app.setPushOn(v);
              if (!context.mounted) return;
              setState(() => _busy = false);
              if (err != null) showError(context, err);
            },
    );
  }
}

/// Zvuci u igri — podrazumevano uključeni.
class _SoundTile extends StatefulWidget {
  const _SoundTile();
  @override
  State<_SoundTile> createState() => _SoundTileState();
}

class _SoundTileState extends State<_SoundTile> {
  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: Icon(Sound.enabled ? Icons.volume_up : Icons.volume_off),
        title: const Text('Zvukovi'),
        value: Sound.enabled,
        onChanged: (v) async {
          await Sound.setEnabled(v);
          if (mounted) setState(() {});
        },
      );
}
