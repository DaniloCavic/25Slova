import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/profile_parts.dart';

/// Profil drugog igrača (otvara se dodirom na igrača na rang listi):
/// level, bodovi po periodima, učinak, međusobni skor, medalje i poslednjih 10 partija.
/// Otvara se sa rang liste i iz liste prijatelja.
class PlayerProfileScreen extends StatefulWidget {
  final String userId;
  const PlayerProfileScreen({super.key, required this.userId});
  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  late Future<dynamic> _f = _fetch();

  Future<dynamic> _fetch() => context.read<AppState>().api.get('/players/${widget.userId}');

  Future<void> _unfriend(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ukloni prijatelja'),
        content: Text('Da li želiš da ukloniš $name sa liste prijatelja?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Ne')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ukloni')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final app = context.read<AppState>();
    try {
      await app.api.delete('/friends/${widget.userId}');
      app.friendsVersion.value++;
      if (mounted) setState(() => _f = _fetch());
    } catch (e) {
      if (mounted) showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => GameScaffold(
        title: 'Profil igrača',
        body: FutureBuilder(
          future: _f,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(snap.error.toString())));
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final u = Map<String, dynamic>.from(snap.data as Map);
            final st = Map<String, dynamic>.from(u['stats'] as Map);
            final played = st['played'] as int;
            final winRate = played == 0 ? 0 : ((st['wins'] as int) * 100 / played).round();
            return ListView(padding: const EdgeInsets.all(16), children: [
              Center(child: UserAvatar(url: u['avatarUrl'], name: u['username'] ?? '', radius: 54, ring: true)),
              const SizedBox(height: 8),
              Text(u['username'] ?? '',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              if (u['isFriend'] == true)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2ECC71)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.people_alt_rounded, size: 15, color: Color(0xFF2ECC71)),
                      SizedBox(width: 5),
                      Text('Prijatelj',
                          style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.w800, fontSize: 13)),
                    ]),
                  ),
                ),
              Text('Level ${u['level'] ?? 1}',
                  textAlign: TextAlign.center, style: TextStyle(color: goldAccent, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: () => showLevelsSheet(context, current: u['level'] as int?),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    LevelBar(progress: u['levelProgress'], totalPoints: u['totalPoints'] as num, width: 160),
                    const SizedBox(width: 6),
                    Icon(Icons.info_outline, size: 18, color: textMuted),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                StatTile(Icons.emoji_events, 'Ukupno', fmtPointsShort(u['totalPoints'])),
                StatTile(Icons.date_range, 'Nedelja', fmtPointsShort(u['weeklyPoints'])),
                StatTile(Icons.calendar_month, 'Mesec', fmtPointsShort(u['monthlyPoints'])),
                StatTile(Icons.bar_chart, 'Godina', fmtPointsShort(u['yearlyPoints'])),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                StatTile(Icons.sports_esports, 'Partije', played),
                StatTile(Icons.check_circle, 'Pobede', st['wins'], valueColor: success),
                StatTile(Icons.cancel, 'Porazi', st['losses'], valueColor: danger),
                StatTile(Icons.percent, 'Uspeh', '$winRate%'),
              ]),
              if (u['h2h'] != null) ...[
                const SizedBox(height: 14),
                _HeadToHead(Map<String, dynamic>.from(u['h2h'] as Map), u['username'] ?? ''),
              ],
              const SizedBox(height: 18),
              MedalsSection((u['medals'] as List).cast<Map>(), emptyText: 'Ovaj igrač još nema medalja.'),
              const SizedBox(height: 18),
              RecentMatches((u['recent'] as List).cast<Map>(), asUserId: u['id']),
              if (u['isFriend'] == true) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.person_remove, color: danger),
                    label: const Text('Ukloni iz prijatelja', style: TextStyle(color: danger)),
                    onPressed: () => _unfriend(u['username'] ?? ''),
                  ),
                ),
              ],
            ]);
          },
        ),
      );
}

/// Međusobni skor: moje pobede : pobede protivnika (i nerešene).
class _HeadToHead extends StatelessWidget {
  final Map<String, dynamic> h;
  final String name;
  const _HeadToHead(this.h, this.name);

  @override
  Widget build(BuildContext context) {
    final wins = h['wins'] as int, losses = h['losses'] as int, draws = h['draws'] as int;
    final total = wins + losses + draws;
    Widget side(String label, int n, Color c) => Expanded(
          child: Column(children: [
            Text('$n', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: c)),
            Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: textMuted, fontSize: 13)),
          ]),
        );
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(children: [
        Text('MEĐUSOBNI SKOR',
            style: TextStyle(fontWeight: FontWeight.w900, color: textMain, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        if (total == 0)
          Text('Još niste igrali jedan protiv drugog.', style: TextStyle(color: textMuted))
        else ...[
          Row(children: [
            side('Ja', wins, wins >= losses ? success : textMain),
            Text(':', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: textMuted)),
            side(name, losses, losses > wins ? danger : textMain),
          ]),
          const SizedBox(height: 4),
          Text(
              '$total ${total == 1 ? 'partija' : (total % 10 >= 2 && total % 10 <= 4 && (total % 100 < 12 || total % 100 > 14)) ? 'partije' : 'partija'}'
              '${draws > 0 ? ' · nerešeno $draws' : ''}',
              style: TextStyle(color: textMuted, fontSize: 13)),
        ],
      ]),
    );
  }
}
