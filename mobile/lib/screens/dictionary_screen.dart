import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Rečnik igre: sve reči koje igra priznaje, pretraga i predlog nove reči.
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});
  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  String _length = '0';
  final List<String> _words = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  bool _done = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _loadMore();
    });
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _term => _search.text.trim().toLowerCase();

  void _reload() {
    _request++;
    setState(() {
      _words.clear();
      _page = 0;
      _done = false;
      _error = null;
      _loading = false;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _done) return;
    final req = _request;
    setState(() => _loading = true);
    try {
      final q = <String>[
        'page=${_page + 1}',
        if (_term.isNotEmpty) 'search=${Uri.encodeQueryComponent(_term)}',
        if (_length != '0') 'length=$_length',
      ].join('&');
      final res = Map<String, dynamic>.from(await context.read<AppState>().api.get('/dictionary?$q'));
      if (!mounted || req != _request) return;
      final words = (res['words'] as List).cast<String>();
      setState(() {
        _words.addAll(words);
        _total = res['total'] as int;
        _page++;
        _done = _words.length >= _total || words.isEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || req != _request) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearch(String _) {
    setState(() {}); // dugme za brisanje
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  @override
  Widget build(BuildContext context) {
    final searching = _term.isNotEmpty;
    return GameScaffold(
      title: 'Rečnik',
      actions: [
        IconButton(
          tooltip: 'Moji predlozi',
          icon: const Icon(Icons.history_edu),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySuggestionsScreen())),
        ),
      ],
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: _onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Pretraži reč',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searching
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        _reload();
                      })
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PillTabs(
            options: const {'0': 'Sve', '3': '3 slova', '4': '4 slova', '5': '5 slova'},
            selected: _length,
            onChanged: (v) {
              _length = v;
              _reload();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 10, 2),
          child: Row(children: [
            Expanded(
              child: Text(
                _page == 0 && _loading ? 'Učitavanje…' : '${fmtCount(_total)} ${_wordsLabel(_total)}',
                style: TextStyle(color: textMuted, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => showSuggestSheet(context, initial: searching ? _term : ''),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Predloži reč'),
            ),
          ]),
        ),
        Expanded(child: _list(searching)),
      ]),
    );
  }

  Widget _list(bool searching) {
    if (_error != null && _words.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    if (_words.isEmpty && _done) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        Panel(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(children: [
            Icon(Icons.search_off, size: 46, color: textMuted),
            const SizedBox(height: 8),
            Text(
              searching ? 'Reč „${_term.toUpperCase()}“ nije u rečniku.' : 'Nema reči.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textMain),
            ),
            if (searching) ...[
              const SizedBox(height: 6),
              Text('Misliš da treba da bude? Predloži je, a admin će je pregledati.',
                  textAlign: TextAlign.center, style: TextStyle(color: textMuted)),
              const SizedBox(height: 14),
              GoldButton(
                label: 'PREDLOŽI REČ',
                icon: Icons.add_circle_outline,
                height: 54,
                onPressed: () => showSuggestSheet(context, initial: _term),
              ),
            ],
          ]),
        ),
      ]);
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: [for (final w in _words) _WordChip(w)]),
          if (_loading)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else if (!_done)
            TextButton(onPressed: _loadMore, child: const Text('Učitaj još')),
        ],
      ),
    );
  }
}

String _wordsLabel(int n) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'reč';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'reči';
  return 'reči';
}

/// 7112 → "7.112"
String fmtCount(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

class _WordChip extends StatelessWidget {
  final String word;
  const _WordChip(this.word);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF3CF), Color(0xFFFFE08A)],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2B54A)),
        ),
        child: Text(word.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: goldText, letterSpacing: 0.6)),
      );
}

/// Prozor za predlog nove reči.
Future<void> showSuggestSheet(BuildContext context, {String initial = ''}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SuggestSheet(initial: initial),
    );

class _SuggestSheet extends StatefulWidget {
  final String initial;
  const _SuggestSheet({required this.initial});
  @override
  State<_SuggestSheet> createState() => _SuggestSheetState();
}

class _SuggestSheetState extends State<_SuggestSheet> {
  late final _word = TextEditingController(text: widget.initial);
  final _note = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _send() async {
    final app = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await app.api.post('/dictionary/suggestions', {
        'word': _word.text.trim(),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      app.toast('Predlog je poslat! Javićemo ti kad ga admin pregleda.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Predloži reč',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            'Reč od 3 do 5 slova. Imenice i pridevi u prvom padežu (jednina ili množina), glagoli u svim oblicima.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _word,
            autofocus: widget.initial.isEmpty,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Reč', prefixIcon: Icon(Icons.spellcheck)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Značenje ili napomena (nije obavezno)'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: danger)),
            ),
          GoldButton(label: _busy ? 'SLANJE…' : 'POŠALJI PREDLOG', height: 54, onPressed: _busy ? null : _send),
        ]),
      );
}

/// Moji predlozi reči i njihov status.
class MySuggestionsScreen extends StatelessWidget {
  const MySuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) => GameScaffold(
        title: 'Moji predlozi',
        body: FutureBuilder(
          future: context.read<AppState>().api.get('/dictionary/suggestions/mine'),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text(snap.error.toString()));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final items = (snap.data as List).cast<Map>();
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Još nema tvojih predloga.\nAko neka reč fali u rečniku, predloži je!',
                      textAlign: TextAlign.center, style: TextStyle(color: textMuted)),
                ),
              );
            }
            return ListView(padding: const EdgeInsets.all(16), children: [
              for (final s in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${s['latin']}'.toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textMain)),
                          if (s['status'] == 'REJECTED' && s['reason'] != null)
                            Text('${s['reason']}', style: TextStyle(color: textMuted, fontSize: 13))
                          else if (s['note'] != null)
                            Text('${s['note']}', style: TextStyle(color: textMuted, fontSize: 13)),
                        ]),
                      ),
                      _StatusChip(s['status'] as String),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'ACCEPTED' => ('Dodata', success, Icons.check_circle),
      'REJECTED' => ('Odbijena', danger, Icons.cancel),
      _ => ('Na čekanju', goldAccent, Icons.schedule),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
    );
  }
}
