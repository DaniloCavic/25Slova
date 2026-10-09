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
              child: const Text('Predaj', style: TextStyle(color: brandRed))),
        ],
      ),
    );
    if (ok == true) await app.resign();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: app.match,
      builder: (context, m, _) {
        if (m == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

        String status;
        if (myTurn && choose) {
          status = 'Tvoj potez: izaberi slovo i polje';
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
          child: Scaffold(
            appBar: AppBar(
              title: Text('Partija · ${m['initialLetters']} poč. ${m['initialLetters'] == 1 ? 'slovo' : 'slova'}'),
              automaticallyImplyLeading: false,
              actions: [
                if (!app.socketConnected) const Icon(Icons.cloud_off, color: Colors.orangeAccent),
                IconButton(tooltip: 'Predaj', icon: const Icon(Icons.flag_outlined), onPressed: () => _resign(app)),
              ],
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                children: [
                  Row(children: [
                    UserAvatar(url: opp['avatarUrl'], name: opp['username'] ?? '', radius: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${opp['username']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Level ${opp['level']} · popunjeno ${opp['filled']}/25',
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ]),
                    ),
                    Lives(opp['lives'] as int),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: myTurn ? brandBlue : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      Text(status,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: myTurn ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: left / turnMs,
                          minHeight: 8,
                          backgroundColor: myTurn ? Colors.white24 : Colors.black12,
                          color: secs <= 10 ? brandRed : (myTurn ? Colors.white : brandBlue),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('$secs s',
                          style: TextStyle(fontWeight: FontWeight.bold, color: myTurn ? Colors.white : Colors.black87)),
                    ]),
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
                    const Text('Moji životi: '),
                    Lives(me['lives'] as int),
                    const Spacer(),
                    Text('Potez ${(m['moveCount'] as int) ~/ 2 + 1}', style: const TextStyle(color: Colors.black54)),
                  ]),
                  const SizedBox(height: 10),
                  if (myTurn && choose)
                    LetterPicker(script: script, selected: _letter, onPick: (l) => setState(() => _letter = l)),
                  if (myTurn && !choose)
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: cellSelected,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: brandBlue, width: 2)),
                        child: Text(showLetter(current, script),
                            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (myTurn)
                    FilledButton(
                      onPressed: canConfirm ? () => _confirm(app, m) : null,
                      child: Text(_cell == null
                          ? 'Izaberi polje'
                          : (choose && _letter == null ? 'Izaberi slovo' : 'Potvrdi potez')),
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
