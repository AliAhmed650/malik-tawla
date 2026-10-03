import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'bots.dart';
import 'engine.dart';
import 'session.dart';
import 'store.dart';

class LobbyPlayer {
  final String id;
  String name;
  int seat;
  LobbyPlayer(this.id, this.name, this.seat);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'seat': seat};
  factory LobbyPlayer.fromJson(Map<String, dynamic> j) => LobbyPlayer(j['id'] as String, j['name'] as String, j['seat'] as int);
}

String makeRoomCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
}

/// جلسة العميل: بتعرض اللي المضيف يبعته وتبعتله الأوامر
class ClientSession extends GameSession {
  ViewState? _v;
  final void Function(Map<String, dynamic> act) _send;
  ClientSession(this._send);

  void apply(ViewState v) {
    _v = v;
    notifyListeners();
  }

  @override
  ViewState? get view => _v;
  @override
  void play(int i, bool left) => _send({'a': 'play', 'i': i, 'left': left});
  @override
  void pass() => _send({'a': 'pass'});
  @override
  void buy() => _send({'a': 'buy'});
  @override
  void next() => _send({'a': 'next'});
  @override
  void react(String e) => _send({'a': 'react', 'e': e});
  @override
  void close() {}
}

/// غرفة أونلاين عبر Supabase Realtime Broadcast.
/// المضيف هو اللي بيدير اللعبة (GameCore) وبيبعت لكل لاعب حالته هو بس.
class OnlineRoom extends ChangeNotifier {
  final bool isHost;
  final String code;
  final AppStore store;
  GameConfig? cfg;
  final List<LobbyPlayer> players = [];
  RealtimeChannel? _ch;
  bool connected = false;
  bool started = false;
  String? error;
  bool _disposed = false;

  LocalSession? hostSession;
  ClientSession? clientSession;
  Timer? _helloT, _giveUpT;
  bool _gotLobby = false;

  OnlineRoom.host(this.store, GameConfig this.cfg)
      : isHost = true,
        code = makeRoomCode();
  OnlineRoom.join(this.store, String c)
      : isHost = false,
        code = c.trim().toUpperCase();

  String get myId => store.deviceId;
  GameSession? get session => isHost ? hostSession : clientSession;

  Map<String, dynamic> _unwrap(Map<String, dynamic> m) {
    final p = m['payload'];
    if (p is Map && (m.containsKey('event') || m.containsKey('type'))) return Map<String, dynamic>.from(p);
    return m;
  }

