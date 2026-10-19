import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../letters.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/board.dart';
import '../widgets/common.dart';
import '../widgets/profile_parts.dart';
import 'home_screen.dart' show matchCost;
import 'private_game_screen.dart';
import 'waiting_screen.dart';

/// Rezultat partije: obe table (prebacivanje dodirom na karticu igrača) i reči.
/// Odmah posle partije: „Revanš“, „Igraj ponovo“ i „Nazad na meni“.
/// U pregledu iz istorije (`review`) samo prikaz, bez dugmadi.
class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  final bool review;
  const ResultScreen({super.key, required this.result, this.review = false});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showOpponent = false;
  Timer? _tick;
  bool _busy = false;

  String get _matchId => widget.result['matchId'] as String;

  @override
  void initState() {
    super.initState();
    // Odbrojavanje za revanš.
    if (!widget.review && widget.result['rematchUntil'] != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (_secondsLeft <= 0) _tick?.cancel();
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _secondsLeft {
    final until = widget.result['rematchUntil'] as int?;
    if (until == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch + context.read<AppState>().clockOffset;
    return ((until - now) / 1000).ceil().clamp(0, 999);
  }

  Future<void> _playAgain(AppState app) async {
    final nav = Navigator.of(context);
    if (widget.result['mode'] == 'PRIVATE') {
      await app.declineRematch(_matchId);
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

  Future<void> _rematch(AppState app) async {
    setState(() => _busy = true);
    final err = await app.requestRematch(_matchId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) showError(context, err);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final r = widget.result;
    final review = widget.review;
    final mine = !review || r['viewerIsPlayer'] == true;
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
    final loser = outcome == 'WIN' ? opp['username'] : me['username'];
    final reason = switch (r['endReason']) {
      'LIVES_LOST' when mine =>
        outcome == 'WIN' ? 'Protivnik je izgubio sva tri života.' : 'Izgubili ste sva tri života.',
      'RESIGNED' when mine => outcome == 'WIN' ? 'Protivnik je predao partiju.' : 'Predali ste partiju.',
      'LIVES_LOST' => '$loser — izgubljena sva tri života.',
      'RESIGNED' => 'Predaja — $loser.',
      _ => 'Obe table su popunjene.',
    };
    final ended = DateTime.tryParse('${r['endedAt']}')?.toLocal();
    final letters = r['initialLetters'] as int?;

    return GameScaffold(
      title: review ? 'Partija' : 'Kraj partije',
      showBack: review,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (review && !mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${me['username']} protiv ${opp['username']}',
                  textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: textMain)),
            ),
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
          if (!review)
            Text('Ukupno ${fmtPoints(r['totalPoints'])} · Level ${r['level']}',
                textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 13))
          else
            Text(
                [
                  if (letters != null && letters > 0) '$letters ${letters == 1 ? 'početno slovo' : 'početna slova'}',
                  if (ended != null) fmtDateShort(ended),
                ].join(' · '),
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 13)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _ScoreCard(
                label: mine ? 'Moja tabla' : '${me['username']}',
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
          if (!review) ...[
            const SizedBox(height: 6),
            _rematchBlock(app, opp['username'] as String),
            const SizedBox(height: 12),
            GoldButton(label: 'IGRAJ PONOVO', icon: Icons.play_arrow_rounded, onPressed: () => _playAgain(app)),
            const SizedBox(height: 12),
            BlueButton(
              label: 'NAZAD NA MENI',
              onPressed: () {
                app.declineRematch(_matchId);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Revanš: dugme, čekanje na protivnika ili protivnikov zahtev (prihvati / odbij).
  Widget _rematchBlock(AppState app, String oppName) => ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: app.rematch,
        builder: (context, st, _) {
          final s = st != null && st['matchId'] == _matchId ? st : null;
          final status = s?['status'] as String?;
          final left = _secondsLeft;
          Widget child;
          if (status == 'declined' || status == 'expired' || (left <= 0 && status != 'waiting')) {
            child = Text(
              status == 'declined' ? (s!['reason'] ?? 'Revanš nije moguć.') : 'Vreme za revanš je isteklo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 13),
            );
          } else if (status == 'offered') {
            child = Panel(
              borderColor: gold,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Column(children: [
                Text('${s!['from']} traži revanš!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: textMain)),
                const SizedBox(height: 10),
                GoldButton(
                  label: 'PRIHVATI REVANŠ',
                  subtitle: 'još $left s',
                  icon: Icons.replay_rounded,
                  height: 62,
                  trailing: const CostTag(matchCost),
                  onPressed: _busy ? null : () => _rematch(app),
                ),
                TextButton(onPressed: () => app.declineRematch(_matchId), child: const Text('Odbij')),
              ]),
            );
          } else if (status == 'waiting') {
            child = Panel(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text('Čeka se da $oppName prihvati revanš… ($left s)',
                        style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
                  ),
                ]),
                TextButton(onPressed: () => app.declineRematch(_matchId), child: const Text('Otkaži')),
              ]),
            );
          } else {
            child = BlueButton(
              label: 'REVANŠ',
              subtitle: 'isti protivnik · još $left s',
              icon: Icons.replay_rounded,
              height: 62,
              trailing: const CostTag(matchCost, color: Colors.white),
              onPressed: _busy ? null : () => _rematch(app),
            );
          }
          return child;
        },
      );

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
