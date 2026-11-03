import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Kratko uputstvo za nove igrače (5 strana). Prikazuje se jednom posle prve
/// prijave, a može se otvoriti i iz „Pravila igre“.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});
  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pc = PageController();
  int _page = 0;

  static final _pages = <(String, String, Widget)>[
    (
      'Dobrodošao u 25 Slova!',
      'Ti i protivnik imate svaki svoju tablu 5 × 5. Cilj je da na svojoj tabli složiš što više reči.',
      const _MiniBoard(letters: {6: 'S', 7: 'L', 8: 'O', 12: 'V', 17: 'A'}),
    ),
    (
      'Kako se igra',
      'Kad si na potezu, biraš slovo i polje na svojoj tabli. Protivnik isto to slovo mora da stavi na svoju tablu — a onda on bira sledeće slovo za tebe.',
      const _MoveDemo(),
    ),
    (
      'Reči i poeni',
      'Reči se čitaju u redovima, kolonama i dijagonalama, u oba smera. Najduža reč u nizu donosi onoliko poena koliko ima slova (3, 4 ili 5).',
      const _WordDemo(),
    ),
    (
      'Vreme i životi',
      'Za potez imaš 30, 45 ili 60 sekundi. Ako ne stigneš, gubiš jedan život. Ko izgubi sva 3 života — gubi partiju.',
      const _LivesDemo(),
    ),
    (
      'Pobeda, bodovi i tokeni',
      'Pobeđuje igrač sa više poena. Pobednik dobija bodove za rang listu i level. Partija košta 10 tokena, a svaki dan dobijaš 30 tokena na poklon.',
      const _RewardDemo(),
    ),
  ];

  void _next() {
    if (_page == _pages.length - 1) return Navigator.pop(context);
    _pc.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return GameScaffold(
      title: 'Uputstvo',
      body: Column(children: [
        Expanded(
          child: PageView(
            controller: _pc,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final (title, text, picture) in _pages)
                ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 8), children: [
                  SizedBox(height: 250, child: Center(child: picture)),
                  const SizedBox(height: 22),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textMain)),
                  const SizedBox(height: 10),
                  Text(text,
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.45, color: textMuted)),
                ]),
            ],
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < _pages.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _page ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == _page ? gold : textMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: GoldButton(label: last ? 'KRENI!' : 'DALJE', height: 58, onPressed: _next),
        ),
        SizedBox(
          height: 44,
          child: last
              ? null
              : TextButton(onPressed: () => Navigator.pop(context), child: const Text('Preskoči')),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ------------------------------------------------------------------ slike

class _Tile extends StatelessWidget {
  final String? letter;
  final double size;
  final bool word;
  const _Tile(this.letter, {this.size = 40, this.word = false});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        margin: EdgeInsets.all(size * 0.05),
        alignment: Alignment.center,
        decoration: letter == null
            ? BoxDecoration(
                color: cellEmpty,
                borderRadius: BorderRadius.circular(size * 0.22),
                border: Border.all(color: panelBorder, width: 1.2),
              )
            : BoxDecoration(
                gradient: goldGradient,
                borderRadius: BorderRadius.circular(size * 0.22),
                border: Border.all(color: word ? success : const Color(0xFFFFE9A6), width: word ? 3 : 1.2),
                boxShadow: [
                  const BoxShadow(color: Colors.black26, offset: Offset(0, 3), blurRadius: 4),
                  if (word) BoxShadow(color: success.withOpacity(0.5), blurRadius: 8),
                ],
              ),
        child: letter == null
            ? null
            : Text(letter!, style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.w900, color: goldText)),
      );
}

class _MiniBoard extends StatelessWidget {
  final Map<int, String> letters;
  final Set<int> word;
  final double cell;
  const _MiniBoard({required this.letters, this.word = const {}, this.cell = 42});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        for (var r = 0; r < 5; r++)
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var c = 0; c < 5; c++) _Tile(letters[r * 5 + c], size: cell, word: word.contains(r * 5 + c)),
          ]),
      ]);
}

class _MoveDemo extends StatelessWidget {
  const _MoveDemo();

  @override
  Widget build(BuildContext context) {
    Widget side(String who, Map<int, String> l) => Column(mainAxisSize: MainAxisSize.min, children: [
          _MiniBoard(letters: l, cell: 24),
          const SizedBox(height: 6),
          Text(who, style: TextStyle(fontWeight: FontWeight.w800, color: textMain)),
        ]);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const _Tile('A', size: 58),
      const SizedBox(height: 6),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.south_west_rounded, color: goldAccent, size: 30),
        const SizedBox(width: 40),
        Icon(Icons.south_east_rounded, color: goldAccent, size: 30),
      ]),
      const SizedBox(height: 4),
      Row(mainAxisSize: MainAxisSize.min, children: [
        side('Ti', {7: 'A', 12: 'R'}),
        const SizedBox(width: 18),
        side('Protivnik', {3: 'R', 21: 'A'}),
      ]),
    ]);
  }
}

class _WordDemo extends StatelessWidget {
  const _WordDemo();

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        const _MiniBoard(
          letters: {0: 'K', 5: 'O', 10: 'S', 11: 'T', 12: 'R', 13: 'O', 14: 'G', 15: 'A', 20: 'M'},
          word: {10, 11, 12, 13, 14},
          cell: 36,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: success.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
          child: Text('STROG = 5 poena', style: TextStyle(color: success, fontWeight: FontWeight.w900, fontSize: 16)),
        ),
      ]);
}

class _LivesDemo extends StatelessWidget {
  const _LivesDemo();

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 130,
            height: 130,
            child: CircularProgressIndicator(
              value: 0.3,
              strokeWidth: 10,
              color: danger,
              backgroundColor: textMuted.withOpacity(0.2),
            ),
          ),
          const Text('10', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: danger)),
        ]),
        const SizedBox(height: 22),
        const Lives(2, size: 40),
      ]);
}

class _RewardDemo extends StatelessWidget {
  const _RewardDemo();

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.emoji_events_rounded, size: 120, color: gold, shadows: [
          Shadow(color: gold.withOpacity(0.6), blurRadius: 24),
        ]),
        const SizedBox(width: 10),
        const Column(mainAxisSize: MainAxisSize.min, children: [
          CoinIcon(size: 64),
          SizedBox(height: 8),
          Text('+30', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: gold)),
        ]),
      ]);
}
