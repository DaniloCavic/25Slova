import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config.dart';
import '../letters.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'board.dart';
import 'challenge_overlay.dart' show PopupCard;
import 'common.dart';

/// „Podeli rezultat“: pregled slike (9:16, za Instagram priču, Viber, WhatsApp…)
/// i deljenje preko sistemskog menija.
Future<void> showShareResult(BuildContext context, Map<String, dynamic> result) => showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => _ShareDialog(result),
    );

class _ShareDialog extends StatefulWidget {
  final Map<String, dynamic> result;
  const _ShareDialog(this.result);
  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final me = context.read<AppState>().user;
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: '25slova-rezultat.png', mimeType: 'image/png')],
        text: 'Odigraj i ti 25 Slova! $productionUrl/igra/?prijatelj=${me?['id'] ?? ''}',
        subject: '25 Slova — rezultat',
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      if (mounted) showError(context, kIsWeb ? 'Ovaj pregledač ne podržava deljenje slike.' : 'Deljenje nije uspelo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final script = context.read<AppState>().script;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      child: PopupCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        children: [
          Text('PODELI REZULTAT',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textMain, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: FittedBox(
                child: RepaintBoundary(key: _key, child: ResultCard(widget.result, script: script)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          GoldButton(
            label: _busy ? 'PRIPREMA…' : 'PODELI',
            icon: Icons.ios_share_rounded,
            height: 54,
            onPressed: _busy ? null : _share,
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zatvori')),
        ],
      ),
    );
  }
}

/// Slika rezultata (360 × 640): ishod, rezultat, moja tabla sa rečima.
class ResultCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final Script script;
  const ResultCard(this.r, {super.key, required this.script});

  @override
  Widget build(BuildContext context) {
    final me = Map<String, dynamic>.from(r['me']);
    final opp = Map<String, dynamic>.from(r['opponent']);
    final lines = (me['lines'] as List).cast<Map>();
    final words = [for (final l in lines) if (l['word'] != null) showWord(l['word'], script)];
    final highlighted = <int>{for (final l in lines) ...((l['cells'] as List).cast<int>())};
    final (title, color) = switch (r['outcome']) {
      'WIN' => ('POBEDA!', gold),
      'LOSS' => ('PORAZ', const Color(0xFFFF6B6B)),
      _ => ('NEREŠENO', const Color(0xFF8DB7FF)),
    };
    const white = Colors.white;
    Widget player(Map p, {required bool left}) => Expanded(
          child: Column(children: [
            UserAvatar(url: p['avatarUrl'], name: p['username'] ?? '', radius: 22, ring: true),
            const SizedBox(height: 4),
            Text('${p['username']}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: white, fontWeight: FontWeight.w800, fontSize: 13)),
            Text('${p['wordsCount']} reči', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        );
    return SizedBox(
      width: 360,
      height: 640,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/pozadina.jpg', fit: BoxFit.cover),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.25), const Color(0xEE0B1A3C), const Color(0xF20B1A3C)],
              stops: const [0, 0.32, 1],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(children: [
            const Text('25 SLOVA',
                style: TextStyle(
                  fontFamily: 'Raleway',
                  color: gold,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
                )),
            const SizedBox(height: 6),
            Text(title,
                style: TextStyle(
                  color: color,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2))],
                )),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              player(me, left: true),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${me['points']} : ${opp['points']}',
                    style: const TextStyle(color: white, fontSize: 34, fontWeight: FontWeight.w900)),
              ),
              player(opp, left: false),
            ]),
            const Text('poena', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 12),
            BoardGrid(
              board: me['board'] as List,
              script: script,
              initialCells: Set<int>.from(r['initialCells'] as List),
              highlighted: highlighted,
              maxSize: 270,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final w in words.take(8))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(w, style: const TextStyle(color: white, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const Text('Igraj i ti — 25 Slova, igra rečima na srpskom',
                style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}
