import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config.dart';
import '../screens/player_profile_screen.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Lični link za poziv: ko ga otvori i prijavi se (ili napravi nalog), postaje ti prijatelj.
void shareInviteLink(BuildContext context) {
  final me = context.read<AppState>().user;
  final link = '$productionUrl/igra/?prijatelj=${me?['id'] ?? ''}';
  final box = context.findRenderObject() as RenderBox?;
  Share.share(
    'Hajde da igramo 25 Slova — igru rečima na srpskom! Otvori $link, prijavi se i bićemo prijatelji u igri.',
    subject: '25 Slova',
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  );
}

const _online = Color(0xFF2ECC71);

/// Moji prijatelji: stanje (u partiji / na mreži / van mreže), međusobni skor, dodir → profil.
class FriendsSection extends StatefulWidget {
  const FriendsSection({super.key});
  @override
  State<FriendsSection> createState() => _FriendsSectionState();
}

class _FriendsSectionState extends State<FriendsSection> {
  late final AppState _app = context.read<AppState>();
  List<Map<String, dynamic>>? _friends;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _app.friendsVersion.addListener(_load);
    // Stanje prijatelja se osvežava dok je ekran otvoren.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _app.friendsVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = (await _app.api.get('/friends') as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (mounted) setState(() => (_friends = list, _error = null));
    } catch (e) {
      if (mounted && _friends == null) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _friends;
    final active = list?.where((f) => f['status'] != 'OFFLINE').length ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(Icons.people_alt_rounded, color: goldAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(list == null ? 'MOJI PRIJATELJI' : 'MOJI PRIJATELJI (${list.length})',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textMain, letterSpacing: 0.5)),
        ),
        if (list != null && list.isNotEmpty)
          Text('$active na mreži', style: TextStyle(color: active > 0 ? _online : textMuted, fontSize: 13)),
      ]),
      const SizedBox(height: 10),
      if (list == null && _error == null)
        const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
      else if (list == null)
        Text(_error!, style: TextStyle(color: textMuted))
      else if (list.isEmpty)
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(
                'Još nemaš prijatelja.\nPošalji svoj link za poziv ili odigraj partiju preko koda — tako postajete prijatelji.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, height: 1.35)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.group_add),
              label: const Text('Pošalji link prijatelju'),
              onPressed: () => shareInviteLink(context),
            ),
          ]),
        )
      else ...[
        for (final f in list) Padding(padding: const EdgeInsets.only(bottom: 8), child: _FriendTile(f)),
        TextButton.icon(
          icon: const Icon(Icons.group_add),
          label: const Text('Pozovi još prijatelja'),
          onPressed: () => shareInviteLink(context),
        ),
      ],
    ]);
  }
}

class _FriendTile extends StatelessWidget {
  final Map<String, dynamic> f;
  const _FriendTile(this.f);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (f['status']) {
      'PLAYING' => ('U partiji', goldAccent),
      'ONLINE' => ('Na mreži', _online),
      _ => ('Van mreže', textMuted),
    };
    final h = Map<String, dynamic>.from(f['h2h'] as Map);
    final wins = h['wins'] as int, losses = h['losses'] as int;
    final h2hColor = wins > losses ? success : (wins < losses ? danger : textMain);
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => PlayerProfileScreen(userId: f['id'] as String))),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          UserAvatar(url: f['avatarUrl'], name: f['username'] ?? '', radius: 22),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: f['status'] == 'OFFLINE' ? Colors.grey : color,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? const Color(0xFF0B1A3C) : Colors.white, width: 2),
              ),
            ),
          ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f['username'] ?? '',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textMain)),
            const SizedBox(height: 2),
            Text('$label · Level ${f['level']}',
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$wins : $losses', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: h2hColor)),
          Text('međusobno', style: TextStyle(color: textMuted, fontSize: 11)),
        ]),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, color: textMuted),
      ]),
    );
  }
}
