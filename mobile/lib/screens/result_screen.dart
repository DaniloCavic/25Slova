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
import '../sound.dart';
import '../widgets/share_result.dart';
import '../widgets/challenge_overlay.dart' show PopupCard;

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
    _app.rematch.addListener(_onRematch);
    if (!widget.review) {
      Sound.play(switch (widget.result['outcome']) { 'WIN' => Sfx.win, 'LOSS' => Sfx.lose, _ => Sfx.draw });
    }
    // Odbrojavanje za revanš.
    if (!widget.review && widget.result['rematchUntil'] != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (_secondsLeft <= 0) _tick?.cancel();
      });
    }
  }

  late final AppState _app = context.read<AppState>();

  void _onRematch() {
    final st = _app.rematch.value;
    if (st != null && st['matchId'] == _matchId && st['status'] == 'declined' && st['reason'] != null) {
      _app.toast(st['reason'] as String, error: true);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _app.rematch.removeListener(_onRematch);
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
      actions: [
        if (mine)
          IconButton(
            tooltip: 'Podeli rezultat',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => showShareResult(context, r),
          ),
      ],
      body: Stack(children: [
        Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                if (review && !mine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('${me['username']} protiv ${opp['username']}',
                        textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: textMain)),
                  ),
                Text(title,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w900, color: color)),
                Text(reason, textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  delta == 0 ? 'Saldo bodova nepromenjen' : '${fmtSignedPoints(delta)} bodova',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: delta > 0 ? goldAccent : (delta < 0 ? danger : textMuted)),
                ),
                Text(
                    review
                        ? [
                            if (letters != null && letters > 0)
                              '$letters ${letters == 1 ? 'početno slovo' : 'početna slova'}',
                            if (ended != null) fmtDateShort(ended),
                          ].join(' · ')
                        : 'Ukupno ${fmtPoints(r['totalPoints'])} · Level ${r['level']}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textMuted, fontSize: 12)),
                const SizedBox(height: 10),
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
                const SizedBox(height: 4),
                Text('Dodirni karticu da vidiš tu tablu',
                    textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 11)),
                const SizedBox(height: 8),
                Center(
                  child: BoardGrid(
                    board: shown['board'] as List,
                    script: app.script,
                    initialCells: Set<int>.from(r['initialCells'] as List),
                    highlighted: highlighted,
                    maxSize: 330,
                  ),
                ),
                const SizedBox(height: 10),
                Text('Pronađene reči', style: TextStyle(fontWeight: FontWeight.w800, color: textMain)),
                const SizedBox(height: 6),
                if (lines.every((l) => l['word'] == null))
                  Text('Nema validnih reči.', style: TextStyle(color: textMuted)),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final l in lines.where((l) => l['word'] != null))
                    Chip(
                      label: Text('${showWord(l['word'], app.script)} · ${l['points']}'),
                      avatar: Text(_lineName(l), style: TextStyle(fontSize: 11, color: textMuted)),
                    ),
                ]),
              ],
            ),
          ),
          if (!review)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: _rematchButton(app)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GoldButton(
                        label: 'IGRAJ',
                        subtitle: 'novi protivnik',
                        icon: Icons.play_arrow_rounded,
                        height: 56,
                        onPressed: () => _playAgain(app),
                      ),
                    ),
                  ]),
                  TextButton.icon(
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Nazad na meni'),
                    onPressed: () {
                      app.declineRematch(_matchId);
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                ]),
              ),
            ),
        ]),
        if (!review) _rematchOffer(app),
      ]),
    );
  }

  Map<String, dynamic>? _rematchState(AppState app) {
    final st = app.rematch.value;
    return st != null && st['matchId'] == _matchId ? st : null;
  }

  /// Dugme za revanš u donjem redu (stanje: ponudi / čeka se / isteklo).
  Widget _rematchButton(AppState app) => ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: app.rematch,
        builder: (context, _, __) {
          final status = _rematchState(app)?['status'] as String?;
          final left = _secondsLeft;
          if (status == 'waiting') {
            return BlueButton(
              label: 'ČEKA SE…',
              subtitle: 'otkaži · $left s',
              icon: Icons.hourglass_top_rounded,
              onPressed: () => app.declineRematch(_matchId),
            );
          }
          final over = status == 'declined' || status == 'expired' || left <= 0;
          return BlueButton(
            label: 'REVANŠ',
            subtitle: over ? (status == 'declined' ? 'odbijen' : 'isteklo') : '10 T · još $left s',
            icon: Icons.replay_rounded,
            onPressed: over || _busy ? null : () => _rematch(app),
          );
        },
      );

  /// Protivnik traži revanš — poziv na sredini ekrana (kao izazov).
  Widget _rematchOffer(AppState app) => ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: app.rematch,
        builder: (context, _, __) {
          final s = _rematchState(app);
          final left = _secondsLeft;
          if (s?['status'] != 'offered' || left <= 0) return const SizedBox.shrink();
          return Positioned.fill(
            child: Material(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: PopupCard(children: [
                  Icon(Icons.replay_circle_filled_rounded, size: 64, color: goldAccent),
                  const SizedBox(height: 8),
                  Text('REVANŠ!',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textMain, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('${s!['from']} traži revanš',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: textMain, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  GoldButton(
                    label: 'PRIHVATI',
                    subtitle: 'još $left s',
                    icon: Icons.replay_rounded,
                    height: 62,
                    trailing: const CostTag(matchCost),
                    onPressed: _busy ? null : () => _rematch(app),
                  ),
                  TextButton(onPressed: () => app.declineRematch(_matchId), child: const Text('Odbij')),
                ]),
              ),
            ),
          );
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
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        child: Column(children: [
          Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, color: textMain, fontSize: 13)),
          Text('${data['points']} poena', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: textMain)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${data['wordsCount']} reči  ', style: TextStyle(color: textMuted, fontSize: 12)),
            Lives(data['lives'] as int, size: 12),
          ]),
        ]),
      );
}
