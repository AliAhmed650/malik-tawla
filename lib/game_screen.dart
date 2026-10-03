import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'engine.dart';
import 'session.dart';
import 'store.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  final GameSession session;
  final AppStore store;
  final VoidCallback onClose;
  const GameScreen({super.key, required this.session, required this.store, required this.onClose});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameSession get s => widget.session;
  AppStore get st => widget.store;

  int? _sel; // حجر مستني اختيار الطرف
  int? _hintIdx;
  int _hintsLeft = 3;
  int _round = -1;
  int _lastChain = 0;
  int _recordedRound = -1;
  bool _recordedGame = false;
  bool _resultOpen = false;
  bool _overOpen = false;
  bool _closed = false;

  String? _banner;
  Timer? _bannerT;
  String? _toast;
  Timer? _toastT;
  final Map<int, String> _bubbles = {};
  final Map<int, Timer> _bubbleT = {};

  @override
  void initState() {
    super.initState();
    s.onEvent = _onEvent;
    s.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onChange());
  }

  @override
  void dispose() {
    s.removeListener(_onChange);
    s.onEvent = null;
    _bannerT?.cancel();
    _toastT?.cancel();
    for (final t in _bubbleT.values) {
      t.cancel();
    }
    if (!_closed) {
      _closed = true;
      widget.onClose();
    }
    super.dispose();
  }

  // ---------- أحداث ----------
  void _onEvent(String type, int seat, String text) {
    if (!mounted) return;
    final v = s.view;
    switch (type) {
      case 'banner':
        setState(() => _banner = text);
        _bannerT?.cancel();
        _bannerT = Timer(const Duration(milliseconds: 1100), () {
          if (mounted) setState(() => _banner = null);
        });
        if (v != null && seat == v.mySeat && text.startsWith('دبل')) st.bump('doubles');
        break;
      case 'toast':
        setState(() => _toast = text);
        _toastT?.cancel();
        _toastT = Timer(const Duration(milliseconds: 1700), () {
          if (mounted) setState(() => _toast = null);
        });
        break;
      case 'bubble':
        setState(() => _bubbles[seat] = text);
        _bubbleT[seat]?.cancel();
        _bubbleT[seat] = Timer(const Duration(milliseconds: 2200), () {
          if (mounted) setState(() => _bubbles.remove(seat));
        });
        break;
      case 'play':
        if (st.sound) {
          SystemSound.play(SystemSoundType.click);
          HapticFeedback.lightImpact();
        }
        break;
      case 'knock':
        if (st.sound) HapticFeedback.heavyImpact();
        break;
    }
  }

  void _onChange() {
    if (!mounted) return;
    final v = s.view;
    if (v == null) return;
    if (v.round < _round) _recordedRound = -1; // قعدة جديدة بدأت من الأول
    if (v.round != _round) {
      _round = v.round;
      _hintsLeft = 3;
      _hintIdx = null;
      _sel = null;
    }
    if (!v.myTurn) {
      _sel = null;
    }
    // الدور الجديد بدأ → اقفل نافذة النتيجة
    if (!v.over && _resultOpen) {
      _resultOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!v.gameOver && _overOpen) {
      _overOpen = false;
      _recordedGame = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (v.over && _recordedRound != v.round) {
      _recordedRound = v.round;
      _recordRound(v);
      if (v.gameOver) {
        _recordGame(v);
        WidgetsBinding.instance.addPostFrameCallback((_) => _showGameOver(v));
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showResult(v));
      }
    }
    setState(() {});
  }

  void _recordRound(ViewState v) {
    final r = v.result!;
    st.stats['rounds'] = (st.stats['rounds'] ?? 0) + 1;
    if (r.winnerTeam != null && r.winnerTeam == v.myTeam) {
      st.stats['roundsWon'] = (st.stats['roundsWon'] ?? 0) + 1;
      if (r.how == 'blocked') st.stats['blocks'] = (st.stats['blocks'] ?? 0) + 1;
      st.stats['best'] = max(st.stats['best'] ?? 0, r.points);
    }
    st.touch();
  }

  int _reward = 0;
  bool _won = false;
  void _recordGame(ViewState v) {
    if (_recordedGame) return;
    _recordedGame = true;
    _won = v.gameWinnerTeam == v.myTeam;
    st.stats['games'] = (st.stats['games'] ?? 0) + 1;
    _reward = 10;
    if (_won) {
      st.stats['wins'] = (st.stats['wins'] ?? 0) + 1;
      final lv = v.cfg.level;
      _reward = 40 + (v.cfg.target / 10).round() * 2 + (lv == Level.hard ? 30 : lv == Level.normal ? 10 : 0);
    }
    st.coins += _reward;
    st.touch();
  }

  // ---------- أدوات العرض ----------
  int _rel(ViewState v, int p) => (p - v.mySeat + v.n) % v.n;

  String _name(ViewState v, int p) {
    final base = p == v.mySeat ? st.name : v.names[p];
    if (v.n == 4 && v.cfg.teams && _rel(v, p) == 2) return '$base (شريكك)';
    return base;
  }

  List<int> _teamKeys(ViewState v) {
    final keys = <int>[];
    for (var p = 0; p < v.n; p++) {
      final k = v.cfg.teamOf(p);
      if (!keys.contains(k)) keys.add(k);
    }
    return keys;
  }

  String _teamLabel(ViewState v, int team) {
    if (v.cfg.teams && v.n == 4) return team == v.myTeam ? 'إحنا' : 'هما';
    return team == v.mySeat ? 'أنت' : v.names[team];
  }

  String _scoreLine(ViewState v) => _teamKeys(v).map((k) => '${_teamLabel(v, k)}: ${nf(v.scores[k])}').join('   |   ');

  // ---------- تفاعل ----------
  void _tapTile(ViewState v, int i) {
    if (!v.myTurn) return;
    final mv = v.moves.where((m) => m.i == i).toList();
    if (mv.isEmpty) {
      _say('الحجر ده مايلعبش دلوقتي');
      return;
    }
    setState(() => _hintIdx = null);
    if (v.chain.isEmpty) return s.play(i, false);
    final sides = mv.map((m) => m.left).toSet();
    if (sides.length == 1) return s.play(i, sides.first);
    if (v.leftEnd == v.rightEnd) return s.play(i, false);
    setState(() => _sel = i);
  }

  void _say(String t) => _onEvent('toast', 0, t);

  void _hint(ViewState v) {
    if (_hintsLeft <= 0 || !v.myTurn) return;
    final i = hintIndex(hand: v.hand, moves: v.moves, chain: v.chain);
    if (i == null) return;
    _hintsLeft--;
    st.bump('hints');
    setState(() => _hintIdx = i);
    _say('جرّب الحجر المنوّر');
  }

  Future<void> _leave() async {
    await showCard(context, title: 'تسيب القعدة؟', body: const Text('التقدم في القعدة دي مش هيتحفظ.'), buttons: [
      CardBtn('أيوه اطلع', gold: true, onTap: () => Navigator.of(context).pop()),
      const CardBtn('لأ كمّل'),
    ]);
  }

  void _showResult(ViewState v) {
    if (!mounted || !v.over || v.gameOver) return;
    _resultOpen = true;
    showCard(context, title: 'نتيجة الدور', dismissible: false, body: _resultBody(v), buttons: [
      CardBtn('الدور الجاي', gold: true, keepOpen: true, onTap: () {
        s.next();
        _say('مستني باقي اللاعبين…');
      }),
    ]).then((_) => _resultOpen = false);
  }

  void _showGameOver(ViewState v) {
    if (!mounted) return;
    _overOpen = true;
    final canRestart = s is LocalSession;
    showCard(context, title: _won ? 'مبروك! كسبت القعدة 🏆' : 'القعدة خلصت', dismissible: false, body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _resultBody(v),
      const SizedBox(height: 8),
      Center(child: Text('🪙 +${nf(_reward)}', style: const TextStyle(fontSize: 20, color: kGold2, fontWeight: FontWeight.w900))),
      if (!canRestart) const Padding(padding: EdgeInsets.only(top: 6), child: Text('المضيف يقدر يبدأ قعدة جديدة.', style: TextStyle(fontSize: 13))),
    ]), buttons: [
      if (canRestart)
        CardBtn('قعدة تانية', gold: true, keepOpen: true, onTap: () {
          _overOpen = false;
          _recordedGame = false;
          Navigator.of(context, rootNavigator: true).pop();
          (s as LocalSession).restart();
        }),
      CardBtn('القائمة', onTap: () => Navigator.of(context).pop()),
    ]).then((_) => _overOpen = false);
  }

  Widget _resultBody(ViewState v) {
    final r = v.result!;
    String head;
    if (r.winnerTeam == null) {
      head = 'الدور اتقفل واتعادل 🤝';
    } else if (r.how == 'out') {
      head = '${_name(v, r.winner!)} خلّص أحجاره وكسب ${nf(r.points)} نقطة';
    } else {
      head = 'الدور اتقفل — ${_name(v, r.winner!)} إيده أخف وكسب ${nf(r.points)} نقطة';
    }
    final rows = <Widget>[];
    for (var p = 0; p < v.n; p++) {
      final h = v.revealed?[p] ?? const <Tile>[];
      final tot = h.fold<int>(0, (a, t) => a + t.pips);
      rows.add(Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF2D6A70)))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_name(v, p), style: const TextStyle(fontSize: 14)),
          Text(h.isEmpty ? 'خلّص ✓' : '${h.map((t) => '${nf(t.a)}|${nf(t.b)}').join('  ')} = ${nf(tot)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(head, style: const TextStyle(color: kGold2, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      ...rows,
      const SizedBox(height: 8),
      Text(_scoreLine(v), style: const TextStyle(fontWeight: FontWeight.w800)),
    ]);
  }

  // ---------- الرسم ----------
  @override
  Widget build(BuildContext context) {
    final v = s.view;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF5B2F17),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(center: Alignment(0, -.2), radius: 1.1, colors: [Color(0xFF7A4224), Color(0xFF4A2412), Color(0xFF2E160A)]),
          ),
          child: SafeArea(child: v == null ? const Center(child: CircularProgressIndicator(color: kGold)) : _table(v)),
        ),
      ),
    );
  }

  Widget _table(ViewState v) {
    final size = MediaQuery.of(context).size;
    final handLen = min(88.0, size.height * .23);
    final chainLen = min(46.0, size.width / 20);
    return Column(children: [
      // الشريط العلوي
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        child: Row(children: [
          _roundBtn(Icons.arrow_forward_rounded, _leave),
          Expanded(
            child: Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
              for (final k in _teamKeys(v))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xC70A0603),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: k == v.myTeam || (!v.cfg.teams && k == v.mySeat) ? kGold2 : const Color(0xFF8A6A2A), width: 2),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_teamLabel(v, k), style: const TextStyle(color: kIvory, fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(nf(v.scores[k]), style: const TextStyle(color: kGold2, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1)),
                  ]),
                ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: kIvory, borderRadius: BorderRadius.circular(14)),
            child: Text('الدور ${nf(v.round)} · لحد ${nf(v.cfg.target)}', style: const TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
      ),
      // الطاولة
      Expanded(
        child: Stack(children: [
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: v.n == 4 ? 110 : 30, vertical: 36),
                child: SingleChildScrollView(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 3,
                      runSpacing: 4,
                      children: [
                        for (final c in v.chain)
                          DominoTile(a: c.l, b: c.r, horizontal: c.l != c.r, length: chainLen),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          ..._seats(v),
          Align(
            alignment: const Alignment(0, -.55),
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _banner == null ? 0 : 1,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 250),
                  scale: _banner == null ? .6 : 1,
                  child: Text(_banner ?? '', style: const TextStyle(color: kGold2, fontSize: 42, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 18), Shadow(color: Color(0xFF5A3D12), offset: Offset(0, 4))])),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _toast == null ? 0 : 1,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(16)),
                  child: Text(_toast ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ]),
      ),
      _bottom(v, handLen),
    ]);
  }

  Widget _roundBtn(IconData i, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: kIvory, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0xFFB9A984), offset: Offset(0, 3))]),
          child: Icon(i, color: kInk, size: 22),
        ),
      );

  List<Widget> _seats(ViewState v) {
    final out = <Widget>[];
    for (var p = 0; p < v.n; p++) {
      if (p == v.mySeat) continue;
      final rel = _rel(v, p);
      final Alignment al;
      if (v.n == 2) {
        al = Alignment.topCenter;
      } else {
        al = rel == 1 ? Alignment.centerRight : rel == 2 ? Alignment.topCenter : Alignment.centerLeft;
      }
      final turn = v.turn == p && !v.over;
      final top = al == Alignment.topCenter;
      out.add(Align(
        alignment: al,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_bubbles[p] != null) _bubble(_bubbles[p]!),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xC70A0603),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: turn ? const Color(0xFFFFE08A) : const Color(0xFF6B5224), width: 2),
                boxShadow: turn ? const [BoxShadow(color: Color(0xB3FFE08A), blurRadius: 16)] : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Avatar(emoji: v.avatars[p], size: 32),
                const SizedBox(width: 6),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(_name(v, p), style: const TextStyle(color: kIvory, fontWeight: FontWeight.w800, fontSize: 13)),
                  Text('${nf(v.counts[p])} أحجار', style: const TextStyle(color: Color(0xFFCDB98D), fontSize: 11)),
                  if (top)
                    Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < v.counts[p]; i++) const TileBack(w: 9, h: 18)]),
                ]),
              ]),
            ),
          ]),
        ),
      ));
    }
    return out;
  }

  Widget _bubble(String t) => Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: kIvory, borderRadius: BorderRadius.circular(12)),
        child: Text(t, style: const TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 14)),
      );

  Widget _bottom(ViewState v, double handLen) {
    String status;
    if (v.over) {
      status = 'الدور خلص';
    } else if (v.opening) {
      status = 'الافتتاح بأكبر حجر…';
    } else if (v.turn != v.mySeat) {
      status = 'دور ${_name(v, v.turn)}…';
    } else if (_sel != null) {
      status = 'تحطه فين؟';
    } else if (v.moves.isNotEmpty) {
      status = 'دورك — اختار حجر';
    } else if (v.canBuy) {
      status = 'ماعندكش حجر مناسب';
    } else {
      status = 'مفيش حجر مناسب… دقّ';
    }
    final actions = <Widget>[];
    if (v.myTurn) {
      if (_sel != null) {
        actions.add(WoodButton('شمال (${nf(v.leftEnd ?? 0)})', gold: true, small: true, onTap: () {
          final i = _sel!;
          setState(() => _sel = null);
          s.play(i, true);
        }));
        actions.add(WoodButton('يمين (${nf(v.rightEnd ?? 0)})', gold: true, small: true, onTap: () {
          final i = _sel!;
          setState(() => _sel = null);
          s.play(i, false);
        }));
        actions.add(WoodButton('إلغاء', small: true, onTap: () => setState(() => _sel = null)));
      } else if (v.moves.isNotEmpty) {
        if (_hintsLeft > 0) actions.add(WoodButton('💡 تلميحة (${nf(_hintsLeft)})', small: true, onTap: () => _hint(v)));
      } else if (v.canBuy) {
        actions.add(WoodButton('اشتري من الأرض (${nf(v.boneyard)})', gold: true, small: true, onTap: s.buy));
      }
    }
    final movable = v.myTurn ? v.moves.map((m) => m.i).toSet() : <int>{};
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 38,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(status, style: const TextStyle(color: kGold2, fontWeight: FontWeight.w800, fontSize: 16, shadows: [Shadow(color: Colors.black, blurRadius: 6)])),
            const SizedBox(width: 12),
            ...actions.expand((w) => [w, const SizedBox(width: 8)]),
          ]),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // أنا
          Column(mainAxisSize: MainAxisSize.min, children: [
            if (_bubbles[v.mySeat] != null) _bubble(_bubbles[v.mySeat]!),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xC70A0603),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: v.myTurn ? const Color(0xFFFFE08A) : const Color(0xFF8A6A2A), width: 2),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Avatar(emoji: '🙂', frame: st.frame, size: 34),
                Text(st.name, style: const TextStyle(color: kIvory, fontWeight: FontWeight.w800, fontSize: 11)),
              ]),
            ),
          ]),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < v.hand.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => _tapTile(v, i),
                        child: DominoTile(
                          a: v.hand[i].a,
                          b: v.hand[i].b,
                          length: handLen,
                          glow: v.myTurn && movable.contains(i),
                          dim: v.myTurn && !movable.contains(i),
                          selected: _sel == i,
                          hint: _hintIdx == i,
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          // الرموز
          Column(mainAxisSize: MainAxisSize.min, children: [
            for (final e in const ['😂', '👏', '😎', '🔥'])
              GestureDetector(
                onTap: () => s.react(e),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xB30A0603), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF8A6A2A))),
                  child: Text(e, style: const TextStyle(fontSize: 17)),
                ),
              ),
          ]),
        ]),
      ]),
    );
  }
}
