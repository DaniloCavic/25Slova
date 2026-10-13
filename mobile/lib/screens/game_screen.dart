import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../letters.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/board.dart';
import '../widgets/common.dart';
import '../widgets/letter_picker.dart';

/// Ekran partije. Stanje dolazi sa servera (AppState.match); server određuje
/// čiji je potez, tajmer i živote — klijent samo prikazuje i šalje potez.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  String? _letter;
  int? _cell;
  bool _sending = false;
  int? _lastMoveCount;
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _confirm(AppState app, Map<String, dynamic> m) async {
    if (_cell == null) return;
    final choose = m['phase'] == 'CHOOSE';
    if (choose && _letter == null) return;
    setState(() => _sending = true);
    final err = await app.move(_cell!, choose ? _letter : null);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      showError(context, err);
    } else {
      setState(() {
        _cell = null;
        _letter = null;
      });
    }
  }

  Future<void> _resign(AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Predaja'),
        content: const Text('Ako predate partiju, protivnik pobeđuje i gubite 10 poena. Da li ste sigurni?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nastavi igru')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Predaj', style: TextStyle(color: danger))),
        ],
      ),
    );
    if (ok == true) await app.resign();
  }

  Widget _player(Map<String, dynamic> p, {required bool active, required bool alignRight}) {
    final info = Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text('${p['username']}',
            overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        Text('Level ${p['level']}', style: const TextStyle(color: textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Lives(p['lives'] as int, size: 16),
      ],
    );
    final avatar = Container(
      decoration: active
          ? BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: gold.withOpacity(0.7), blurRadius: 12)])
          : null,
      child: UserAvatar(url: p['avatarUrl'], name: p['username'] ?? '', radius: 22, ring: active),
    );
    return Expanded(
      child: Row(
        mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: alignRight
            ? [Flexible(child: info), const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), Flexible(child: info)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: app.match,
      builder: (context, m, _) {
        if (m == null) {
          return const AppBackground(
              child: Scaffold(backgroundColor: Colors.transparent, body: Center(child: CircularProgressIndicator())));
        }
        // Novi potez sa servera — poništi lokalni izbor.
        if (_lastMoveCount != m['moveCount']) {
          _lastMoveCount = m['moveCount'];
          _cell = null;
          _letter = null;
        }
        final script = app.script;
        final me = Map<String, dynamic>.from(m['me']);
        final opp = Map<String, dynamic>.from(m['opponent']);
        final myTurn = m['isMyTurn'] == true;
        final choose = m['phase'] == 'CHOOSE';
        final current = m['currentLetter'] as String?;
        final turnMs = (m['turnSeconds'] as int) * 1000;
        final now = DateTime.now().millisecondsSinceEpoch + app.clockOffset;
        final left = ((m['deadline'] as int) - now).clamp(0, turnMs);
        final secs = (left / 1000).ceil();
        final initial = m['initialLetters'] as int;
        final myPlaced = (me['board'] as List).where((c) => c != null).length - initial;
        final totalMoves = 25 - initial;

        String status;
        if (myTurn && choose) {
          status = 'Izaberi slovo i polje';
        } else if (myTurn) {
          status = 'Postavi slovo ${showLetter(current, script)} na svoju tablu';
        } else if (choose) {
          status = '${opp['username']} bira slovo…';
        } else {
          status = '${opp['username']} postavlja slovo ${showLetter(current, script)}';
        }

        final canConfirm = myTurn && !_sending && _cell != null && (!choose || _letter != null);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _resign(app);
          },
          child: GameScaffold(
            title: initialLettersLabel(initial),
            showBack: false,
            actions: [
              if (!app.socketConnected) const Icon(Icons.cloud_off, color: Colors.orangeAccent),
              IconButton(tooltip: 'Predaj', icon: const Icon(Icons.flag_outlined), onPressed: () => _resign(app)),
            ],
            body: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Row(children: [
                      _player(me, active: myTurn, alignRight: false),
                      TimerRing(seconds: secs, fraction: left / turnMs, urgent: secs <= 10),
                      _player(opp, active: !myTurn, alignRight: true),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Panel(
                    gradient: myTurn ? blueGradient : null,
                    borderColor: myTurn ? const Color(0xFF4F80E0) : panelBorder,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    child: Text(status,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800, color: myTurn ? Colors.white : textMuted)),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: BoardGrid(
                      board: me['board'] as List,
                      script: script,
                      initialCells: Set<int>.from(m['initialCells'] as List),
                      selected: _cell,
                      previewLetter: choose ? _letter : current,
                      onTap: myTurn ? (i) => setState(() => _cell = i) : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('${opp['username']}: ${opp['filled']}/25',
                        style: const TextStyle(color: textMuted, fontSize: 13)),
                    const Spacer(),
                    Text('Potez ${(myPlaced + 1).clamp(1, totalMoves)}/$totalMoves',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 10),
                  if (myTurn && choose)
                    LetterPicker(script: script, selected: _letter, onPick: (l) => setState(() => _letter = l)),
                  if (myTurn && !choose)
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: goldGradient,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFE9A6), width: 2),
                        ),
                        child: Text(showLetter(current, script),
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: goldText)),
                      ),
                    ),
                  const SizedBox(height: 14),
                  if (myTurn)
                    GoldButton(
                      label:
                          _cell == null ? 'IZABERI POLJE' : (choose && _letter == null ? 'IZABERI SLOVO' : 'POTVRDI'),
                      height: 58,
                      onPressed: canConfirm ? () => _confirm(app, m) : null,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
