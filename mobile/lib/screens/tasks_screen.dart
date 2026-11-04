import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/challenge_overlay.dart' show PopupCard;

/// Zadaci: dnevni (sa glavnim zadatkom — 4 reči na jednoj tabli), nedeljni i mesečni.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _tab = 'day';
  Map<String, dynamic>? _data;
  String? _error;
  final Set<String> _claiming = {};
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _load();
    // Odbrojavanje do kraja perioda.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    try {
      final d = Map<String, dynamic>.from(await app.api.get('/tasks'));
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
      app.setTasksClaimable(d['claimable'] as int);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _claim(String period, Map t) async {
    final app = context.read<AppState>();
    final id = t['id'] as String;
    setState(() => _claiming.add(id));
    try {
      final r = Map<String, dynamic>.from(await app.api.post('/tasks/$period/$id/claim'));
      if (app.user != null) app.setUser({...app.user!, 'tokens': r['tokens']});
      app.announceTask(r['title'] as String, r['reward'] as int);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _claiming.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return GameScaffold(
      title: 'Zadaci',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: PillTabs(
            options: const {'day': 'Dnevni', 'week': 'Nedeljni', 'month': 'Mesečni'},
            selected: _tab,
            onChanged: (v) => setState(() => _tab = v),
          ),
        ),
        Expanded(
          child: d == null
              ? Center(
                  child: _error != null
                      ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!))
                      : const CircularProgressIndicator())
              : RefreshIndicator(onRefresh: _load, child: _list(d)),
        ),
      ]),
    );
  }

  Widget _list(Map<String, dynamic> d) {
    final p = Map<String, dynamic>.from(d[_tab] as Map);
    final tasks = (p['tasks'] as List).cast<Map>();
    final ends = DateTime.tryParse('${p['endsAt']}');
    final total = tasks.length + (_tab == 'day' ? 1 : 0);
    final doneCount =
        tasks.where((t) => t['done'] == true).length + (_tab == 'day' && (p['main'] as Map)['done'] == true ? 1 : 0);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        Row(children: [
          Icon(Icons.schedule, size: 18, color: textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(ends == null ? '' : 'Ističe za ${_left(ends)}',
                style: TextStyle(color: textMuted, fontWeight: FontWeight.w700)),
          ),
          Text('$doneCount/$total ispunjeno', style: TextStyle(color: textMuted, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        if (_tab == 'day') ...[
          _MainCard(main: Map<String, dynamic>.from(p['main'] as Map), claiming: _claiming, onClaim: _claim),
          const SizedBox(height: 14),
        ],
        for (final t in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TaskCard(
              t: t,
              busy: _claiming.contains(t['id']),
              onClaim: () => _claim(_tab, t),
            ),
          ),
      ],
    );
  }

  String _left(DateTime end) {
    final diff = end.toLocal().difference(DateTime.now());
    if (diff.isNegative) return '0 min';
    if (diff.inDays >= 1) return '${diff.inDays} ${diff.inDays == 1 ? 'dan' : 'dana'} i ${diff.inHours % 24} h';
    if (diff.inHours >= 1) return '${diff.inHours} h ${diff.inMinutes % 60} min';
    return '${diff.inMinutes} min';
  }
}

/// Glavni dnevni zadatak: 4 reči (2 od 5 i 2 od 4 slova) na jednoj tabli.
class _MainCard extends StatelessWidget {
  final Map<String, dynamic> main;
  final Set<String> claiming;
  final Future<void> Function(String period, Map t) onClaim;
  const _MainCard({required this.main, required this.claiming, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final words = (main['words'] as List).cast<Map>();
    final done = main['done'] == true;
    final claimed = main['claimed'] == true;
    return Panel(
      borderColor: gold,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark ? [const Color(0xFF1E3F86), const Color(0xFF102552)] : [Colors.white, const Color(0xFFFFF3CF)],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.star_rounded, color: gold, size: 26),
          const SizedBox(width: 6),
          Expanded(
            child: Text('GLAVNI ZADATAK DANA',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textMain, letterSpacing: 0.4)),
          ),
          _Reward(main['reward'] as int),
        ]),
        const SizedBox(height: 6),
        Text('Složi sve 4 reči na jednoj tabli u jednoj partiji. Reči su samo tvoje i menjaju se svaki dan.',
            style: TextStyle(color: textMuted, fontSize: 13, height: 1.35)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (final w in words) WordTiles(w['word'] as String, done: w['done'] == true),
        ]),
        const SizedBox(height: 12),
        _Progress(progress: main['progress'] as int, target: main['target'] as int, percent: main['percent'] as int),
        const SizedBox(height: 4),
        Text('Najbolja današnja tabla: ${main['progress']} od 4 reči',
            textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 12)),
        if (done && !claimed) ...[
          const SizedBox(height: 12),
          GoldButton(
            label: 'PREUZMI NAGRADU',
            height: 52,
            trailing: _Reward(main['reward'] as int, onGold: true),
            centerTrailing: true,
            onPressed: claiming.contains(main['id']) ? null : () => onClaim('day', main),
          ),
        ] else if (claimed) ...[
          const SizedBox(height: 10),
          const _ClaimedLabel(),
        ],
      ]),
    );
  }
}

