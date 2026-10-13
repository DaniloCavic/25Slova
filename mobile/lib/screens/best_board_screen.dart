import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../letters.dart';
import '../state/app_state.dart';
import '../widgets/board.dart';
import '../widgets/common.dart';
import '../theme.dart';

/// „Najbolja tabla ikad“ — ukupni rekord i posebni rekordi za 1, 3 i 5 početnih slova.
class BestBoardScreen extends StatefulWidget {
  const BestBoardScreen({super.key});
  @override
  State<BestBoardScreen> createState() => _BestBoardScreenState();
}

class _BestBoardScreenState extends State<BestBoardScreen> {
  late final Future<dynamic> _f = context.read<AppState>().api.get('/best-board');
  String _tab = 'overall';

  @override
  Widget build(BuildContext context) {
    final script = context.watch<AppState>().script;
    return Scaffold(
      appBar: AppBar(title: const Text('Najbolja tabla ikad')),
      body: FutureBuilder(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data as Map;
          final by = data['byInitialLetters'] as Map;
          final rec = (_tab == 'overall' ? data['overall'] : by[_tab]) as Map?;
          return ListView(padding: const EdgeInsets.all(16), children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'overall', label: Text('Ukupno')),
                ButtonSegment(value: '1', label: Text('1 slovo')),
                ButtonSegment(value: '3', label: Text('3 slova')),
                ButtonSegment(value: '5', label: Text('5 slova')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            const SizedBox(height: 16),
            if (rec == null)
              const Padding(padding: EdgeInsets.all(32), child: Text('Još nema rekorda.', textAlign: TextAlign.center))
            else ...[
              Row(children: [
                UserAvatar(url: rec['avatarUrl'], name: rec['username'] ?? '', radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rec['username'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                        'Level ${rec['level']} · ${rec['initialLetters']} početn${rec['initialLetters'] == 1 ? 'o slovo' : 'a slova'}'),
                  ]),
                ),
                Column(children: [
                  Text('${rec['points']}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: brandBlue)),
                  Text('${rec['wordsCount']} reči'),
                ]),
              ]),
              const SizedBox(height: 16),
              Center(
                child: BoardGrid(
                  board: rec['board'] as List,
                  script: script,
                  initialCells: Set<int>.from(rec['initialCells'] as List),
                  highlighted: {
                    for (final w in (rec['words'] as List? ?? []).cast<Map>()) ...(w['cells'] as List).cast<int>(),
                  },
                  maxSize: 360,
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.square, color: cellInitial),
                const Text(' početna nasumična slova   '),
                Icon(Icons.square, color: cellWord),
                const Text(' reči'),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final w in (rec['words'] as List? ?? []).cast<Map>())
                  Chip(label: Text('${showWord(w['word'], script)} · ${w['points']}')),
              ]),
            ],
          ]);
        },
      ),
    );
  }
}
