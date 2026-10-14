import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'waiting_screen.dart';
import 'private_game_screen.dart';
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
    final err = await context.read<AppState>().joinQueue();
    if (!context.mounted) return;
    if (err != null) return showError(context, err);
    _go(context, const WaitingScreen());
  }

  /// Otvara sistemski meni za deljenje (Viber, WhatsApp, SMS, Instagram, Telegram…).
  void _invite(BuildContext context) {
    const link = '$productionUrl/igra';
    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      'Hajde da igramo 25 Slova — igru rečima na srpskom! Otvori $link i napravi nalog.',
      subject: '25 Slova',
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final u = app.user ?? {};
    final total = (u['totalPoints'] ?? 0) as num;
    return PictureBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: app.refreshMe,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              children: [
                // Gornja traka je preko tamne slike, pa je tekst uvek beo (i u svetlom režimu).
                DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white),
                  child: Row(children: [
                    // Jedna traka: profil levo, tokeni desno.
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _go(context, const ProfileScreen()),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
                          decoration: BoxDecoration(
                            color: headerChipColor,
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Row(children: [
                            UserAvatar(url: u['avatarUrl'], name: u['username'] ?? '', radius: 22, ring: true),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(u['username'] ?? '',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                Text('Level ${u['level'] ?? 1}',
                                    style: const TextStyle(color: gold, fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 3),
                                LevelBar(
                                    progress: u['levelProgress'],
                                    totalPoints: total,
                                    width: 56,
                                    compact: true,
                                    textColor: Colors.white70),
                              ]),
                            ),
                            if (!app.socketConnected)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Tooltip(
                                    message: 'Povezivanje…', child: Icon(Icons.cloud_off, color: Colors.white70)),
                              ),
                            TokenChip((u['tokens'] ?? 0) as int, onTap: () => _go(context, const TokensScreen())),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Material(
                      color: headerChipColor,
                      shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: () => _go(context, const SettingsScreen()),
                      ),
                    ),
                  ]),
                ),
                // Prostor za logo sa pozadinske slike.
                SizedBox(height: (PictureBackground.logoBottom(context) - 70).clamp(120.0, 600.0)),
                GoldButton(
                  label: 'IGRAJ',
                  subtitle: 'nasumični protivnik',
                  icon: Icons.play_arrow_rounded,
                  height: 72,
                  trailing: const CostTag(matchCost),
                  onPressed: () => _playRandom(context),
                ),
                const SizedBox(height: 12),
                BlueButton(
                  label: 'IGRAJ SA PRIJATELJEM',
                  subtitle: 'pošalji ili unesi kod',
                  icon: Icons.group,
                  height: 64,
                  trailing: const CostTag(matchCost, color: Colors.white),
                  onPressed: () => _go(context, const PrivateGameScreen()),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.75,
                  children: [
                    MenuTile(Icons.emoji_events, 'Rang liste', () => _go(context, const LeaderboardScreen())),
                    MenuTile(Icons.monetization_on, 'Tokeni', () => _go(context, const TokensScreen()),
                        iconWidget: const CoinIcon(size: 34)),
                    MenuTile(Icons.grid_view_rounded, 'Najbolja tabla', () => _go(context, const BestBoardScreen())),
                    MenuTile(Icons.person, 'Moj profil', () => _go(context, const ProfileScreen())),
                    MenuTile(Icons.menu_book, 'Pravila igre', () => _go(context, const RulesScreen())),
                    MenuTile(Icons.group_add, 'Pozovi prijatelje', () => _invite(context)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
