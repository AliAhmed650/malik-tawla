import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'engine.dart';

class GameConfig {
  final int n;
  final bool teams;
  final int target;
  final Level level;
  const GameConfig({required this.n, required this.teams, required this.target, required this.level});

  int teamOf(int p) => (n == 4 && teams) ? p % 2 : p;

  Map<String, dynamic> toJson() => {'n': n, 'teams': teams, 'target': target, 'level': level.index};
  factory GameConfig.fromJson(Map<String, dynamic> j) => GameConfig(
        n: j['n'] as int,
        teams: j['teams'] as bool,
        target: j['target'] as int,
        level: Level.values[j['level'] as int],
      );
}

class SeatInfo {
  String name;
  String avatar;
  bool human;
  SeatInfo(this.name, this.avatar, this.human);
}

/// اللي اللاعب شايفه (بيتبعت أونلاين لكل لاعب بإيده هو بس)
class ViewState {
  final GameConfig cfg;
  final int mySeat, round, turn, boneyard;
  final List<Tile> hand;
  final List<Move> moves;
  final bool canBuy;
  final List<int> counts;
  final List<Placed> chain;
  final List<int> scores;
  final List<String> names, avatars;
  final bool over, gameOver, opening;
  final int? gameWinnerTeam;
  final RoundResult? result;
  final List<List<Tile>>? revealed;

  const ViewState({
    required this.cfg,
    required this.mySeat,
    required this.round,
    required this.turn,
    required this.boneyard,
    required this.hand,
    required this.moves,
    required this.canBuy,
    required this.counts,
    required this.chain,
    required this.scores,
    required this.names,
    required this.avatars,
    required this.over,
    required this.gameOver,
    required this.opening,
    required this.gameWinnerTeam,
    required this.result,
    required this.revealed,
  });

  int get n => cfg.n;
  int get myTeam => cfg.teamOf(mySeat);
  bool get myTurn => turn == mySeat && !over && !opening;
  int? get leftEnd => chain.isEmpty ? null : chain.first.l;
  int? get rightEnd => chain.isEmpty ? null : chain.last.r;

  Map<String, dynamic> toJson() => {
        'cfg': cfg.toJson(),
        'seat': mySeat,
        'round': round,
        'turn': turn,
        'bone': boneyard,
        'hand': hand.map((t) => t.toJson()).toList(),
        'moves': moves.map((m) => [m.i, m.left ? 1 : 0]).toList(),
        'buy': canBuy,
        'counts': counts,
        'chain': chain.map((c) => c.toJson()).toList(),
        'scores': scores,
        'names': names,
        'avs': avatars,
        'over': over,
        'gover': gameOver,
        'opening': opening,
        'gwt': gameWinnerTeam,
        'result': result?.toJson(),
        'rev': revealed?.map((h) => h.map((t) => t.toJson()).toList()).toList(),
      };

  factory ViewState.fromJson(Map<String, dynamic> j) => ViewState(
        cfg: GameConfig.fromJson(Map<String, dynamic>.from(j['cfg'] as Map)),
        mySeat: j['seat'] as int,
        round: j['round'] as int,
        turn: j['turn'] as int,
        boneyard: j['bone'] as int,
        hand: (j['hand'] as List).map((e) => Tile.fromJson(e)).toList(),
        moves: (j['moves'] as List).map((e) => Move((e as List)[0] as int, e[1] == 1)).toList(),
        canBuy: j['buy'] as bool,
        counts: (j['counts'] as List).map((e) => e as int).toList(),
        chain: (j['chain'] as List).map((e) => Placed.fromJson(e)).toList(),
        scores: (j['scores'] as List).map((e) => e as int).toList(),
        names: (j['names'] as List).map((e) => e as String).toList(),
        avatars: (j['avs'] as List).map((e) => e as String).toList(),
        over: j['over'] as bool,
        gameOver: j['gover'] as bool,
        opening: j['opening'] as bool,
        gameWinnerTeam: j['gwt'] as int?,
        result: j['result'] == null ? null : RoundResult.fromJson(Map<String, dynamic>.from(j['result'] as Map)),
        revealed: j['rev'] == null
            ? null
            : (j['rev'] as List).map((h) => (h as List).map((e) => Tile.fromJson(e)).toList()).toList(),
      );
}

typedef GameEvent = void Function(String type, int seat, String text);

abstract class GameSession extends ChangeNotifier {
  ViewState? get view;
  GameEvent? onEvent;
  void play(int i, bool left);
  void pass();
  void buy();
  void next();
  void react(String emoji);
  void close();
}

