import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

const _txLabels = {
  'DAILY_REWARD': 'Dnevna nagrada',
  'MATCH_ENTRY': 'Ulaz u partiju',
  'MATCH_REFUND': 'Povraćaj',
  'AD_REWARD': 'Reklama',
  'PURCHASE': 'Kupovina',
  'ADMIN_ADJUST': 'Izmena (podrška)',
  'SIGNUP_BONUS': 'Bonus',
};

class TokensScreen extends StatefulWidget {
  const TokensScreen({super.key});
  @override
  State<TokensScreen> createState() => _TokensScreenState();
}

class _TokensScreenState extends State<TokensScreen> {
  late final Future<dynamic> _history = context.read<AppState>().api.get('/tokens/history');

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tokens = app.user?['tokens'] ?? 0;
    return Scaffold(
      appBar: AppBar(title: const ScreenTitle('Tokeni')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: Transform.scale(scale: 1.4, child: TokenChip(tokens, light: !isDark))),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.calendar_today),
            title: Text('Dnevna nagrada: 30 tokena'),
            subtitle: Text('Dobija se automatski pri prvoj prijavi svakog dana.'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.ondemand_video),
            title: Text('Pogledaj reklamu: +5 tokena'),
            subtitle: Text('Uskoro — nagrada se dodeljuje tek kad oglasni sistem potvrdi da je reklama odgledana.'),
            enabled: false,
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.shopping_cart),
            title: Text('Kupi tokene'),
            subtitle: Text('Uskoro — paketi tokena kroz Google Play / App Store.'),
            enabled: false,
          ),
        ),
        const SizedBox(height: 12),
        const Text('Istorija', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        FutureBuilder(
          future: _history,
          builder: (context, snap) {
            if (!snap.hasData) return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
            final items = (snap.data as List).cast<Map>();
            return Column(children: [
              for (final t in items)
                ListTile(
                  dense: true,
                  title: Text(_txLabels[t['type']] ?? t['type']),
                  subtitle: Text(DateTime.parse(t['createdAt']).toLocal().toString().substring(0, 16)),
                  trailing: Text(
                    '${t['amount'] > 0 ? '+' : ''}${t['amount']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: t['amount'] > 0 ? success : danger,
                    ),
                  ),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}
