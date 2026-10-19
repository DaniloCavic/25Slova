import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/profile_parts.dart';

/// Profil drugog igrača (otvara se dodirom na igrača na rang listi):
/// level, poeni po periodima, učinak, medalje i poslednjih 10 partija.
class PlayerProfileScreen extends StatefulWidget {
  final String userId;
  const PlayerProfileScreen({super.key, required this.userId});
  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  late final Future<dynamic> _f = context.read<AppState>().api.get('/players/${widget.userId}');

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
              const SizedBox(height: 18),
              MedalsSection((u['medals'] as List).cast<Map>(), emptyText: 'Ovaj igrač još nema medalja.'),
              const SizedBox(height: 18),
              RecentMatches((u['recent'] as List).cast<Map>(), asUserId: u['id']),
            ]);
          },
        ),
      );
}
