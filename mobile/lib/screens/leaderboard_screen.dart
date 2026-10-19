import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'player_profile_screen.dart';
import 'profile_screen.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        initialIndex: 1,
        child: GameScaffold(
          title: 'Rang liste',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(54),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: panelBorder),
              ),
              child: TabBar(
                indicator: BoxDecoration(gradient: blueGradient, borderRadius: BorderRadius.circular(10)),
                tabs: const [
                  Tab(text: 'Nedeljna', height: 36),
                  Tab(text: 'Mesečna', height: 36),
                  Tab(text: 'Godišnja', height: 36)
                ],
              ),
            ),
          ),
          body: const TabBarView(children: [_Board('week'), _Board('month'), _Board('year')]),
        ),
      );
}

class _Board extends StatefulWidget {
  final String period;
  const _Board(this.period);
  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  Timer? _debounce;
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<dynamic> _load() {
    final q = _search.text.trim();
    final query = q.isEmpty ? '' : '&search=${Uri.encodeQueryComponent(q)}';
    return context.read<AppState>().api.get('/leaderboard?period=${widget.period}$query');
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _f = _load());
    });
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _f = _load());
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final searching = _search.text.trim().isNotEmpty;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          controller: _search,
          onChanged: (v) {
            setState(() {}); // osveži dugme za brisanje
            _onSearchChanged(v);
          },
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Pretraži igrača',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searching ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch) : null,
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder(
          future: _f,
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text(snap.error.toString()));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final data = snap.data as Map;
            final items = (data['items'] as List).cast<Map>();
            final me = data['me'] as Map?;
            return Column(children: [
              if (data['key'] != null)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(_periodTitle(data['key'] as String), style: TextStyle(color: textMuted)),
                ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            searching
                                ? 'Nema igrača sa tim imenom na ovoj listi.\nIgrač se pojavljuje na listi kada osvoji ili izgubi poene u ovom periodu.'
                                : 'Još nema rezultata u ovom periodu.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          final f = _load();
                          setState(() => _f = f);
                          await f;
                        },
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (_, i) =>
                              _row(items[i], highlight: me != null && me['userId'] == items[i]['userId']),
                        ),
                      ),
              ),
              // Moje mesto je uvek vidljivo na dnu kad nisam u prikazanoj listi.
              if (me != null && !items.any((r) => r['userId'] == me['userId']))
                Container(
                  decoration: BoxDecoration(
                    color: bgBottom,
                    border: Border(top: BorderSide(color: panelBorder)),
                  ),
                  padding: const EdgeInsets.only(top: 6),
                  child: SafeArea(top: false, child: _row(me, highlight: true)),
                ),
            ]);
          },
        ),
      ),
    ]);
  }

  String _periodTitle(String key) => switch (widget.period) {
        'week' => 'Nedelja ${key.split('-W').last}. · ${key.split('-W').first}',
        'month' => monthLabel(key),
        _ => 'Godina $key.',
      };

  Widget _row(Map r, {bool highlight = false}) {
    final rank = r['rank'] as int;
    final first = rank == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Panel(
        // Dodir otvara profil igrača (ili moj profil).
        onTap: () {
          final mine = r['userId'] == context.read<AppState>().user?['id'];
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => mine ? const ProfileScreen() : PlayerProfileScreen(userId: r['userId'] as String)),
          );
        },
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        gradient: first
            ? (isDark
                ? LinearGradient(colors: [const Color(0xFF8A6A12).withOpacity(0.9), const Color(0xFF3B3410)])
                : const LinearGradient(colors: [Color(0xFFFFF1C4), Color(0xFFFFE08A)]))
            : null,
        color: highlight ? panelLight : null,
        borderColor: first ? gold : (highlight ? cellSelected : panelBorder),
        child: Row(children: [
          SizedBox(
            width: 40,
            child: rank <= 3
                ? Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: medalColor(rank),
                        border: Border.all(color: Colors.white70, width: 2),
                        boxShadow: [BoxShadow(color: medalColor(rank).withOpacity(0.6), blurRadius: 8)],
                      ),
                      child: Text('$rank',
                          style: const TextStyle(fontWeight: FontWeight.w900, color: goldText, fontSize: 16)),
                    ),
                  )
                : Text('$rank',
                    textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(width: 6),
          UserAvatar(url: r['avatarUrl'], name: r['username'] ?? '', radius: 20, ring: first),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['username'] ?? '',
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('Level ${r['level']}', style: TextStyle(color: first ? goldAccent : textMuted, fontSize: 12)),
            ]),
          ),
          Text(fmtPoints(r['points']),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: first ? goldAccent : textMain)),
          const SizedBox(width: 4),
        ]),
      ),
    );
  }
}
