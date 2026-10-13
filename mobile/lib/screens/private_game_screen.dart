import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Privatna partija: pošalji svoj kod prijatelju ili unesi njegov.
/// Kada partija počne, AppState sam otvara ekran partije.
class PrivateGameScreen extends StatefulWidget {
  const PrivateGameScreen({super.key});
  @override
  State<PrivateGameScreen> createState() => _PrivateGameScreenState();
}

class _PrivateGameScreenState extends State<PrivateGameScreen> {
  bool _sendTab = true;
  bool _busy = false;
  final _code = TextEditingController();
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _create(AppState app) async {
    setState(() => _busy = true);
    final err = await app.createPrivate();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) showError(context, err);
  }

  Future<void> _join(AppState app) async {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 6) return showError(context, 'Kod ima 6 znakova.');
    setState(() => _busy = true);
    final err = await app.joinPrivate(code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) showError(context, err);
  }

  Future<void> _leave(AppState app) async {
    if (app.waiting == 'private') await app.cancelPrivate();
    if (mounted) Navigator.pop(context);
  }

  void _copy(String text, String msg) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _tab(String label, IconData icon, bool active, VoidCallback onTap) => Expanded(
        child: Panel(
          onTap: onTap,
          gradient: active ? blueGradient : null,
          borderColor: active ? const Color(0xFF4F80E0) : panelBorder,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final code = app.waiting == 'private' ? app.privateCode : null;
    final left = app.privateExpiresAt == null
        ? null
        : Duration(milliseconds: app.privateExpiresAt! - DateTime.now().millisecondsSinceEpoch);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(app);
      },
      child: GameScaffold(
        title: 'Privatna partija',
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            _tab('Pošalji kod', Icons.send_rounded, _sendTab, () => setState(() => _sendTab = true)),
            const SizedBox(width: 12),
            _tab('Unesi kod', Icons.group, !_sendTab, () => setState(() => _sendTab = false)),
          ]),
          const SizedBox(height: 28),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.smartphone, color: gold, size: 70),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.send_rounded, color: Colors.white, size: 34),
            ),
            Icon(Icons.smartphone, color: gold, size: 70),
          ]),
          const SizedBox(height: 24),
          if (_sendTab) ...[
            if (code == null) ...[
              const Text('Napravi kod i pošalji ga prijatelju. Partija počinje čim on unese kod.',
                  textAlign: TextAlign.center, style: TextStyle(color: textMuted)),
              const SizedBox(height: 20),
              GoldButton(label: 'NAPRAVI KOD', onPressed: _busy ? null : () => _create(app)),
            ] else ...[
              const Text('Pošalji ovaj kod prijatelju:', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              Panel(
                onTap: () => _copy(code, 'Kod je kopiran.'),
                borderColor: const Color(0xFF4F80E0),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                child: Row(children: [
                  Expanded(
                    child: Text(code,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 34, letterSpacing: 10, fontWeight: FontWeight.w900)),
                  ),
                  const Icon(Icons.copy, color: brandBlue),
                ]),
              ),
              const SizedBox(height: 8),
              if (left != null && !left.isNegative)
                Text('Kod važi još ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center, style: const TextStyle(color: textMuted)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Podeli'),
                    onPressed: () => _copy(
                      'Hajde da igramo 25 Slova! Uđi u „Igraj sa prijateljem“ → „Unesi kod“ i upiši: $code',
                      'Poruka sa kodom je kopirana — nalepi je prijatelju.',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: const Color(0xFF1E9E5A), foregroundColor: Colors.white),
                    icon: const Icon(Icons.copy),
                    label: const Text('Kopiraj kod'),
                    onPressed: () => _copy(code, 'Kod je kopiran.'),
                  ),
                ),
              ]),
              const SizedBox(height: 22),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                SizedBox(width: 10),
                Text('Čekamo prijatelja…', style: TextStyle(color: textMuted)),
              ]),
              TextButton(onPressed: () => _leave(app), child: const Text('Otkaži')),
            ],
          ] else ...[
            const Text('Upiši kod koji ti je prijatelj poslao:',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              textAlign: TextAlign.center,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 30, letterSpacing: 10, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(hintText: 'K7PM2Q', counterText: ''),
              onSubmitted: (_) => _join(app),
            ),
            const SizedBox(height: 18),
            GoldButton(label: 'UĐI U PARTIJU', onPressed: _busy ? null : () => _join(app)),
          ],
          const SizedBox(height: 18),
          const Text('Partija košta 10 tokena, naplaćuje se kad počne.',
              textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 12)),
        ]),
      ),
    );
  }
}
