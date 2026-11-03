import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/home_screen.dart' show matchCost;
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Izazov prijatelja preko celog ekrana: primljeni (Prihvati / Odbij)
/// i poslati (čeka se odgovor / prijatelj je odbio).
class ChallengeOverlay extends StatefulWidget {
  final Widget child;
  const ChallengeOverlay({super.key, required this.child});
  @override
  State<ChallengeOverlay> createState() => _ChallengeOverlayState();
}

class _ChallengeOverlayState extends State<ChallengeOverlay> {
  late final AppState _app = context.read<AppState>();
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _app.incomingChallenge.addListener(_sync);
    _app.outgoingChallenge.addListener(_sync);
  }

  void _sync() {
    final active = _app.incomingChallenge.value != null || _app.outgoingChallenge.value != null;
    if (active && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
    } else if (!active) {
      _tick?.cancel();
      _tick = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    _app.incomingChallenge.removeListener(_sync);
    _app.outgoingChallenge.removeListener(_sync);
    super.dispose();
  }

  int _left(Map c) {
    final now = DateTime.now().millisecondsSinceEpoch + _app.clockOffset;
    return (((c['expiresAt'] as int) - now) / 1000).ceil().clamp(0, 999);
  }

  Future<void> _accept(String id) async {
    setState(() => _busy = true);
    final err = await _app.acceptChallenge(id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) _app.toast(err);
  }

  @override
  Widget build(BuildContext context) {
    final inc = _app.incomingChallenge.value;
    final out = _app.outgoingChallenge.value;
    Widget? card;
    if (inc != null) {
      card = _incoming(inc);
    } else if (out != null) {
      card = _outgoing(out);
    }
    return Stack(children: [
      widget.child,
      if (card != null)
        Positioned.fill(
          child: Material(
            color: Colors.black.withOpacity(0.6),
            child: Center(child: SingleChildScrollView(child: card)),
          ),
        ),
    ]);
  }

  Widget _card({required List<Widget> children}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                isDark ? [const Color(0xFF1A3A7A), const Color(0xFF0B1A3C)] : [Colors.white, const Color(0xFFE9EFFA)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: gold, width: 2.5),
          boxShadow: [BoxShadow(color: gold.withOpacity(0.45), blurRadius: 30, spreadRadius: 1)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _vs(Map from, Map to) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        UserAvatar(url: from['avatarUrl'], name: from['username'] ?? '', radius: 30, ring: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('VS', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: goldAccent)),
        ),
        UserAvatar(url: to['avatarUrl'], name: to['username'] ?? '', radius: 30, ring: true),
      ]);

  Widget _incoming(Map<String, dynamic> c) {
    final from = Map<String, dynamic>.from(c['from'] as Map);
    final left = _left(c);
    return _card(children: [
      _vs(from, Map<String, dynamic>.from(c['to'] as Map)),
      const SizedBox(height: 14),
      Text('IZAZOV!',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textMain, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text('${from['username']} te izaziva na partiju',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: textMain, fontWeight: FontWeight.w700)),
      Text('Level ${from['level'] ?? 1}', style: TextStyle(color: textMuted, fontSize: 13)),
      const SizedBox(height: 16),
      GoldButton(
        label: 'PRIHVATI',
        subtitle: 'još $left s',
        icon: Icons.sports_kabaddi_rounded,
        height: 62,
        trailing: const CostTag(matchCost),
        onPressed: _busy || left <= 0 ? null : () => _accept(c['id'] as String),
      ),
      TextButton(onPressed: () => _app.declineChallenge(c['id'] as String), child: const Text('Odbij')),
    ]);
  }

  Widget _outgoing(Map<String, dynamic> c) {
    final to = Map<String, dynamic>.from(c['to'] as Map);
    if (c['status'] == 'closed') {
      return _card(children: [
        Icon(Icons.sentiment_dissatisfied_rounded, size: 56, color: textMuted),
        const SizedBox(height: 8),
        Text('${c['reason'] ?? 'Izazov nije prihvaćen.'}',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: textMain, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextButton(onPressed: () => _app.outgoingChallenge.value = null, child: const Text('U redu')),
      ]);
    }
    final left = _left(c);
    return _card(children: [
      _vs(Map<String, dynamic>.from(c['from'] as Map), to),
      const SizedBox(height: 14),
      Text('IZAZOV JE POSLAT',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textMain, letterSpacing: 0.5)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
        const SizedBox(width: 10),
        Flexible(
          child: Text('Čeka se da ${to['username']} prihvati…',
              style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
        ),
      ]),
      const SizedBox(height: 6),
      Text('Partija počinje čim prihvati · još $left s', style: TextStyle(color: textMuted, fontSize: 13)),
      const SizedBox(height: 6),
      TextButton(onPressed: () => _app.declineChallenge(c['id'] as String), child: const Text('Otkaži')),
    ]);
  }
}
