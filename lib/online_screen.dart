import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config.dart';
import 'dialogs.dart';
import 'engine.dart';
import 'game_screen.dart';
import 'online.dart';
import 'session.dart';
import 'store.dart';
import 'widgets.dart';

GameConfig configFor(String mode, int target, Level level) =>
    GameConfig(n: mode == '2' ? 2 : 4, teams: mode == '4t', target: target, level: level);

/// قائمة الأونلاين: اعمل طاولة / ادخل بكود
void openOnline(BuildContext c, AppStore store) {
  if (!Config.ok) {
    showCard(c, title: 'قعدة صحاب 👥', buttons: const [CardBtn('تمام', gold: true)], body: const Text(
        'الأونلاين محتاج بيانات Supabase في الملف lib/config.dart (URL و anon key)، وبعدين تبني التطبيق تاني. كل التفاصيل في README.'));
    return;
  }
  showCard(c, title: 'قعدة صحاب 👥', buttons: [
    CardBtn('اعمل طاولة', gold: true, onTap: () => _createRoom(c, store)),
    CardBtn('ادخل بكود', onTap: () => _joinRoom(c, store)),
    const CardBtn('ارجع'),
  ], body: const Text('العب مع صحابك كل واحد في بيته. واحد يعمل طاولة ويبعت الكود، والباقي يدخلوا بيه. المقاعد الفاضية بتتملي بوتات.'));
}

void _createRoom(BuildContext c, AppStore store) {
  openSetup(c, store, title: 'طاولة أونلاين', goLabel: 'اعمل الطاولة', onGo: (mode, target, level) {
    final room = OnlineRoom.host(store, configFor(mode, target, level));
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => LobbyScreen(room: room, store: store)));
  });
}

void _joinRoom(BuildContext c, AppStore store) {
  final ctl = TextEditingController();
  showCard(c, title: 'ادخل بكود الطاولة', buttons: [
    CardBtn('ادخل', gold: true, onTap: () {
      final code = ctl.text.trim();
      if (code.length < 4) return;
      final room = OnlineRoom.join(store, code);
      Navigator.of(c).push(MaterialPageRoute(builder: (_) => LobbyScreen(room: room, store: store)));
    }),
    const CardBtn('ارجع'),
  ], body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('اطلب الكود من صاحبك اللي عمل الطاولة (٤ حروف).'),
    const SizedBox(height: 8),
    TextField(
      controller: ctl,
      maxLength: 4,
      textCapitalization: TextCapitalization.characters,
      textAlign: TextAlign.center,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]'))],
      style: const TextStyle(color: kInk, fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: 6),
      decoration: InputDecoration(filled: true, fillColor: kIvory, counterText: '', hintText: 'كود الطاولة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    ),
  ]));
}

class LobbyScreen extends StatefulWidget {
  final OnlineRoom room;
  final AppStore store;
  const LobbyScreen({super.key, required this.room, required this.store});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  OnlineRoom get room => widget.room;
  bool _pushed = false;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    room.addListener(_onRoom);
    room.connect();
  }

  @override
  void dispose() {
    room.removeListener(_onRoom);
    _leave();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_left) return;
    _left = true;
    await room.leave();
  }

  void _onRoom() {
    if (!mounted) return;
    if (room.error != null) {
      final msg = room.error!;
      room.removeListener(_onRoom);
      showCard(context, title: 'مش قادر أكمل', body: Text(msg), buttons: const [CardBtn('تمام', gold: true)]).then((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    if (room.started && room.session != null && !_pushed) {
      _pushed = true;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => GameScreen(session: room.session!, store: widget.store, onClose: _leave)))
          .then((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cfg = room.cfg;
    final modeText = cfg == null
        ? ''
        : cfg.n == 2
            ? 'طاولة لاتنين'
            : cfg.teams
                ? '٢ على ٢'
                : '٤ فرادى';
    return Scaffold(
      backgroundColor: kBg,
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [kTeal, kTeal2])),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('كود الطاولة', style: TextStyle(color: kGold2, fontWeight: FontWeight.w800, fontSize: 16)),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: room.code));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اتنسخ الكود')));
                    },
                    child: Text(room.code, style: const TextStyle(color: kIvory, fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: 10)),
                  ),
                  const Text('اضغط على الكود عشان تنسخه', style: TextStyle(color: Color(0xFFCDB98D), fontSize: 12)),
                  const SizedBox(height: 8),
                  if (cfg != null) Text('$modeText · لحد ${nf(cfg.target)}', style: const TextStyle(color: kIvory, fontSize: 16)),
                  const SizedBox(height: 10),
                  if (!room.connected)
                    const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: kGold))
                  else if (cfg != null)
                    ...List.generate(cfg.n, (seat) {
                      final p = room.players.where((x) => x.seat == seat).toList();
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFF0A2A2F), borderRadius: BorderRadius.circular(14), border: Border.all(color: p.isEmpty ? const Color(0xFF2D6A70) : kGold, width: 2)),
                        child: Row(children: [
                          Text(p.isEmpty ? '🤖' : '🙂', style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.isEmpty ? 'بوت (لو محدش دخل)' : p.first.name + (p.first.id == room.myId ? ' (أنت)' : ''), style: TextStyle(color: p.isEmpty ? const Color(0xFF8FB3B6) : kIvory, fontWeight: FontWeight.w800, fontSize: 17))),
                          if (cfg.n == 4 && cfg.teams) Text(seat % 2 == 0 ? 'فريق ١' : 'فريق ٢', style: const TextStyle(color: kGold2, fontSize: 12)),
                        ]),
                      );
                    })
                  else
                    const Text('بدوّر على الطاولة…', style: TextStyle(color: kIvory)),
                  const SizedBox(height: 14),
                  if (room.isHost)
                    WoodButton('ابدأ اللعب', gold: true, onTap: room.connected ? room.startGame : null)
                  else
                    const Text('مستني المضيف يبدأ اللعب…', style: TextStyle(color: kGold2, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  WoodButton('اطلع', small: true, onTap: () => Navigator.of(context).pop()),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
