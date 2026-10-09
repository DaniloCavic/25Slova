import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _msg;
  bool _isError = false;

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await fn();
    } catch (e) {
      setState(() {
        _msg = e.toString();
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Zaboravljena lozinka')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'E-mail naloga'),
            keyboardType: TextInputType.emailAddress,
            enabled: !_sent,
          ),
          const SizedBox(height: 12),
          if (!_sent)
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        final r = await api.post('/auth/forgot-password', {'email': _email.text.trim()});
                        setState(() {
                          _sent = true;
                          _msg = r['message'];
                          _isError = false;
                        });
                      }),
              child: const Text('Pošalji kod'),
            )
          else ...[
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Kod iz e-maila (6 cifara)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Nova lozinka'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        await api.post('/auth/reset-password', {
                          'email': _email.text.trim(),
                          'code': _code.text.trim(),
                          'newPassword': _password.text,
                        });
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Lozinka je promenjena. Prijavite se.')));
                        Navigator.pop(context);
                      }),
              child: const Text('Promeni lozinku'),
            ),
          ],
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_msg!, style: TextStyle(color: _isError ? brandRed : Colors.green.shade800)),
            ),
        ],
      ),
    );
  }
}
