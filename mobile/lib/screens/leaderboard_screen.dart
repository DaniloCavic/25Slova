import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Rang-liste'),
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [Tab(text: 'Mesečna'), Tab(text: 'Godišnja')],
            ),
          ),
          body: const TabBarView(children: [_Board('month'), _Board('year')]),
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
            filled: true,
            fillColor: Colors.white,
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
                  child: Text(widget.period == 'month' ? 'Mesec ${data['key']}' : 'Godina ${data['key']}',
                      style: const TextStyle(color: Colors.black54)),
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFD5DAE3))),
                  ),
                  child: SafeArea(top: false, child: _row(me, highlight: true)),
                ),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _row(Map r, {bool highlight = false}) {
    final rank = r['rank'] as int;
    return ListTile(
      tileColor: highlight ? cellSelected : null,
      leading: SizedBox(
        width: 84,
        child: Row(children: [
          SizedBox(
            width: 40,
            child: rank <= 3
                ? Icon(Icons.emoji_events, color: medalColor(rank))
                : Text('$rank.', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          UserAvatar(url: r['avatarUrl'], name: r['username'] ?? '', radius: 18),
        ]),
      ),
      title: Text(r['username'] ?? ''),
      subtitle: Text('Level ${r['level']}${rank <= 3 ? ' · $rank. mesto' : ''}'),
      trailing: Text('${r['points']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
