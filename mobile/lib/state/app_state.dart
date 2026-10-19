import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../api.dart';
import '../config.dart';
import '../letters.dart';
import '../push/push.dart';
import '../push/push_fcm.dart';
import '../theme.dart';
import '../screens/game_screen.dart';
import '../screens/result_screen.dart';

enum AuthStatus { loading, loggedOut, loggedIn }

/// Glavno stanje aplikacije: prijava, profil, podešavanja i veza za igru.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final api = Api();
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  AuthStatus status = AuthStatus.loading;
  Map<String, dynamic>? user;

  /// Slova se prikazuju latinicom (ćirilica je samo interni zapis na serveru).
  final Script script = Script.latin;

  /// Režim prikaza: 'dark' (podrazumevano) ili 'light'.
  String themeMode = 'dark';

  /// Menja se pri promeni režima — ceo prikaz se tada ponovo iscrtava novim bojama.
  int themeVersion = 0;

  io.Socket? _socket;
  bool socketConnected = false;

  /// Poslednji izgubljen život u partiji (ko i koliko je ostalo) — za animaciju na ekranu partije.
  final lifeLost = ValueNotifier<({bool mine, int livesLeft, DateTime at})?>(null);

  /// Trenutna partija (stanje iz ugla ovog igrača) — null ako nije u partiji.
  final match = ValueNotifier<Map<String, dynamic>?>(null);

  /// Revanš posle partije: {matchId, status: waiting|offered|declined|expired, from?, reason?}.
  final rematch = ValueNotifier<Map<String, dynamic>?>(null);

  /// Razlika serverskog i lokalnog sata (ms), da tajmer ne zavisi od sata telefona.
  int clockOffset = 0;

  /// Status čekanja: 'queue' | 'private' | null
  String? waiting;
  String? privateCode;
  int? privateExpiresAt;

  AppState() {
    WidgetsBinding.instance.addObserver(this);
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
    if (mode != 'light') mode = 'dark'; // podrazumevano tamni režim
    themeMode = mode;
    pal = mode == 'light' ? lightPalette : darkPalette;
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
    // Ovaj uređaj više ne prima obaveštenja za odjavljeni nalog.
    final endpoint = _pushEndpoint;
    _pushEndpoint = null;
    if (endpoint != null) await api.post('/push/unsubscribe', {'endpoint': endpoint}).catchError((_) => null);
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
      _sendPresence();
      _initPush();
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
    s.on('match:start', (data) {
      rematch.value = null;
      _openMatch(Map<String, dynamic>.from(data));
    });
    s.on('rematch:offer', (data) {
      rematch.value = {'matchId': data['matchId'], 'status': 'offered', 'from': data['from']};
      // Dugme za prihvatanje je pri dnu ekrana rezultata — kratka poruka da se ne propusti.
      toast('${data['from']} traži revanš!');
    });
    s.on('rematch:declined', (data) {
      rematch.value = {'matchId': data['matchId'], 'status': 'declined', 'reason': data['reason']};
    });
    s.on('rematch:expired', (data) {
      rematch.value = {'matchId': data['matchId'], 'status': 'expired'};
    });
    s.on('match:state', (data) => _updateMatch(Map<String, dynamic>.from(data)));
    s.on('match:life-lost', (data) {
      final m = match.value;
      if (m == null) return;
      // Ekran partije prikazuje veliku poruku na sredini ekrana.
      lifeLost.value = (mine: data['seat'] == m['mySeat'], livesLeft: data['livesLeft'] as int, at: DateTime.now());
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

  // ------------------------------------------------------------ obaveštenja

  String? _pushEndpoint;

  /// Obaveštenja su podrazumevano uključena; igrač ih može isključiti u Podešavanjima.
  bool pushOn = true;
  bool _pushPrefsLoaded = false;
  bool _firstTapArmed = false;
  bool _fcmRefreshListening = false;

  /// Aplikacija je u prvom planu ili ne — server šalje „na potezu si“ samo kad igrač nije u aplikaciji.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _sendPresence(state);
    }
  }

  void _sendPresence([AppLifecycleState? state]) {
    final s = state ?? WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _socket?.emit('presence', {'foreground': s == AppLifecycleState.resumed});
  }

  /// Pri povezivanju: ako obaveštenja nisu isključena, prijavi uređaj (Android pita za dozvolu odmah,
  /// iPhone posle prvog dodira na ekran).
  Future<void> _initPush() async {
    if (!_pushPrefsLoaded) {
      final prefs = await SharedPreferences.getInstance();
      pushOn = !(prefs.getBool('pushOff') ?? false);
      _pushPrefsLoaded = true;
      notifyListeners();
    }
    if (!pushOn) return;
    if (fcmAvailable) {
      await _enableFcm();
    } else if (pushSupported()) {
      final perm = pushPermission();
      if (perm == 'granted') {
        await _enableWeb(ask: false);
      } else if (perm == 'default' && !_firstTapArmed) {
        _firstTapArmed = true;
        final key = await _vapidKey();
        if (key == null) return;
        final json = await pushSubscribeOnFirstTap(key);
        _firstTapArmed = false;
        if (json.isNotEmpty) await _saveWebSubscription(json);
      }
    }
  }

  /// Prekidač u Podešavanjima.
  Future<String?> setPushOn(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pushOff', !on);
    pushOn = on;
    notifyListeners();
    if (!on) {
      final endpoint = _pushEndpoint;
      _pushEndpoint = null;
      if (endpoint != null) await api.post('/push/unsubscribe', {'endpoint': endpoint}).catchError((_) => null);
      if (fcmAvailable) await fcmDeleteToken();
      return null;
    }
    final err = fcmAvailable ? await _enableFcm() : await _enableWeb(ask: true);
    if (err != null) {
      await prefs.setBool('pushOff', true);
      pushOn = false;
      notifyListeners();
    }
    return err;
  }

  Future<String?> _enableFcm() async {
    final token = await fcmToken();
    if (token == null) return 'Obaveštenja su blokirana. Uključi ih u podešavanjima telefona za 25 Slova.';
    try {
      await api.post('/push/subscribe', {'kind': 'FCM', 'token': token});
      _pushEndpoint = token;
    } catch (e) {
      return e.toString();
    }
    if (!_fcmRefreshListening) {
      _fcmRefreshListening = true;
      await onFcmTokenRefresh((t) {
        if (!pushOn || api.token == null) return;
        _pushEndpoint = t;
        api.post('/push/subscribe', {'kind': 'FCM', 'token': t}).catchError((_) => null);
      });
    }
    return null;
  }

  Future<String?> _vapidKey() async {
    try {
      final cfg = Map<String, dynamic>.from(await api.get('/push/config'));
      return cfg['webPublicKey'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _enableWeb({required bool ask}) async {
    if (!pushSupported()) {
      return 'Na iPhone-u obaveštenja rade kada je igra dodata na početni ekran (Share → Add to Home Screen).';
    }
    final key = await _vapidKey();
    if (key == null) return 'Obaveštenja trenutno nisu dostupna.';
    final json = await pushSubscribe(key, ask: ask);
    if (json.isEmpty) {
      return pushPermission() == 'denied'
          ? 'Obaveštenja su blokirana. Uključi ih u podešavanjima telefona za 25 Slova.'
          : 'Obaveštenja nisu uključena.';
    }
    return _saveWebSubscription(json);
  }

  Future<String?> _saveWebSubscription(String json) async {
    try {
      final sub = Map<String, dynamic>.from(jsonDecode(json));
      await api.post('/push/subscribe', {'kind': 'WEB', 'subscription': sub});
      _pushEndpoint = sub['endpoint'] as String?;
      return null;
    } catch (e) {
      return e.toString();
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

  /// Traži revanš (ili prihvata protivnikov zahtev). Vraća poruku greške ili null.
  Future<String?> requestRematch(String matchId) async {
    final r = await emit('rematch:request', {'matchId': matchId});
    if (r['ok'] != true) return r['error'];
    if (r['waiting'] == true) rematch.value = {'matchId': matchId, 'status': 'waiting'};
    return null;
  }

  Future<void> declineRematch(String matchId) async {
    final st = rematch.value;
    if (st != null && st['matchId'] == matchId && st['status'] != 'waiting' && st['status'] != 'offered') return;
    rematch.value = null;
    await emit('rematch:decline', {'matchId': matchId});
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
