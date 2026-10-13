import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../api.dart';
import '../config.dart';
import '../letters.dart';
import '../theme.dart';
import '../screens/game_screen.dart';
import '../screens/result_screen.dart';

enum AuthStatus { loading, loggedOut, loggedIn }

/// Glavno stanje aplikacije: prijava, profil, podešavanja i veza za igru.
class AppState extends ChangeNotifier {
  final api = Api();
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  AuthStatus status = AuthStatus.loading;
  Map<String, dynamic>? user;

  /// Slova se prikazuju latinicom (ćirilica je samo interni zapis na serveru).
  final Script script = Script.latin;

  /// Režim prikaza: 'dark', 'light' ili 'system' (prema podešavanju telefona pri pokretanju).
  String themeMode = 'dark';

  /// Menja se pri promeni režima — ceo prikaz se tada ponovo iscrtava novim bojama.
  int themeVersion = 0;

  io.Socket? _socket;
  bool socketConnected = false;

  /// Trenutna partija (stanje iz ugla ovog igrača) — null ako nije u partiji.
  final match = ValueNotifier<Map<String, dynamic>?>(null);

  /// Razlika serverskog i lokalnog sata (ms), da tajmer ne zavisi od sata telefona.
  int clockOffset = 0;

  /// Status čekanja: 'queue' | 'private' | null
  String? waiting;
  String? privateCode;
  int? privateExpiresAt;

  AppState() {
    api.onUnauthorized = (msg) {
      if (status == AuthStatus.loggedIn) {
        logout();
        toast(msg);
      }
    };
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _applyTheme(prefs.getString('themeMode') ?? 'dark');
    final token = prefs.getString('token');
    if (token == null) {
      status = AuthStatus.loggedOut;
      notifyListeners();
      return;
    }
    api.token = token;
    try {
      final res = await api.get('/me');
      _onSession(res['user'], res['dailyReward']);
    } on ApiException catch (e) {
      if (e.status == 0) {
        // Bez interneta: ostajemo prijavljeni, pokušaćemo ponovo.
        status = AuthStatus.loggedIn;
        user = {'username': '', 'tokens': 0, 'level': 1};
        notifyListeners();
        _connectSocket();
      } else {
        await logout();
      }
    }
  }

  void _applyTheme(String mode) {
    themeMode = mode;
    final brightness = mode == 'system'
        ? WidgetsBinding.instance.platformDispatcher.platformBrightness
        : (mode == 'light' ? Brightness.light : Brightness.dark);
    pal = brightness == Brightness.light ? lightPalette : darkPalette;
    themeVersion++;
  }

  Future<void> setThemeMode(String mode) async {
    _applyTheme(mode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode);
  }

