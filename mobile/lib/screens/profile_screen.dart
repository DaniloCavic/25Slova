import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<List<dynamic>> _extra;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    app.refreshMe().catchError((_) {});
    _extra = Future.wait([app.api.get('/me/medals'), app.api.get('/matches/recent')]);
  }

  Future<void> _avatar(AppState app) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Izaberi iz galerije'),
              onTap: () => Navigator.pop(context, 'gallery')),
          ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Slikaj'),
              onTap: () => Navigator.pop(context, 'camera')),
          if (app.user?['avatarUrl'] != null)
            ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Ukloni sliku'),
                onTap: () => Navigator.pop(context, 'remove')),
        ]),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'remove') {
        app.setUser(Map<String, dynamic>.from(await app.api.delete('/me/avatar')));
        return;
      }
      final img = await ImagePicker().pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (img == null) return;
      final bytes = await img.readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      app.setUser(Map<String, dynamic>.from(await app.api.put('/me/avatar', {'dataUrl': dataUrl})));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _deleteAccount(AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Brisanje naloga'),
        content: const Text(
            'Nalog i lični podaci biće trajno obrisani. Tokeni, poeni i medalje se gube. Ova radnja se ne može poništiti.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Odustani')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Obriši nalog', style: TextStyle(color: brandRed))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await app.api.delete('/me');
      await app.logout();
      app.toast('Nalog je obrisan.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final u = app.user ?? {};
    final total = (u['totalPoints'] ?? 0) as int;
    return GameScaffold(
      title: 'Moj profil',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: Stack(children: [
            UserAvatar(url: u['avatarUrl'], name: u['username'] ?? '', radius: 54, ring: true),
            Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: brandBlue,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.edit, size: 17, color: Colors.white),
                  onPressed: () => _avatar(app),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Text(u['username'] ?? '',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        Text('Level ${u['level'] ?? 1}',
            textAlign: TextAlign.center, style: const TextStyle(color: gold, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Center(child: LevelBar(progress: u['levelProgress'], totalPoints: total, width: 180)),
        const SizedBox(height: 16),
        Row(children: [
          _Stat(Icons.emoji_events, 'Ukupno', u['totalPoints']),
          _Stat(Icons.date_range, 'Nedelja', u['weeklyPoints']),
          _Stat(Icons.calendar_month, 'Mesec', u['monthlyPoints']),
          _Stat(Icons.bar_chart, 'Godina', u['yearlyPoints']),
          _Stat(Icons.monetization_on, 'Tokeni', u['tokens']),
        ]),
        const SizedBox(height: 18),
        FutureBuilder<List<dynamic>>(
          future: _extra,
          builder: (context, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();
            final medals = (snap.data![0] as List).cast<Map>();
            final matches = (snap.data![1] as List).cast<Map>();
            int count(int place) => medals.where((m) => m['place'] == place).length;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Medalje', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              Row(children: [
                for (final place in [1, 2, 3])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Panel(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(children: [
                          Icon(Icons.military_tech,
                              size: 40, color: count(place) > 0 ? medalColor(place) : textMuted.withOpacity(0.35)),
                          Text(['Zlatne', 'Srebrne', 'Bronzane'][place - 1],
                              style: const TextStyle(fontSize: 12, color: textMuted)),
                          Text('${count(place)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        ]),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              if (medals.isEmpty)
                const Text('Uđi među prva tri na nedeljnoj, mesečnoj ili godišnjoj listi i osvoji medalju!',
                    style: TextStyle(color: textMuted, fontSize: 13))
              else
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final m in medals.take(12))
                    Chip(
                      avatar: Icon(Icons.military_tech, color: medalColor(m['place'])),
                      label: Text('${m['place']}. mesto · ${periodName(m['period'])} ${m['periodKey']}'),
                    ),
                ]),
              const SizedBox(height: 18),
              const Text('Poslednje partije', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              if (matches.isEmpty) const Text('Još nema odigranih partija.', style: TextStyle(color: textMuted)),
              for (final m in matches)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Icon(
                        m['outcome'] == 'WIN'
                            ? Icons.check_circle
                            : m['outcome'] == 'LOSS'
                                ? Icons.cancel
                                : Icons.remove_circle,
                        color: m['outcome'] == 'WIN' ? success : (m['outcome'] == 'LOSS' ? danger : textMuted),
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('protiv ${m['opponent'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${m['myScore']} : ${m['opponentScore']} poena',
                              style: const TextStyle(color: textMuted, fontSize: 13)),
                        ]),
                      ),
                      Text('${m['pointsDelta'] > 0 ? '+' : ''}${m['pointsDelta']}',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: m['pointsDelta'] > 0 ? success : (m['pointsDelta'] < 0 ? danger : textMuted))),
                    ]),
                  ),
                ),
            ]);
          },
        ),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('Lični podaci'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Promena lozinke'),
          onTap: () => showDialog(context: context, builder: (_) => const _PasswordDialog()),
        ),
        ListTile(leading: const Icon(Icons.logout), title: const Text('Odjava'), onTap: () => app.logout()),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: danger),
          title: const Text('Obriši nalog', style: TextStyle(color: brandRed)),
          onTap: () => _deleteAccount(app),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic value;
  const _Stat(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Panel(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Column(children: [
              Icon(icon, color: gold, size: 22),
              const SizedBox(height: 4),
              FittedBox(
                  child: Text('${value ?? 0}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
              Text(label, style: const TextStyle(fontSize: 11, color: textMuted)),
            ]),
          ),
        ),
      );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final hasPassword = app.user?['hasPassword'] == true;
    return AlertDialog(
      title: const Text('Promena lozinke'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (hasPassword)
          TextField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Trenutna lozinka')),
        const SizedBox(height: 8),
        TextField(controller: _next, obscureText: true, decoration: const InputDecoration(labelText: 'Nova lozinka')),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: brandRed))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Otkaži')),
        TextButton(
          onPressed: () async {
            try {
              await app.api.post('/me/password', {
                if (hasPassword) 'currentPassword': _current.text,
                'newPassword': _next.text,
              });
              if (!context.mounted) return;
              Navigator.pop(context);
              app.toast('Lozinka je promenjena.');
            } catch (e) {
              setState(() => _error = e.toString());
            }
          },
          child: const Text('Sačuvaj'),
        ),
      ],
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final Map<String, dynamic> u = context.read<AppState>().user ?? {};
  late final _username = TextEditingController(text: u['username']);
  late final _fullName = TextEditingController(text: u['fullName']);
  late final _email = TextEditingController(text: u['email']);
  late final _phone = TextEditingController(text: u['phone']);
  late String? _gender = u['gender'];
  late String? _birthDate = u['birthDate'];
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    final app = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await app.api.patch('/me', {
        'username': _username.text.trim(),
        'fullName': _fullName.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        if (_gender != null) 'gender': _gender,
        if (_birthDate != null) 'birthDate': _birthDate,
      });
      app.setUser(Map<String, dynamic>.from(res));
      if (mounted) Navigator.pop(context);
      app.toast('Podaci su sačuvani.');
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
      appBar: AppBar(title: const Text('Lični podaci')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(controller: _username, decoration: const InputDecoration(labelText: 'Korisničko ime')),
        gap,
        TextField(controller: _fullName, decoration: const InputDecoration(labelText: 'Ime i prezime')),
        gap,
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: const InputDecoration(labelText: 'Pol'),
          items: const [
            DropdownMenuItem(value: 'MALE', child: Text('Muški')),
            DropdownMenuItem(value: 'FEMALE', child: Text('Ženski')),
          ],
          onChanged: (v) => setState(() => _gender = v),
        ),
        gap,
        OutlinedButton.icon(
          icon: const Icon(Icons.cake_outlined),
          label: Text(_birthDate ?? 'Datum rođenja'),
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime.tryParse(_birthDate ?? '') ?? DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (d != null) setState(() => _birthDate = d.toIso8601String().substring(0, 10));
          },
        ),
        gap,
        TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'E-mail'),
            keyboardType: TextInputType.emailAddress),
        gap,
        TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Telefon'),
            keyboardType: TextInputType.phone),
        const SizedBox(height: 6),
        const Text('E-mail i telefon ne vide drugi igrači.', style: TextStyle(color: textMuted, fontSize: 12)),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: brandRed))),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Sačuvaj')),
      ]),
    );
  }
}
