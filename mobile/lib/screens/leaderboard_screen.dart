import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Rang-liste'),
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [Tab(text: 'Mesečna'), Tab(text: 'Godišnja'), Tab(text: 'Ukupna')],
            ),
          ),
          body: const TabBarView(children: [_Board('month'), _Board('year'), _Board('total')]),
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
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = context.read<AppState>().api.get('/leaderboard?period=${widget.period}');
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder(
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
              padding: const EdgeInsets.all(8),
              child: Text(widget.period == 'month' ? 'Mesec ${data['key']}' : 'Godina ${data['key']}',
                  style: const TextStyle(color: Colors.black54)),
            ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Još nema rezultata u ovom periodu.'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => _row(items[i], highlight: me != null && me['userId'] == items[i]['userId']),
                  ),
          ),
          if (me != null && me['rank'] > items.length)
            Container(color: Colors.white, child: SafeArea(top: false, child: _row(me, highlight: true))),
        ]);
      },
    );
  }

  Widget _row(Map r, {bool highlight = false}) {
    final rank = r['rank'] as int;
    return ListTile(
      tileColor: highlight ? cellSelected : null,
      leading: SizedBox(
        width: 72,
        child: Row(children: [
          SizedBox(
            width: 28,
            child: rank <= 3
                ? Icon(Icons.emoji_events, color: medalColor(rank))
                : Text('$rank.', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          UserAvatar(url: r['avatarUrl'], name: r['username'] ?? '', radius: 18),
        ]),
      ),
      title: Text(r['username'] ?? ''),
      subtitle: Text('Level ${r['level']}'),
      trailing: Text('${r['points']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