/// قلب اللعبة: بيدير الأدوار والبوتات والنقط. شغّال أوفلاين وعلى جهاز المضيف أونلاين.
class GameCore {
  final GameConfig cfg;
  final List<SeatInfo> seats;
  final int humanTimeoutSec; // 0 = من غير مهلة
  final Random rng = Random();

  late Round round;
  late List<int> scores;
  int roundNo = 0;
  bool opening = false;
  bool gameOver = false;
  int? gameWinnerTeam;
  bool _disposed = false;
  Timer? _timer;
  Timer? _ackTimer;
  final Set<int> _acks = {};

  VoidCallback? onChange;
  GameEvent? onEvent;

  GameCore(this.cfg, this.seats, {this.humanTimeoutSec = 0}) {
    scores = List<int>.filled(cfg.n, 0);
  }

  void start() => _newRound(null);

  void restart() {
    scores = List<int>.filled(cfg.n, 0);
    roundNo = 0;
    gameOver = false;
    gameWinnerTeam = null;
    _newRound(null);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _ackTimer?.cancel();
  }

  void _emit(String type, int seat, String text) => onEvent?.call(type, seat, text);
  void _changed() {
    if (!_disposed) onChange?.call();
  }

  void _newRound(int? starter) {
    _timer?.cancel();
    _ackTimer?.cancel();
    _acks.clear();
    roundNo++;
    round = Round(cfg.n, cfg.teams, starter: starter);
    final op = round.opener;
    opening = op != null;
    _changed();
    if (op != null) {
      _timer = Timer(const Duration(milliseconds: 700), () {
        if (_disposed) return;
        final r = round;
        final i = r.hands[op.p].indexWhere((t) => t.same(op.tile));
        _emit('banner', op.p, op.isDouble ? 'دبل ${_ar(op.tile.a)}!' : 'افتتاح');
        _emit('toast', op.p, '${seats[op.p].name} افتتح ${op.isDouble ? 'بأكبر دبل' : 'بأكبر حجر'}');
        opening = false;
        r.play(op.p, i, false);
        _after();
      });
    } else {
      _tick();
    }
  }

  static String _ar(int n) => '٠١٢٣٤٥٦٧٨٩'[n];

  void _after() {
    if (round.over) {
      _finishRound();
    } else {
      _tick();
      _changed();
    }
  }

  void _tick() {
    if (_disposed || round.over || opening) return;
    _timer?.cancel();
    final p = round.turn;
    if (!seats[p].human) {
      _timer = Timer(Duration(milliseconds: 650 + rng.nextInt(500)), () => _bot(p));
      return;
    }
    final moves = round.legalMoves(p);
    final mustBuy = round.n == 2 && round.boneyard.isNotEmpty;
    if (moves.isEmpty && !mustBuy) {
      _timer = Timer(const Duration(milliseconds: 1000), () {
        if (_disposed || round.over || round.turn != p) return;
        _doPass(p);
      });
    } else if (humanTimeoutSec > 0) {
      _timer = Timer(Duration(seconds: humanTimeoutSec), () {
        if (_disposed || round.over || round.turn != p) return;
        seats[p].human = false; // البوت بياخد مكانه
        _emit('toast', p, '${seats[p].name} اتأخر — البوت كمّل مكانه');
        _bot(p);
      });
    }
  }

  void _bot(int p) {
    if (_disposed || round.over || round.turn != p || opening) return;
    var m = round.bestMove(p, cfg.level);
    var bought = 0;
    while (m == null && cfg.n == 2 && round.boneyard.isNotEmpty) {
      round.draw(p);
      bought++;
      m = round.bestMove(p, cfg.level);
    }
    if (bought > 0) _emit('toast', p, '${seats[p].name} اشترى $bought من الأرض');
    if (m != null) {
      _doPlay(p, m.i, m.left);
      if (rng.nextInt(100) < 7) {
        const talk = ['ماشي يا باشا!', 'دا انت جامد 👌', 'لسه بدري!', 'هاتلنا شاي ☕', 'دي ضربة معلم', 'هههه حلوة دي'];
        _emit('bubble', p, talk[rng.nextInt(talk.length)]);
      }
    } else {
      _doPass(p);
    }
  }

  void _doPlay(int p, int i, bool left) {
    _timer?.cancel();
    final t = round.play(p, i, left);
    if (t.isDouble) _emit('banner', p, 'دبل!');
    _emit('play', p, '');
    _after();
  }

  void _doPass(int p) {
    _timer?.cancel();
    round.pass(p);
    _emit('bubble', p, 'دقّ!');
    _emit('knock', p, '');
    _after();
  }

