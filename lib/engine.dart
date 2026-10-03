import 'dart:math';

/// حجر دومينو
class Tile {
  final int a, b;
  const Tile(this.a, this.b);
  int get pips => a + b;
  bool get isDouble => a == b;
  bool same(Tile o) => a == o.a && b == o.b;
  List<int> toJson() => [a, b];
  factory Tile.fromJson(dynamic j) => Tile((j as List)[0] as int, j[1] as int);
}

/// حجر متحط على الطاولة (l = الطرف الشمال، r = الطرف اليمين)
class Placed {
  final int l, r;
  const Placed(this.l, this.r);
  List<int> toJson() => [l, r];
  factory Placed.fromJson(dynamic j) => Placed((j as List)[0] as int, j[1] as int);
}

class Move {
  final int i;
  final bool left;
  const Move(this.i, this.left);
}

class RoundResult {
  final String how; // out | blocked
  final int? winnerTeam;
  final int? winner;
  final int points;
  const RoundResult(this.how, this.winnerTeam, this.winner, this.points);
  Map<String, dynamic> toJson() => {'how': how, 'wt': winnerTeam, 'w': winner, 'pts': points};
  factory RoundResult.fromJson(Map<String, dynamic> j) =>
      RoundResult(j['how'] as String, j['wt'] as int?, j['w'] as int?, j['pts'] as int);
}

enum Level { easy, normal, hard }

class OpenerInfo {
  final int p;
  final Tile tile;
  final bool isDouble;
  const OpenerInfo(this.p, this.tile, this.isDouble);
}

class Round {
  final int n;
  final bool teams;
  final Random rng;
  late List<List<Tile>> hands;
  late List<Tile> boneyard;
  final List<Placed> chain = [];
  int turn = 0;
  int passes = 0;
  bool over = false;
  RoundResult? result;
  OpenerInfo? opener;

  Round(this.n, this.teams, {int? starter, Random? random}) : rng = random ?? Random() {
    final all = <Tile>[];
    for (var i = 0; i <= 6; i++) {
      for (var j = i; j <= 6; j++) {
        all.add(Tile(i, j));
      }
    }
    all.shuffle(rng);
    hands = List.generate(n, (p) => List<Tile>.from(all.sublist(p * 7, p * 7 + 7)));
    boneyard = List<Tile>.from(all.sublist(n * 7));
    for (final h in hands) {
      sortHand(h);
    }
    if (starter == null) {
      OpenerInfo? best;
      var bestKey = -1;
      for (var p = 0; p < n; p++) {
        for (final t in hands[p]) {
          final key = t.isDouble ? 100 + t.a : t.pips;
          if (key > bestKey) {
            bestKey = key;
            best = OpenerInfo(p, t, t.isDouble);
          }
        }
      }
      opener = best;
      turn = best!.p;
    } else {
      turn = starter;
    }
  }

  static void sortHand(List<Tile> h) => h.sort((x, y) => y.pips - x.pips);

  int teamOf(int p) => (n == 4 && teams) ? p % 2 : p;

  int? get leftEnd => chain.isEmpty ? null : chain.first.l;
  int? get rightEnd => chain.isEmpty ? null : chain.last.r;

  List<Move> legalMoves(int p) {
    final moves = <Move>[];
    final l = leftEnd, r = rightEnd;
    for (var i = 0; i < hands[p].length; i++) {
      final t = hands[p][i];
      if (l == null) {
        moves.add(Move(i, false));
        continue;
      }
      if (t.a == l || t.b == l) moves.add(Move(i, true));
      if (t.a == r || t.b == r) moves.add(Move(i, false));
    }
    return moves;
  }

  /// يلعب حجر. بيرجّع الحجر اللي اتلعب.
  Tile play(int p, int i, bool left) {
    final t = hands[p][i];
    final l = leftEnd, r = rightEnd;
    Placed item;
    if (l == null) {
      item = Placed(t.a, t.b);
    } else if (left) {
      item = t.b == l ? Placed(t.a, t.b) : Placed(t.b, t.a);
      if (item.r != l) throw StateError('bad left move');
    } else {
      item = t.a == r ? Placed(t.a, t.b) : Placed(t.b, t.a);
      if (item.l != r) throw StateError('bad right move');
    }
    hands[p].removeAt(i);
    if (left && l != null) {
      chain.insert(0, item);
    } else {
      chain.add(item);
    }
    passes = 0;
    if (hands[p].isEmpty) {
      _finish(p, 'out');
    } else {
      turn = (p + 1) % n;
    }
    return t;
  }

  Tile? draw(int p) {
    if (boneyard.isEmpty) return null;
    final t = boneyard.removeLast();
    hands[p].add(t);
    sortHand(hands[p]);
    return t;
  }

  void pass(int p) {
    passes++;
    if (passes >= n && boneyard.isEmpty) {
      _finish(p, 'blocked');
    } else {
      turn = (p + 1) % n;
    }
  }

