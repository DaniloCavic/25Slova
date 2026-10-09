import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../letters.dart';
import '../state/app_state.dart';
import 'rules_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Podešavanja')),
      body: ListView(children: [
        const ListTile(title: Text('Pismo slova na tabli', style: TextStyle(fontWeight: FontWeight.bold))),
        RadioListTile<Script>(
          title: const Text('Latinica (A B C Č Ć …)'),
          value: Script.latin,
          groupValue: app.script,
          onChanged: (s) => app.setScript(s!),
        ),
        RadioListTile<Script>(
          title: const Text('Ćirilica (А Б В Г Д …)'),
          value: Script.cyrillic,
          groupValue: app.script,
          onChanged: (s) => app.setScript(s!),
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