  // ------ أوامر اللاعبين ------
  void play(int seat, int i, bool left) {
    if (_disposed || round.over || opening || round.turn != seat) return;
    if (i < 0 || i >= round.hands[seat].length) return;
    final ok = round.legalMoves(seat).any((m) => m.i == i && (round.chain.isEmpty || m.left == left));
    if (!ok) return;
    _doPlay(seat, i, left);
  }

  void pass(int seat) {
    if (_disposed || round.over || opening || round.turn != seat) return;
    if (round.legalMoves(seat).isNotEmpty) return;
    if (round.n == 2 && round.boneyard.isNotEmpty) return;
    _doPass(seat);
  }

  void buy(int seat) {
    if (_disposed || round.over || opening || round.turn != seat) return;
    if (round.n != 2 || round.boneyard.isEmpty || round.legalMoves(seat).isNotEmpty) return;
    round.draw(seat);
    _emit('toast', seat, '${seats[seat].name} اشترى حجر');
    _tick();
    _changed();
  }

  void next(int seat) {
    if (_disposed || !round.over || gameOver) return;
    _acks.add(seat);
    final humans = [for (var i = 0; i < seats.length; i++) if (seats[i].human) i];
    if (humans.every(_acks.contains)) _newRound(round.result?.winner);
  }

  /// رمز تعبيري من لاعب، والبوتات ممكن ترد
  void react(int seat, String emoji) {
    if (_disposed) return;
    _emit('bubble', seat, emoji);
    final bots = [for (var i = 0; i < seats.length; i++) if (!seats[i].human) i];
    if (bots.isNotEmpty && rng.nextInt(100) < 55) {
      const talk = ['ماشي يا باشا!', 'دا انت جامد 👌', 'لسه بدري!', 'هاتلنا شاي ☕', 'دي ضربة معلم', 'هههه حلوة دي'];
      Timer(const Duration(milliseconds: 700), () {
        if (!_disposed) _emit('bubble', bots[rng.nextInt(bots.length)], talk[rng.nextInt(talk.length)]);
      });
    }
  }

  void _finishRound() {
    _timer?.cancel();
    final res = round.result!;
    if (res.winnerTeam != null) scores[res.winnerTeam!] += res.points;
    final done = <int>[];
    for (var p = 0; p < cfg.n; p++) {
      final t = cfg.teamOf(p);
      if (scores[t] >= cfg.target && !done.contains(t)) done.add(t);
    }
    if (done.isNotEmpty) {
      done.sort((a, b) => scores[b].compareTo(scores[a]));
      gameOver = true;
      gameWinnerTeam = done.first;
    } else {
      _ackTimer = Timer(const Duration(seconds: 15), () {
        if (!_disposed && round.over && !gameOver) _newRound(round.result?.winner);
      });
    }
    _changed();
  }

  ViewState viewFor(int seat) {
    final r = round;
    final mine = r.turn == seat && !r.over && !opening;
    final moves = mine ? r.legalMoves(seat) : <Move>[];
    return ViewState(
      cfg: cfg,
      mySeat: seat,
      round: roundNo,
      turn: r.turn,
      boneyard: r.boneyard.length,
      hand: List<Tile>.from(r.hands[seat]),
      moves: moves,
      canBuy: mine && moves.isEmpty && cfg.n == 2 && r.boneyard.isNotEmpty,
      counts: r.hands.map((h) => h.length).toList(),
      chain: List<Placed>.from(r.chain),
      scores: List<int>.from(scores),
      names: seats.map((s) => s.name).toList(),
      avatars: seats.map((s) => s.avatar).toList(),
      over: r.over,
      gameOver: gameOver,
      opening: opening,
      gameWinnerTeam: gameWinnerTeam,
      result: r.result,
      revealed: r.over ? r.hands.map((h) => List<Tile>.from(h)).toList() : null,
    );
  }
}

/// جلسة محلية (أوفلاين، أو جهاز المضيف أونلاين)
class LocalSession extends GameSession {
  final GameCore core;
  final int mySeat;
  final List<GameEvent> taps = [];

  LocalSession(this.core, {this.mySeat = 0}) {
    core.onChange = notifyListeners;
    core.onEvent = (t, s, x) {
      onEvent?.call(t, s, x);
      for (final f in taps) {
        f(t, s, x);
      }
    };
  }

  void begin() => core.start();

  @override
  void react(String e) => core.react(mySeat, e);

  @override
  ViewState? get view => core.roundNo == 0 ? null : core.viewFor(mySeat);

  @override
  void play(int i, bool left) => core.play(mySeat, i, left);
  @override
  void pass() => core.pass(mySeat);
  @override
  void buy() => core.buy(mySeat);
  @override
  void next() => core.next(mySeat);
  void restart() => core.restart();

  @override
  void close() {
    core.dispose();
    dispose();
  }
}
