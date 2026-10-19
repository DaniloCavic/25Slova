import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

/// Završena partija iz istorije: obe table, reči i rezultat (isti prikaz kao kraj partije).
class MatchDetailScreen extends StatefulWidget {
  final String matchId;
  final String? asUserId;
  const MatchDetailScreen({super.key, required this.matchId, this.asUserId});
  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  late final Future<dynamic> _f = context
      .read<AppState>()
      .api
      .get('/matches/${widget.matchId}${widget.asUserId == null ? '' : '?as=${widget.asUserId}'}');

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _f,
        builder: (context, snap) {
          if (snap.hasData) return ResultScreen(result: Map<String, dynamic>.from(snap.data as Map), review: true);
          return GameScaffold(
            title: 'Partija',
            body: Center(
              child: snap.hasError
                  ? Padding(padding: const EdgeInsets.all(24), child: Text(snap.error.toString()))
                  : const CircularProgressIndicator(),
            ),
          );
        },
      );
}
