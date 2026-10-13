import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Čekanje protivnika (nasumično) ili prijatelja (privatni kod).
/// Kada partija počne, AppState sam otvara ekran partije.
class WaitingScreen extends StatefulWidget {
  const WaitingScreen({super.key});
  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  late final Timer _t;
  final _start = DateTime.now();

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  Future<void> _cancel(AppState app) async {
    if (app.waiting == 'private') {
      await app.cancelPrivate();
    } else {
      await app.leaveQueue();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isPrivate = app.waiting == 'private';
    final waited = DateTime.now().difference(_start).inSeconds;
    if (app.waiting == null) {
      // Otkazano ili isteklo — vrati se nazad.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && app.match.value == null) Navigator.maybePop(context);
      });
    }
    final remaining = app.privateExpiresAt == null
        ? null
        : Duration(milliseconds: app.privateExpiresAt! - DateTime.now().millisecondsSinceEpoch);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel(app);
      },
      child: GameScaffold(
        title: isPrivate ? 'Privatna partija' : 'Traženje protivnika',
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: SizedBox(width: 64, height: 64, child: CircularProgressIndicator(strokeWidth: 6))),
                const SizedBox(height: 28),
                if (isPrivate && app.privateCode != null) ...[
                  const Text('Pošalji ovaj kod prijatelju:', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: app.privateCode!));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod je kopiran.')));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                          color: panel,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: brandBlue, width: 2)),
                      child: Text(app.privateCode!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 36, letterSpacing: 8, fontWeight: FontWeight.bold, color: brandBlue)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Dodirni kod da ga kopiraš.',
                      textAlign: TextAlign.center, style: TextStyle(color: textMuted)),
                  if (remaining != null && !remaining.isNegative)
                    Text('Kod važi još ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                        textAlign: TextAlign.center, style: const TextStyle(color: textMuted)),
                ] else ...[
                  const Text('Tražimo protivnika sličnog levela…',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Čekanje: ${waited}s', textAlign: TextAlign.center, style: const TextStyle(color: textMuted)),
                ],
                const SizedBox(height: 16),
                const Text('Tokeni (10) se naplaćuju tek kada partija počne.',
                    textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 12)),
                const SizedBox(height: 32),
                OutlinedButton(onPressed: () => _cancel(app), child: const Text('Otkaži')),
              ]),
        ),
      ),
    );
  }
}
