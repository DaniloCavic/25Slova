import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../letters.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/board.dart';
import '../widgets/common.dart';
import 'private_game_screen.dart';
import 'waiting_screen.dart';

/// Rezultat partije: obe table (prebacivanje dodirom na karticu igrača), reči,
/// pa „Igraj ponovo“ (isti način kao prethodna partija) i „Nazad na meni“.
class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  const ResultScreen({super.key, required this.result});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showOpponent = false;

  Future<void> _playAgain(AppState app) async {
    final nav = Navigator.of(context);
    if (widget.result['mode'] == 'PRIVATE') {
      nav.popUntil((r) => r.isFirst);
      nav.push(MaterialPageRoute(builder: (_) => const PrivateGameScreen()));
      return;
    }
    final err = await app.joinQueue();
    if (!mounted) return;
    if (err != null) return showError(context, err);
    nav.popUntil((r) => r.isFirst);
    nav.push(MaterialPageRoute(builder: (_) => const WaitingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final r = widget.result;
    final outcome = r['outcome'] as String;
    final delta = r['pointsDelta'] as num;
    final me = Map<String, dynamic>.from(r['me']);
    final opp = Map<String, dynamic>.from(r['opponent']);
    final shown = _showOpponent ? opp : me;
    final lines = (shown['lines'] as List).cast<Map>();
    final highlighted = <int>{for (final l in lines) ...((l['cells'] as List).cast<int>())};

    final (title, color) = switch (outcome) {
      'WIN' => ('POBEDA!', goldAccent),
      'LOSS' => ('PORAZ', danger),
      _ => ('NEREŠENO', brandBlue),
    };
    final reason = switch (r['endReason']) {
      'LIVES_LOST' => outcome == 'WIN' ? 'Protivnik je izgubio sva tri života.' : 'Izgubili ste sva tri života.',
      'RESIGNED' => outcome == 'WIN' ? 'Protivnik je predao partiju.' : 'Predali ste partiju.',
      _ => 'Obe table su popunjene.',
    };

    return GameScaffold(
      title: 'Kraj partije',
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(title,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: color)),
          Text(reason, textAlign: TextAlign.center, style: TextStyle(color: textMuted)),
          const SizedBox(height: 6),
          Text(
            delta == 0 ? 'Saldo poena nepromenjen' : '${fmtSignedPoints(delta)} poena',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: delta > 0 ? goldAccent : (delta < 0 ? danger : textMuted)),
          ),
          Text('Ukupno ${fmtPoints(r['totalPoints'])} · Level ${r['level']}',
              textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 13)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _ScoreCard(
                label: 'Moja tabla',
                data: me,
                active: !_showOpponent,
                onTap: () => setState(() => _showOpponent = false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ScoreCard(
                label: '${opp['username']}',
                data: opp,
                active: _showOpponent,
                onTap: () => setState(() => _showOpponent = true),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Dodirni karticu da vidiš tu tablu',
              textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          Center(
            child: BoardGrid(
              board: shown['board'] as List,
              script: app.script,
              initialCells: Set<int>.from(r['initialCells'] as List),
              highlighted: highlighted,
              maxSize: 360,
            ),
          ),
          const SizedBox(height: 12),
          Text('Pronađene reči', style: TextStyle(fontWeight: FontWeight.w800, color: textMain)),
          const SizedBox(height: 6),
          if (lines.every((l) => l['word'] == null)) Text('Nema validnih reči.', style: TextStyle(color: textMuted)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final l in lines.where((l) => l['word'] != null))
              Chip(
                label: Text('${showWord(l['word'], app.script)} · ${l['points']}'),
                avatar: Text(_lineName(l), style: TextStyle(fontSize: 11, color: textMuted)),
              ),
          ]),
          const SizedBox(height: 20),
          GoldButton(label: 'IGRAJ PONOVO', icon: Icons.play_arrow_rounded, onPressed: () => _playAgain(app)),
          const SizedBox(height: 12),
          BlueButton(label: 'NAZAD NA MENI', onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
        ],
      ),
    );
  }

  String _lineName(Map l) => switch (l['kind']) {
        'ROW' => 'R${l['index'] + 1}',
        'COL' => 'K${l['index'] + 1}',
        _ => l['index'] == 0 ? '↘' : '↙',
      };
}

class _ScoreCard extends StatelessWidget {
  final String label;
  final Map<String, dynamic> data;
  final bool active;
  final VoidCallback onTap;
  const _ScoreCard({required this.label, required this.data, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Panel(
        onTap: onTap,
        color: active ? panelLight : null,
        borderColor: active ? gold : panelBorder,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(children: [
          Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: textMain)),
          Text('${data['points']} poena', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textMain)),
          Text('${data['wordsCount']} reči', style: TextStyle(color: textMuted)),
          const SizedBox(height: 2),
          Lives(data['lives'] as int, size: 14),
        ]),
      );
}
