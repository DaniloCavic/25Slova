import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Velika poruka preko ekrana (dnevna nagrada, osvojena medalja): zatamnjena pozadina,
/// kartica koja „iskoči“ na sredinu, zraci svetlosti koji se polako okreću i dugme za zatvaranje.
/// Više poruka se prikazuje jedna za drugom.
class AnnouncementOverlay extends StatefulWidget {
  final Widget child;
  const AnnouncementOverlay({super.key, required this.child});
  @override
  State<AnnouncementOverlay> createState() => _AnnouncementOverlayState();
}

class _AnnouncementOverlayState extends State<AnnouncementOverlay> with TickerProviderStateMixin {
  late final AnimationController _show = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 14))
    ..repeat();
  late final AppState _app = context.read<AppState>();
  Map<String, dynamic>? _current;

  @override
  void initState() {
    super.initState();
    _app.announcements.addListener(_sync);
    _sync();
  }

  void _sync() {
    final list = _app.announcements.value;
    final next = list.isEmpty ? null : list.first;
    if (identical(next, _current)) return;
    setState(() => _current = next);
    if (next != null) _show.forward(from: 0);
  }

  Future<void> _close() async {
    await _show.reverse();
    _app.dismissAnnouncement();
  }

  @override
  void dispose() {
    _app.announcements.removeListener(_sync);
    _show.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _current;
    return Stack(children: [
      widget.child,
      if (a != null)
        AnimatedBuilder(
          animation: _show,
          builder: (context, _) {
            final t = _show.value;
            final scale = 0.5 + 0.5 * Curves.easeOutBack.transform(t);
            return Material(
              color: Colors.black.withOpacity(0.62 * t),
              child: Center(
                child: Opacity(
                  opacity: Curves.easeOut.transform(t).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: a['type'] == 'medal' ? _medalCard(a) : _dailyCard(a),
                  ),
                ),
              ),
            );
          },
        ),
    ]);
  }

  // ------------------------------------------------------------------ kartice

  Widget _card({required Color accent, required Widget hero, required List<Widget> children, required String button}) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                isDark ? [const Color(0xFF1A3A7A), const Color(0xFF0B1A3C)] : [Colors.white, const Color(0xFFE9EFFA)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: accent, width: 2.5),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.55), blurRadius: 36, spreadRadius: 2)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 170,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(
                animation: _spin,
                builder: (_, __) => Transform.rotate(
                  angle: _spin.value * 2 * math.pi,
                  child: CustomPaint(size: const Size(190, 190), painter: _RaysPainter(accent)),
                ),
              ),
              hero,
            ]),
          ),
          ...children,
          const SizedBox(height: 18),
          GoldButton(label: button, height: 56, onPressed: _close),
        ]),
      );

  Widget _dailyCard(Map<String, dynamic> a) => _card(
        accent: gold,
        hero: Column(mainAxisSize: MainAxisSize.min, children: [
          const CoinIcon(size: 92),
          const SizedBox(height: 6),
          Text('+${a['amount']}',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: goldAccent,
                shadows: const [Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
              )),
        ]),
        children: [
          Text('DNEVNA NAGRADA',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textMain, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text('${a['amount']} tokena je dodato na tvoj račun.\nVrati se i sutra po još!',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: textMuted, height: 1.35)),
        ],
        button: 'SUPER!',
      );

  Widget _medalCard(Map<String, dynamic> a) {
    final place = a['place'] as int;
    final color = medalColor(place);
    final list = switch (a['period']) { 'MONTH' => 'mesečnoj', 'YEAR' => 'godišnjoj', _ => 'nedeljnoj' };
    return _card(
      accent: color,
      hero: Icon(Icons.military_tech, size: 130, color: color, shadows: [
        Shadow(color: color.withOpacity(0.8), blurRadius: 24),
        const Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
      ]),
      children: [
        Text('${medalName(place).toUpperCase()} MEDALJA!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textMain, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text('$place. mesto na $list rang listi',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: textMain, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('${_periodText(a['period'] as String, a['periodKey'] as String)} · ${fmtPoints(a['points'] as num)} poena',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: textMuted)),
        const SizedBox(height: 8),
        Text('Čestitamo! Medalja je dodata na tvoj profil.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: textMuted)),
      ],
      button: 'SJAJNO!',
    );
  }

  /// "2026-W42" → "Nedelja 42, 2026.", "2026-10" → "Oktobar 2026.", "2026" → "Godina 2026."
  String _periodText(String period, String key) {
    if (period == 'WEEK') {
      final p = key.split('-W');
      return 'Nedelja ${int.tryParse(p.last) ?? p.last}, ${p.first}.';
    }
    return medalPeriodLabel(period, key);
  }
}

/// Zraci svetlosti iza nagrade.
class _RaysPainter extends CustomPainter {
  final Color color;
  _RaysPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final glow = Paint()
      ..shader = RadialGradient(colors: [color.withOpacity(0.55), color.withOpacity(0)])
          .createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, glow);
    final ray = Paint()
      ..shader = RadialGradient(colors: [color.withOpacity(0.45), color.withOpacity(0)])
          .createShader(Rect.fromCircle(center: c, radius: r));
    const n = 12;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - 0.11), c.dy + r * math.sin(a - 0.11))
        ..lineTo(c.dx + r * math.cos(a + 0.11), c.dy + r * math.sin(a + 0.11))
        ..close();
      canvas.drawPath(path, ray);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.color != color;
}