/// Reč kao niz pločica (kao na tabli); zelena ivica kad je složena.
class WordTiles extends StatelessWidget {
  final String word;
  final bool done;
  const WordTiles(this.word, {super.key, required this.done});

  @override
  Widget build(BuildContext context) {
    final letters = RegExp(r'lj|nj|dž|.').allMatches(word).map((m) => m.group(0)!).toList();
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: done ? success : Colors.transparent, width: 2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final l in letters)
          Container(
            width: 30,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF3CF), Color(0xFFFFD36A)],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2B54A)),
            ),
            child: FittedBox(
              child: Text(l.length > 1 ? l[0].toUpperCase() + l.substring(1) : l.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: goldText)),
            ),
          ),
        if (done) ...[const SizedBox(width: 4), Icon(Icons.check_circle, color: success, size: 20)],
      ]),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map t;
  final bool busy;
  final VoidCallback onClaim;
  const _TaskCard({required this.t, required this.busy, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final done = t['done'] == true;
    final claimed = t['claimed'] == true;
    return Panel(
      borderColor: done && !claimed ? gold : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(claimed ? Icons.check_circle : (done ? Icons.emoji_events : Icons.radio_button_unchecked),
              color: claimed ? success : (done ? gold : textMuted), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${t['title']}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textMain, height: 1.25)),
          ),
          const SizedBox(width: 8),
          _Reward(t['reward'] as int),
        ]),
        const SizedBox(height: 10),
        _Progress(progress: t['progress'] as int, target: t['target'] as int, percent: t['percent'] as int),
        if (done && !claimed) ...[
          const SizedBox(height: 10),
          GoldButton(
            label: 'PREUZMI',
            height: 46,
            trailing: _Reward(t['reward'] as int, onGold: true),
            centerTrailing: true,
            onPressed: busy ? null : onClaim,
          ),
        ] else if (claimed) ...[
          const SizedBox(height: 8),
          const _ClaimedLabel(),
        ],
      ]),
    );
  }
}

/// Traka napretka: početak (0) — traka sa stanjem u sredini („3 / 5 · 60%“) — cilj (zastavica i broj,
/// kad je ispunjeno: zelena kvačica).
class _Progress extends StatelessWidget {
  final int progress;
  final int target;
  final int percent;
  const _Progress({required this.progress, required this.target, required this.percent});

  @override
  Widget build(BuildContext context) {
    final done = percent >= 100;
    final color = done ? success : gold;
    final track = isDark ? Colors.black.withOpacity(0.35) : const Color(0xFFDCE5F5);
    Widget end(Widget child, {required Color border, Color? fill}) => Container(
          height: 26,
          constraints: const BoxConstraints(minWidth: 26),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill ?? track,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: border, width: 1.6),
          ),
          child: child,
        );
    return Row(children: [
      end(Text('0', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: textMuted)),
          border: textMuted.withOpacity(0.5)),
      const SizedBox(width: 6),
      Expanded(
        child: SizedBox(
          height: 20,
          child: Stack(alignment: Alignment.center, children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: target == 0 ? 0 : progress / target,
                  backgroundColor: track,
                  color: color,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${fmtNum(progress)} / ${fmtNum(target)} · $percent%',
                maxLines: 1,
                // Na svetloj (praznoj) traci tamni tekst, inače beli sa senkom.
                style: !isDark && percent < 50
                    ? TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, color: textMain)
                    : const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 3),
                          Shadow(color: Colors.black54, blurRadius: 6)
                        ],
                      ),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 6),
      // Cilj: zastavica i broj (bez okvira); kad je ispunjeno — zelena kvačica.
      done
          ? Icon(Icons.check_circle_rounded, size: 24, color: success)
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.flag_rounded, size: 16, color: goldAccent),
              const SizedBox(width: 2),
              Text(fmtNum(target), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: goldAccent)),
            ]),
    ]);
  }
}

