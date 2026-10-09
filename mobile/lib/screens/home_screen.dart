import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'waiting_screen.dart';
import 'leaderboard_screen.dart';
import 'best_board_screen.dart';
import 'profile_screen.dart';
import 'tokens_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';

const matchCost = 10;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _go(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Future<void> _playRandom(BuildContext context) async {
    final app = context.read<AppState>();
    final err = await app.joinQueue();
    if (!context.mounted) return;
    if (err != null) return showError(context, err);
    _go(context, const WaitingScreen());
  }

  Future<void> _privateGame(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Kreiraj partiju i pošalji kod'),
            onTap: () => Navigator.pop(context, 'create'),
          ),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Unesi kod prijatelja'),
            onTap: () => Navigator.pop(context, 'join'),
          ),
        ]),
      ),
    );
    if (!context.mounted || choice == null) return;
    final app = context.read<AppState>();
    if (choice == 'create') {
      final err = await app.createPrivate();
      if (!context.mounted) return;
      if (err != null) return showError(context, err);
      _go(context, const WaitingScreen());
    } else {
      final code = await showDialog<String>(context: context, builder: (_) => const _CodeDialog());
      if (code == null || code.isEmpty) return;
      final err = await app.joinPrivate(code);
      if (err != null && context.mounted) showError(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final u = app.user ?? {};
    final tokens = (u['tokens'] ?? 0) as int;
    return Scaffold(
      appBar: AppBar(
        title: const Text('25 Slova'),
        actions: [
          if (!app.socketConnected)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Tooltip(message: 'Povezivanje…', child: Icon(Icons.cloud_off, color: Colors.white70)),
            ),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => _go(context, const SettingsScreen())),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: app.refreshMe,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: InkWell(
                onTap: () => _go(context, const ProfileScreen()),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    UserAvatar(url: u['avatarUrl'], name: u['username'] ?? '', radius: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u['username'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Level ${u['level'] ?? 1} · ${u['totalPoints'] ?? 0} poena',
                            style: const TextStyle(color: Colors.black54)),
                      ]),
                    ),
                    GestureDetector(onTap: () => _go(context, const TokensScreen()), child: TokenChip(tokens)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 64,
              child: FilledButton.icon(
                onPressed: () => _playRandom(context),
                icon: const Icon(Icons.play_arrow, size: 30),
                label: const Text('Igraj — nasumični protivnik', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _privateGame(context),
              icon: const Icon(Icons.group),
              label: const Text('Igraj sa prijateljem (kod)'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Partija košta $matchCost tokena. Tip partije (1, 3 ili 5 početnih slova) je nasumičan.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12)),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _Tile(Icons.leaderboard, 'Rang-liste', () => _go(context, const LeaderboardScreen())),
                _Tile(Icons.emoji_events, 'Najbolja tabla', () => _go(context, const BestBoardScreen())),
                _Tile(Icons.toll, 'Tokeni', () => _go(context, const TokensScreen())),
                _Tile(Icons.person, 'Moj profil', () => _go(context, const ProfileScreen())),
                _Tile(Icons.menu_book, 'Pravila igre', () => _go(context, const RulesScreen())),
                _Tile(Icons.settings, 'Podešavanja', () => _go(context, const SettingsScreen())),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Tile(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: brandBlue, size: 30),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();
  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _c = TextEditingController();
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Kod partije'),
        content: TextField(
          controller: _c,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'npr. K7PM2Q'),
          style: const TextStyle(fontSize: 22, letterSpacing: 4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Otkaži')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.pop(context, _c.text.trim().toUpperCase()),
            child: const Text('Uđi'),
          ),
        ],
      );
}
