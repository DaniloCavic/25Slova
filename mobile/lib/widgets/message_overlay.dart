import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Kratke poruke na sredini ekrana (greške, „kod je kopiran“, „… ti je sada prijatelj“).
/// Nestaju same posle par sekundi ili na dodir; ne blokiraju ostatak ekrana.
class MessageOverlay extends StatefulWidget {
  final Widget child;
  const MessageOverlay({super.key, required this.child});
  @override
  State<MessageOverlay> createState() => _MessageOverlayState();
}

class _MessageOverlayState extends State<MessageOverlay> with SingleTickerProviderStateMixin {
  late final AppState _app = context.read<AppState>();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  ({String text, bool error, int id})? _shown;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _app.message.addListener(_sync);
  }

  void _sync() {
    final m = _app.message.value;
    if (m == null) return;
    _hide?.cancel();
    setState(() => _shown = m);
    _anim.forward(from: _anim.value > 0.5 ? 0.6 : 0);
    final words = m.text.split(' ').length;
    _hide = Timer(Duration(milliseconds: (1800 + words * 180).clamp(2200, 5000)), _close);
  }

  Future<void> _close() async {
    _hide?.cancel();
    await _anim.reverse();
    if (mounted) setState(() => _shown = null);
  }

  @override
  void dispose() {
    _hide?.cancel();
    _app.message.removeListener(_sync);
    _anim.dispose();
    super.dispose();
  }

  IconData _icon(({String text, bool error, int id}) m) {
    final t = m.text.toLowerCase();
    if (t.contains('veze') || t.contains('server') || t.contains('interneta')) return Icons.wifi_off_rounded;
    if (t.contains('token')) return Icons.toll_rounded;
    if (t.contains('prijatelj')) return Icons.people_alt_rounded;
    if (t.contains('kopiran')) return Icons.copy_rounded;
    return m.error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final m = _shown;
    return Stack(children: [
      widget.child,
      if (m != null)
        Positioned.fill(
          child: Center(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, child) => Opacity(
                opacity: _anim.value,
                child: Transform.scale(scale: 0.85 + 0.15 * Curves.easeOutBack.transform(_anim.value), child: child),
              ),
              child: GestureDetector(
                onTap: _close,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 36),
                    constraints: const BoxConstraints(maxWidth: 340),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xF2132C5E) : const Color(0xF7FFFFFF),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: m.error ? danger : gold, width: 2.2),
                      boxShadow: [
                        const BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 6)),
                        BoxShadow(color: (m.error ? danger : gold).withValues(alpha: 0.35), blurRadius: 22),
                      ],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_icon(m), size: 44, color: m.error ? danger : goldAccent),
                      const SizedBox(height: 10),
                      Text(m.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, height: 1.3, fontWeight: FontWeight.w800, color: textMain)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
