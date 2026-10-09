import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../letters.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/board.dart';
import '../widgets/common.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  const ResultScreen({super.key, required this.result});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showOpponent = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final r = widget.result;
    final outcome = r['outcome'] as String;
    final delta = r['pointsDelta'] as int;
    final me = Map<String, dynamic>.from(r['me']);
    final opp = Map<String, dynamic>.from(r['opponent']);
    final shown = _showOpponent ? opp : me;
    final lines = (shown['lines'] as List).cast<Map>();
    final highlighted = <int>{for (final l in lines) ...((l['cells'] as List).cast<int>())};

    final (title, color) = switch (outcome) {
      'WIN' => ('Pobeda!', Colors.green.shade700),
      'LOSS' => ('Poraz', brandRed),
      _ => ('Nerešeno', brandBlue),
    };
    final reason = switch (r['endReason']) {
      'LIVES_LOST' => outcome == 'WIN' ? 'Protivnik je izgubio sva tri života.' : 'Izgubili ste sva tri života.',
      'RESIGNED' => outcome == 'WIN' ? 'Protivnik je predao partiju.' : 'Predali ste partiju.',
      _ => 'Obe table su popunjene.',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Rezultat'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(title,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: color)),
          Text(reason, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Text(
            delta == 0 ? 'Saldo poena nepromenjen' : '${delta > 0 ? '+' : ''}$delta poena',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          Text('Ukupno: ${r['totalPoints']} · Level ${r['level']}', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _ScoreCard(
                    label: 'Ti', data: me, active: !_showOpponent, onTap: () => setState(() => _showOpponent = false))),
            const SizedBox(width: 10),
            Expanded(
                child: _ScoreCard(
                    label: opp['username'],
                    data: opp,
                    active: _showOpponent,
                    onTap: () => setState(() => _showOpponent = true))),
          ]),
          const SizedBox(height: 12),
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
          const Text('Pronađene reči', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (lines.every((l) => l['word'] == null))
            const Text('Nema validnih reči.', style: TextStyle(color: Colors.black54)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final l in lines.where((l) => l['word'] != null))
              Chip(
                label: Text('${showWord(l['word'], app.script)} · ${l['points']}'),
                avatar: Text(_lineName(l), style: const TextStyle(fontSize: 11)),
                backgroundColor: cellWord,
              ),
          ]),
          const SizedBox(height: 20),
          FilledButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Nazad na početni ekran')),
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
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? brandBlue : const Color(0xFFD5DAE3), width: active ? 2 : 1),
          ),
          child: Column(children: [
            Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${data['points']} poena', style: const TextStyle(fontSize: 20)),
            Text('${data['wordsCount']} reči', style: const TextStyle(color: Colors.black54)),
            Lives(data['lives'] as int, size: 14),
          ]),
        ),
      );
}