/// 1000 → "1.000"
String fmtNum(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

class _Reward extends StatelessWidget {
  final int amount;
  final bool onGold;
  const _Reward(this.amount, {this.onGold = false});

  @override
  Widget build(BuildContext context) {
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      Text('+${fmtNum(amount)}',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: onGold ? goldText : goldAccent)),
      const SizedBox(width: 4),
      const CoinIcon(size: 22),
    ]);
    if (onGold) return row;
    // Nagrada u zaobljenom okviru (kao cena partije).
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.3) : const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withOpacity(0.85), width: 1.6),
      ),
      child: row,
    );
  }
}

class _ClaimedLabel extends StatelessWidget {
  const _ClaimedLabel();

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check, size: 18, color: success),
        const SizedBox(width: 4),
        Text('Nagrada preuzeta', style: TextStyle(color: success, fontWeight: FontWeight.w800)),
      ]);
}

// ------------------------------------------------------------------ u partiji

/// 5 redova, 5 kolona i 2 dijagonale (indeksi polja), kao na serveru.
final List<List<int>> _lines = [
  for (var r = 0; r < 5; r++) [for (var c = 0; c < 5; c++) r * 5 + c],
  for (var c = 0; c < 5; c++) [for (var r = 0; r < 5; r++) r * 5 + c],
  [0, 6, 12, 18, 24],
  [4, 8, 12, 16, 20],
];

/// Koje reči (ćirilica) se nalaze na tabli — u bilo kom nizu, u oba smera.
List<bool> boardHits(List board, List<String> words) {
  final strings = _lines.expand((l) {
    final s = l.map((i) => (board[i] as String?) ?? '·').join();
    return [s, s.split('').reversed.join()];
  }).toList();
  return [for (final w in words) strings.any((s) => s.contains(w))];
}

/// Glavni zadatak u toku partije: reči koje treba složiti i koje su već na ovoj tabli.
Future<void> showMainTaskPopup(BuildContext context, List board) => showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => _MainTaskPopup(board),
    );

class _MainTaskPopup extends StatefulWidget {
  final List board;
  const _MainTaskPopup(this.board);
  @override
  State<_MainTaskPopup> createState() => _MainTaskPopupState();
}

class _MainTaskPopupState extends State<_MainTaskPopup> {
  late final Future<dynamic> _f = context.read<AppState>().api.get('/tasks');

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(vertical: 24),
        child: PopupCard(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.star_rounded, color: gold, size: 28),
            const SizedBox(width: 6),
            Text('GLAVNI ZADATAK',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: textMain, letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 4),
          Text('Složi sve 4 reči na jednoj tabli', style: TextStyle(color: textMuted, fontSize: 13)),
          const SizedBox(height: 14),
          FutureBuilder(
            future: _f,
            builder: (context, snap) {
              if (snap.hasError) return Text('${snap.error}', style: TextStyle(color: textMuted));
              if (!snap.hasData) {
                return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator());
              }
              final main = Map<String, dynamic>.from((snap.data as Map)['day']['main'] as Map);
              final words = (main['words'] as List).cast<Map>();
              final done = main['done'] == true;
              // Tabla se prati uživo dok je prozor otvoren.
              return ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: context.read<AppState>().match,
                builder: (context, m, _) {
                  final board = m == null ? widget.board : (m['me'] as Map)['board'] as List;
                  final hits = boardHits(board, [for (final w in words) '${w['cyr'] ?? ''}']);
                  final n = hits.where((h) => h).length;
                  return Column(children: [
                    Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                      for (var i = 0; i < words.length; i++) WordTiles(words[i]['word'] as String, done: hits[i]),
                    ]),
                    const SizedBox(height: 14),
                    _Progress(progress: n, target: words.length, percent: words.isEmpty ? 0 : n * 100 ~/ words.length),
                    const SizedBox(height: 6),
                    Text(
                        done
                            ? 'Glavni zadatak je danas već ispunjen!'
                            : 'Na ovoj tabli: $n od ${words.length} reči · nagrada ${main['reward']} T',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: done ? success : textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]);
                },
              );
            },
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zatvori')),
        ]),
      );
}