  void toast(String msg) {
    messengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveToken(String token) async {
    api.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  void _onSession(Map<String, dynamic> u, Map<String, dynamic>? daily) {
    user = u;
    status = AuthStatus.loggedIn;
    notifyListeners();
    if (daily != null && daily['granted'] == true) {
      Future.microtask(() => toast('Dnevna nagrada: +${daily['amount']} tokena!'));
    }
    _connectSocket();
  }

  Future<void> login(String login, String password) async {
    final res = await api.post('/auth/login', {'login': login, 'password': password});
    await _saveToken(res['accessToken']);
    _onSession(res['user'], res['dailyReward']);
  }

  Future<void> register(Map<String, dynamic> data) async {
    final res = await api.post('/auth/register', data);
    await _saveToken(res['accessToken']);
    _onSession(res['user'], res['dailyReward']);
  }

  Future<void> refreshMe() async {
    final res = await api.get('/me');
    user = res['user'];
    notifyListeners();
    final daily = res['dailyReward'];
    if (daily != null && daily['granted'] == true) toast('Dnevna nagrada: +${daily['amount']} tokena!');
  }

  void setUser(Map<String, dynamic> u) {
    user = u;
    notifyListeners();
  }

  Future<void> logout() async {
    _socket?.dispose();
    _socket = null;
    socketConnected = false;
    api.token = null;
    user = null;
    match.value = null;
    waiting = null;
    status = AuthStatus.loggedOut;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    notifyListeners();
  }

  // ------------------------------------------------------------ igra (Socket.IO)

  void _connectSocket() {
    _socket?.dispose();
    final s = io.io(
      apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': api.token})
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );
    _socket = s;

    s.onConnect((_) {
      socketConnected = true;
      notifyListeners();
    });
    s.onDisconnect((_) {
      socketConnected = false;
      notifyListeners();
    });
    s.on('session', (data) {
      // Povratak u partiju posle prekida veze — vreme je sve vreme teklo.
      final active = data['activeMatch'];
      if (active != null) _openMatch(Map<String, dynamic>.from(active));
    });
    s.on('auth:error', (data) => toast(data['error'] ?? 'Greška prijave.'));
    s.on('account:blocked', (data) {
      logout();
      toast('Nalog je blokiran: ${data['reason'] ?? ''}');
    });
    s.on('tokens:balance', (data) {
      if (user != null) {
        user = {...user!, 'tokens': data['tokens']};
        notifyListeners();
      }
    });
    s.on('queue:left', (_) => _setWaiting(null));
    s.on('private:created', (data) {
      privateCode = data['code'];
      privateExpiresAt = data['expiresAt'];
      _setWaiting('private');
    });
    s.on('private:cancelled', (data) {
      _setWaiting(null);
      toast(data['reason'] ?? 'Privatna partija je otkazana.');
    });
    s.on('match:start', (data) => _openMatch(Map<String, dynamic>.from(data)));
    s.on('match:state', (data) => _updateMatch(Map<String, dynamic>.from(data)));
    s.on('match:life-lost', (data) {
      final m = match.value;
      if (m == null) return;
      final mine = data['seat'] == m['mySeat'];
      toast(mine ? 'Isteklo vreme — izgubili ste život!' : 'Protivniku je isteklo vreme i izgubio je život.');
    });
    s.on('match:end', (data) {
      match.value = null;
      final result = Map<String, dynamic>.from(data);
      if (user != null) {
        user = {...user!, 'totalPoints': result['totalPoints'], 'level': result['level']};
        notifyListeners();
      }
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
        (r) => r.isFirst,
      );
    });
    s.connect();
  }

  void _setWaiting(String? w) {
    waiting = w;
    if (w != 'private') privateCode = null;
    notifyListeners();
  }

  void _updateMatch(Map<String, dynamic> view) {
    clockOffset = (view['serverNow'] as int) - DateTime.now().millisecondsSinceEpoch;
    match.value = view;
  }

  void _openMatch(Map<String, dynamic> view) {
    _setWaiting(null);
    final alreadyOpen = match.value?['matchId'] == view['matchId'];
    _updateMatch(view);
    if (!alreadyOpen) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const GameScreen()),
        (r) => r.isFirst,
      );
    }
  }

  /// Šalje događaj i čeka odgovor servera; vraća poruku greške ili null.
  Future<Map<String, dynamic>> emit(String event, [Map<String, dynamic>? data]) async {
    final s = _socket;
    if (s == null || !s.connected) return {'ok': false, 'error': 'Nema veze sa serverom.'};
    try {
      final res = await s.emitWithAckAsync(event, data ?? {}).timeout(const Duration(seconds: 10));
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return {'ok': false, 'error': 'Server ne odgovara. Pokušajte ponovo.'};
    }
  }

  Future<String?> joinQueue() async {
    final r = await emit('queue:join');
    if (r['ok'] == true) _setWaiting('queue');
    return r['ok'] == true ? null : r['error'];
  }

  Future<void> leaveQueue() async {
    await emit('queue:leave');
    _setWaiting(null);
  }

  Future<String?> createPrivate() async {
    final r = await emit('private:create');
    if (r['ok'] == true) {
      privateCode = r['code'];
      privateExpiresAt = r['expiresAt'];
      _setWaiting('private');
      return null;
    }
    return r['error'];
  }

  Future<void> cancelPrivate() async {
    await emit('private:cancel');
    _setWaiting(null);
  }

  Future<String?> joinPrivate(String code) async {
    final r = await emit('private:join', {'code': code});
    return r['ok'] == true ? null : r['error'];
  }

  Future<String?> move(int cell, String? letter) async {
    final r = await emit('match:move', {'cell': cell, 'letter': letter});
    return r['ok'] == true ? null : r['error'];
  }

  Future<void> resign() async {
    await emit('match:resign');
  }
}
