import 'package:flutter/material.dart';
import '../screens/match_detail_screen.dart';
import '../theme.dart';
import 'common.dart';

/// Kockica sa jednim podatkom (Ukupno, Nedelja, Tokeni…).
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic value;
  final Widget? iconWidget;
  final Color? valueColor;
  const StatTile(this.icon, this.label, this.value, {super.key, this.iconWidget, this.valueColor});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Panel(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Column(children: [
              iconWidget ?? Icon(icon, color: gold, size: 22),
              const SizedBox(height: 4),
              FittedBox(
                  child: Text('${value ?? 0}',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: valueColor))),
              FittedBox(child: Text(label, style: TextStyle(fontSize: 11, color: textMuted))),
            ]),
          ),
        ),
      );
}

/// Medalje: broj zlatnih, srebrnih i bronzanih + spisak za koji period.
class MedalsSection extends StatelessWidget {
  final List<Map> medals;
  final String emptyText;
  const MedalsSection(this.medals, {super.key, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    int count(int place) => medals.where((m) => m['place'] == place).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Medalje', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 8),
      Row(children: [
        for (final place in [1, 2, 3])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Panel(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  Icon(Icons.military_tech,
                      size: 40, color: count(place) > 0 ? medalColor(place) : textMuted.withOpacity(0.35)),
                  Text(['Zlatne', 'Srebrne', 'Bronzane'][place - 1], style: TextStyle(fontSize: 12, color: textMuted)),
                  Text('${count(place)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      if (medals.isEmpty)
        Text(emptyText, style: TextStyle(color: textMuted, fontSize: 13))
      else
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in medals.take(12))
            Chip(
              avatar: Icon(Icons.military_tech, color: medalColor(m['place'])),
              label: Text('${m['place']}. mesto · ${medalPeriodLabel(m['period'], m['periodKey'])}'),
            ),
        ]),
    ]);
  }
}

/// Poslednje partije (najviše 10); dodir otvara partiju sa obe table i rečima.
class RecentMatches extends StatelessWidget {
  final List<Map> matches;

  /// Čiji je profil (za profile drugih igrača) — partija se prikazuje iz njegovog ugla.
  final String? asUserId;
  const RecentMatches(this.matches, {super.key, this.asUserId});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Poslednje partije', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 8),
        if (matches.isEmpty) Text('Još nema odigranih partija.', style: TextStyle(color: textMuted)),
        for (final m in matches) _MatchTile(m, asUserId: asUserId),
      ]);
}

class _MatchTile extends StatelessWidget {
  final Map m;
  final String? asUserId;
  const _MatchTile(this.m, {this.asUserId});

  @override
  Widget build(BuildContext context) {
    final outcome = m['outcome'];
    final delta = m['pointsDelta'] as num;
    final ended = DateTime.tryParse('${m['endedAt']}')?.toLocal();
    final letters = m['initialLetters'] as int?;
    final sub = [
      '${m['myScore']} : ${m['opponentScore']} poena',
      if (letters != null && letters > 0) '$letters ${letters == 1 ? 'slovo' : 'slova'}',
      if (ended != null) fmtDateShort(ended),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Panel(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: m['matchId'], asUserId: asUserId)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Icon(
            outcome == 'WIN'
                ? Icons.check_circle
                : outcome == 'LOSS'
                    ? Icons.cancel
                    : Icons.remove_circle,
            color: outcome == 'WIN' ? success : (outcome == 'LOSS' ? danger : textMuted),
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('protiv ${m['opponent'] ?? '—'}',
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(sub, style: TextStyle(color: textMuted, fontSize: 12)),
            ]),
          ),
          Text(fmtSignedPoints(delta),
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: delta > 0 ? success : (delta < 0 ? danger : textMuted))),
          Icon(Icons.chevron_right, color: textMuted),
        ]),
      ),
    );
  }
}

/// 14.10. 22:15 (ove godine) ili 14.10.2025.
String fmtDateShort(DateTime d) {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  if (d.year != now.year) return '${d.day}.${d.month}.${d.year}.';
  return '${d.day}.${d.month}. ${two(d.hour)}:${two(d.minute)}';
}