  int _handTotal(int p) => hands[p].fold(0, (s, t) => s + t.pips);

  void _finish(int p, String how) {
    final totals = <int, int>{};
    for (var q = 0; q < n; q++) {
      final tm = teamOf(q);
      totals[tm] = (totals[tm] ?? 0) + _handTotal(q);
    }
    int? winnerTeam;
    if (how == 'out') {
      winnerTeam = teamOf(p);
    } else {
      var min = 1 << 30;
      var cnt = 0;
      totals.forEach((k, v) {
        if (v < min) {
          min = v;
          cnt = 1;
          winnerTeam = k;
        } else if (v == min) {
          cnt++;
        }
      });
      if (cnt > 1) winnerTeam = null;
    }
    var points = 0;
    if (winnerTeam != null) {
      totals.forEach((k, v) {
        if (k != winnerTeam) points += v;
      });
    }
    int? winner;
    if (winnerTeam != null) {
      if (how == 'out') {
        winner = p;
      } else {
        var best = 1 << 30;
        for (var q = 0; q < n; q++) {
          if (teamOf(q) != winnerTeam) continue;
          final s = _handTotal(q);
          if (s < best) {
            best = s;
            winner = q;
          }
        }
      }
    }
    over = true;
    result = RoundResult(how, winnerTeam, winner, points);
  }

  // ---------------- الذكاء ----------------
  double _eval(int p, Move m, Level level) {
    final t = hands[p][m.i];
    if (level == Level.easy) return rng.nextDouble() * 10;
    var s = t.pips.toDouble() + (t.isDouble ? 2.5 : 0);
    final l = leftEnd, r = rightEnd;
    int e0, e1;
    if (l == null) {
      e0 = t.a;
      e1 = t.b;
    } else if (m.left) {
      e0 = t.a == l ? t.b : t.a;
      e1 = r!;
    } else {
      e0 = l;
      e1 = t.a == r ? t.b : t.a;
    }
    final rest = <Tile>[];
    for (var i = 0; i < hands[p].length; i++) {
      if (i != m.i) rest.add(hands[p][i]);
    }
    int cover(int x) => rest.where((q) => q.a == x || q.b == x).length;
    s += (cover(e0) + cover(e1)) * 1.4;
    if (level == Level.hard) {
      final seen = List<int>.filled(7, 0);
      for (final c in chain) {
        seen[c.l]++;
        seen[c.r]++;
      }
      for (final q in rest) {
        seen[q.a]++;
        seen[q.b]++;
      }
      s += (seen[e0] + seen[e1]) * 0.5;
      if (e0 == e1 && cover(e0) >= 2) s += 3;
      var minOpp = 99;
      for (var q = 0; q < n; q++) {
        if (teamOf(q) != teamOf(p) && hands[q].length < minOpp) minOpp = hands[q].length;
      }
      if (minOpp <= 2) s += t.pips * 0.8;
    }
    return s;
  }

  Move? bestMove(int p, Level level) {
    final ms = legalMoves(p);
    if (ms.isEmpty) return null;
    Move? best;
    var bestV = -1e9;
    for (final m in ms) {
      final v = _eval(p, m, level) + rng.nextDouble() * 0.01;
      if (v > bestV) {
        bestV = v;
        best = m;
      }
    }
    return best;
  }
}

/// تلميحة لحد اللاعب من حالته المرئية بس (بتشتغل أونلاين كمان)
int? hintIndex({
  required List<Tile> hand,
  required List<Move> moves,
  required List<Placed> chain,
}) {
  if (moves.isEmpty) return null;
  final seen = List<int>.filled(7, 0);
  for (final c in chain) {
    seen[c.l]++;
    seen[c.r]++;
  }
  for (final q in hand) {
    seen[q.a]++;
    seen[q.b]++;
  }
  final l = chain.isEmpty ? null : chain.first.l;
  final r = chain.isEmpty ? null : chain.last.r;
  int? bestI;
  var bestV = -1e9;
  for (final m in moves) {
    final t = hand[m.i];
    int e0, e1;
    if (l == null) {
      e0 = t.a;
      e1 = t.b;
    } else if (m.left) {
      e0 = t.a == l ? t.b : t.a;
      e1 = r!;
    } else {
      e0 = l;
      e1 = t.a == r ? t.b : t.a;
    }
    final rest = <Tile>[];
    for (var i = 0; i < hand.length; i++) {
      if (i != m.i) rest.add(hand[i]);
    }
    int cover(int x) => rest.where((q) => q.a == x || q.b == x).length;
    var v = t.pips.toDouble() + (t.isDouble ? 2.5 : 0) + (cover(e0) + cover(e1)) * 1.4 + (seen[e0] + seen[e1]) * 0.5;
    if (e0 == e1 && cover(e0) >= 2) v += 3;
    if (v > bestV) {
      bestV = v;
      bestI = m.i;
    }
  }
  return bestI;
}