  Future<void> connect() async {
    try {
      final ch = Supabase.instance.client.channel('mtdom:$code', opts: const RealtimeChannelConfig(self: false, ack: false));
      _ch = ch;
      void on(String ev, void Function(Map<String, dynamic>) f) {
        ch.onBroadcast(event: ev, callback: (payload) {
          try {
            f(_unwrap(Map<String, dynamic>.from(payload)));
          } catch (e) {
            debugPrint('online[$ev] error: $e');
          }
        });
      }

      if (isHost) {
        on('hello', _hostHello);
        on('act', _hostAct);
        on('bye', _hostBye);
      } else {
        on('lobby', _clientLobby);
        on('state', _clientState);
        on('ev', _clientEvent);
        on('reject', (m) {
          if (m['id'] == myId) _fail((m['reason'] as String?) ?? 'مش قادر تدخل الطاولة');
        });
        on('closed', (_) => _fail('المضيف قفل الطاولة'));
      }

      ch.subscribe((status, err) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          connected = true;
          if (isHost) {
            players.add(LobbyPlayer(myId, store.name, 0));
            _sendLobby();
          } else {
            _sayHello();
            _helloT = Timer.periodic(const Duration(seconds: 3), (_) {
              if (!_gotLobby) _sayHello();
            });
            _giveUpT = Timer(const Duration(seconds: 10), () {
              if (!_gotLobby) _fail('مالقيتش الطاولة دي — راجع الكود');
            });
          }
          _notify();
        } else if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
          _fail('مشكلة في الاتصال بالسيرفر');
        }
      });
    } catch (e) {
      _fail('مقدرتش أتصل: $e');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _fail(String m) {
    if (error != null) return;
    error = m;
    _notify();
  }

  Future<void> _send(String ev, Map<String, dynamic> payload) async {
    try {
      await _ch?.sendBroadcastMessage(event: ev, payload: payload);
    } catch (e) {
      debugPrint('send $ev failed: $e');
    }
  }

  // ---------------- المضيف ----------------
  void _sendLobby() {
    _send('lobby', {
      'cfg': cfg!.toJson(),
      'players': players.map((p) => p.toJson()).toList(),
      'started': started,
    });
  }

  void _hostHello(Map<String, dynamic> m) {
    final id = m['id'] as String;
    final name = ((m['name'] as String?) ?? 'لاعب').trim();
    final known = players.where((p) => p.id == id).toList();
    if (known.isNotEmpty) {
      known.first.name = name.isEmpty ? known.first.name : name;
      _sendLobby();
      if (started) _sendStateTo(known.first);
      _notify();
      return;
    }
    if (started) {
      _send('reject', {'id': id, 'reason': 'القعدة بدأت خلاص'});
      return;
    }
    if (players.length >= cfg!.n) {
      _send('reject', {'id': id, 'reason': 'الطاولة مليانة'});
      return;
    }
    var seat = 0;
    while (players.any((p) => p.seat == seat)) {
      seat++;
    }
    players.add(LobbyPlayer(id, name.isEmpty ? 'لاعب' : name, seat));
    _sendLobby();
    _notify();
  }

  void _hostBye(Map<String, dynamic> m) {
    final id = m['id'] as String;
    final idx = players.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final p = players[idx];
    if (!started) {
      players.removeAt(idx);
      _sendLobby();
    } else {
      final core = hostSession!.core;
      core.seats[p.seat].human = false; // البوت يكمل مكانه
      players.removeAt(idx);
      core.onEvent?.call('toast', p.seat, '${p.name} سابنا — البوت كمّل مكانه');
    }
    _notify();
  }

  void _hostAct(Map<String, dynamic> m) {
    if (!started) return;
    final id = m['id'] as String;
    final p = players.where((x) => x.id == id).toList();
    if (p.isEmpty) return;
    final core = hostSession!.core;
    final seat = p.first.seat;
    switch (m['a']) {
      case 'play':
        core.play(seat, m['i'] as int, m['left'] as bool);
        break;
      case 'pass':
        core.pass(seat);
        break;
      case 'buy':
        core.buy(seat);
        break;
      case 'next':
        core.next(seat);
        break;
      case 'react':
        final e = (m['e'] as String?) ?? '🙂';
        core.react(seat, e.length > 8 ? e.substring(0, 8) : e);
        break;
    }
  }

  /// المضيف يبدأ اللعب، والمقاعد الفاضية بتتملي بوتات
  void startGame() {
    if (!isHost || started || cfg == null) return;
    final humans = {for (final p in players) p.seat: p.name};
    final core = GameCore(cfg!, buildSeats(cfg!.n, humans), humanTimeoutSec: 45);
    final ss = LocalSession(core, mySeat: 0);
    ss.taps.add((type, seat, text) => _send('ev', {'type': type, 'seat': seat, 'text': text}));
    ss.addListener(_broadcastStates);
    hostSession = ss;
    started = true;
    ss.begin();
    _sendLobby();
    _notify();
  }

  void restartGame() => hostSession?.restart();

  void _sendStateTo(LobbyPlayer p) {
    final core = hostSession?.core;
    if (core == null || core.roundNo == 0) return;
    _send('state', {'id': p.id, 'v': core.viewFor(p.seat).toJson()});
  }

  void _broadcastStates() {
    for (final p in players) {
      if (p.id == myId) continue;
      _sendStateTo(p);
    }
  }

  // ---------------- العميل ----------------
  void _sayHello() => _send('hello', {'id': myId, 'name': store.name});

  void _clientLobby(Map<String, dynamic> m) {
    _gotLobby = true;
    cfg = GameConfig.fromJson(Map<String, dynamic>.from(m['cfg'] as Map));
    players
      ..clear()
      ..addAll((m['players'] as List).map((e) => LobbyPlayer.fromJson(Map<String, dynamic>.from(e as Map))));
    _notify();
  }

  void _clientState(Map<String, dynamic> m) {
    if (m['id'] != myId) return;
    _gotLobby = true;
    clientSession ??= ClientSession((act) => _send('act', {...act, 'id': myId}));
    started = true;
    clientSession!.apply(ViewState.fromJson(Map<String, dynamic>.from(m['v'] as Map)));
    _notify();
  }

  void _clientEvent(Map<String, dynamic> m) {
    clientSession?.onEvent?.call(m['type'] as String, m['seat'] as int, (m['text'] as String?) ?? '');
  }

  // ---------------- خروج ----------------
  Future<void> leave() async {
    _helloT?.cancel();
    _giveUpT?.cancel();
    if (isHost) {
      await _send('closed', {});
      hostSession?.close();
    } else {
      await _send('bye', {'id': myId});
    }
    try {
      if (_ch != null) await Supabase.instance.client.removeChannel(_ch!);
    } catch (_) {}
    _ch = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _helloT?.cancel();
    _giveUpT?.cancel();
    super.dispose();
  }
}
