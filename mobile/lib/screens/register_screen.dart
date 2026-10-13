import 'package:flutter/material.dart';
import '../widgets/common.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  String? _gender;
  DateTime? _birthDate;
  bool _busy = false;
  String? _error;

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Datum rođenja',
    );
    if (d != null) setState(() => _birthDate = d);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_gender == null || _birthDate == null) {
      setState(() => _error = 'Izaberite pol i datum rođenja.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().register({
        'username': _username.text.trim(),
        'fullName': _fullName.text.trim(),
        'gender': _gender,
        'birthDate': _fmt(_birthDate!),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
        'passwordConfirm': _password2.text,
      });
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(title: const ScreenTitle('Novi nalog')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Korisničko ime *', helperText: 'Najmanje 5 znakova'),
              validator: (v) => (v ?? '').trim().length < 5 ? 'Korisničko ime mora imati najmanje 5 znakova.' : null,
            ),
            gap,
            TextFormField(
              controller: _fullName,
              decoration: const InputDecoration(labelText: 'Ime i prezime *'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v ?? '').trim().length < 3 ? 'Unesite ime i prezime.' : null,
            ),
            gap,
            const Text('Pol *'),
            Row(children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Muški'),
                  value: 'MALE',
                  groupValue: _gender,
                  onChanged: (v) => setState(() => _gender = v),
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Ženski'),
                  value: 'FEMALE',
                  groupValue: _gender,
                  onChanged: (v) => setState(() => _gender = v),
                ),
              ),
            ]),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.cake_outlined),
              label: Text(_birthDate == null
                  ? 'Datum rođenja *'
                  : '${_birthDate!.day}.${_birthDate!.month}.${_birthDate!.year}.'),
            ),
            gap,
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'E-mail *'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (v) =>
                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'E-mail nije ispravan.',
            ),
            gap,
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Broj telefona', hintText: '+381 6x xxx xxxx'),
              keyboardType: TextInputType.phone,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                return RegExp(r'^\+?[0-9][0-9 /-]{5,19}$').hasMatch(s) ? null : 'Broj telefona nije ispravan.';
              },
            ),
            gap,
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Lozinka *', helperText: 'Najmanje 8 znakova, slovo i broj'),
              obscureText: true,
              validator: (v) {
                final s = v ?? '';
                if (s.length < 8 || !RegExp(r'\d').hasMatch(s) || !RegExp(r'[^\d\s]').hasMatch(s)) {
                  return 'Lozinka mora imati najmanje 8 znakova, slovo i broj.';
                }
                return null;
              },
            ),
            gap,
            TextFormField(
              controller: _password2,
              decoration: const InputDecoration(labelText: 'Potvrda lozinke *'),
              obscureText: true,
              validator: (v) => v != _password.text ? 'Lozinke se ne poklapaju.' : null,
            ),
            if (_error != null) ...[gap, Text(_error!, style: const TextStyle(color: brandRed))],
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _submit, child: const Text('Registruj se')),
          ],
        ),
      ),
    );
  }
}
