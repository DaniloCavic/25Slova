import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../letters.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/board.dart';
import '../widgets/common.dart';
import 'waiting_screen.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  const ResultScreen({super.key, required this.result});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showOpponent = false;
  bool _showBoards = false;

  Future<void> _playAgain(AppState app) async {
    final err = await app.joinQueue();
    if (!mounted) return;
    if (err != null) return showError(context, err);
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WaitingScreen()));
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

    final (title, color, icon) = switch (outcome) {
      'WIN' => ('POBEDA!', gold, Icons.emoji_events),
      'LOSS' => ('PORAZ', danger, Icons.sentiment_dissatisfied),
      _ => ('NEREŠENO', brandBlue, Icons.handshake),
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [color.withOpacity(0.35), Colors.transparent]),
              ),
              child: Icon(icon, size: 112, color: color),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 8),
              decoration: BoxDecoration(
                gradient: outcome == 'WIN' ? goldGradient : null,
                color: outcome == 'WIN' ? null : panelLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: outcome == 'WIN' ? const Color(0xFFFFE9A6) : panelBorder),
              ),
              child: Text(title,
                  style:
                      TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: outcome == 'WIN' ? goldText : color)),
            ),
          ),
          const SizedBox(height: 12),
          Text(app.user?['username'] ?? '',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(
            delta == 0 ? 'Saldo poena nepromenjen' : '${fmtSignedPoints(delta)} poena',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: delta > 0 ? goldAccent : (delta < 0 ? danger : textMuted)),
          ),
          Text('$reason  ·  Ukupno ${fmtPoints(r['totalPoints'])} · Level ${r['level']}',
              textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 13)),
          const SizedBox(height: 16),
          Panel(
            child: IntrinsicHeight(
              child: Row(children: [
                Expanded(child: _PlayerScore(data: me, winner: outcome == 'WIN')),
                VerticalDivider(color: panelBorder, width: 20),
                Expanded(child: _PlayerScore(data: opp, winner: outcome == 'LOSS')),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          GoldButton(label: 'IGRAJ PONOVO', icon: Icons.play_arrow_rounded, onPressed: () => _playAgain(app)),
          const SizedBox(height: 12),
          BlueButton(label: 'NAZAD NA MENI', onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _showBoards = !_showBoards),
            icon: Icon(_showBoards ? Icons.expand_less : Icons.expand_more),
            label: Text(_showBoards ? 'Sakrij table' : 'Pogledaj table i reči'),
          ),
          if (_showBoards) ...[
            SegmentedButton<bool>(
              segments: [
                const ButtonSegment(value: false, label: Text('Moja tabla')),
                ButtonSegment(value: true, label: Text('${opp['username']}')),
              ],
              selected: {_showOpponent},
              onSelectionChanged: (s) => setState(() => _showOpponent = s.first),
            ),
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
            if (lines.every((l) => l['word'] == null)) Text('Nema validnih reči.', style: TextStyle(color: textMuted)),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final l in lines.where((l) => l['word'] != null))
                Chip(
                  label: Text('${showWord(l['word'], app.script)} · ${l['points']}'),
                  avatar: Text(_lineName(l), style: TextStyle(fontSize: 11, color: textMuted)),
                ),
            ]),
          ],
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

class _PlayerScore extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool winner;
  const _PlayerScore({required this.data, required this.winner});

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(height: 22, child: winner ? const Icon(Icons.workspace_premium, color: gold) : null),
        UserAvatar(url: data['avatarUrl'], name: data['username'] ?? '', radius: 26, ring: winner),
        const SizedBox(height: 6),
        Text('${data['username']}',
            overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('${data['points']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        Text('poena · ${data['wordsCount']} reči', style: TextStyle(color: textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Lives(data['lives'] as int, size: 14),
      ]);
}
