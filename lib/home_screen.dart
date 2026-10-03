import 'package:flutter/material.dart';
import 'bots.dart';
import 'dialogs.dart';
import 'engine.dart';
import 'game_screen.dart';
import 'online_screen.dart';
import 'session.dart';
import 'store.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  final AppStore store;
  const HomeScreen({super.key, required this.store});

  void _startLocal(BuildContext c, String mode, int target, Level level) {
    final cfg = configFor(mode, target, level);
    final core = GameCore(cfg, buildSeats(cfg.n, {0: store.name}));
    final ss = LocalSession(core);
    ss.begin();
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => GameScreen(session: ss, store: store, onClose: ss.close)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final h = MediaQuery.of(context).size.height;
        return Scaffold(
          backgroundColor: const Color(0xFF120B07),
          body: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(center: Alignment(0, -.3), radius: 1.2, colors: [Color(0xFF2B1B10), Color(0xFF120B07), Color(0xFF080504)]),
            ),
            child: SafeArea(
              child: Stack(children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 44, 12, 8),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Image.asset('assets/logo.png', height: (h * .27).clamp(70.0, 140.0).toDouble()),
                      Text('ملك الطاولة',
                          style: TextStyle(
                            color: kGold,
                            fontSize: (h * .11).clamp(30.0, 52.0).toDouble(),
                            fontWeight: FontWeight.w900,
                            shadows: const [Shadow(color: Color(0xFF5A3D12), offset: Offset(0, 4)), Shadow(color: Colors.black87, blurRadius: 18)],
                          )),
                      const Text('دومينو بالأصول المصرية 👑', style: TextStyle(color: Color(0xFFE7D7B0), fontSize: 16)),
                      const SizedBox(height: 14),
                      Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
                        _MenuBtn('🁫', 'ابدأ قعدة', main: true, onTap: () {
                          openSetup(context, store, title: 'ابدأ قعدة', goLabel: 'يلا نلعب', onGo: (m, t, l) => _startLocal(context, m, t, l));
                        }),
                        _MenuBtn('📖', 'مدرسة الأسطى', onTap: () => openSchool(context)),
                        _MenuBtn('👥', 'قعدة صحاب', onTap: () => openOnline(context, store)),
                        _MenuBtn('☕', 'الخزنة والمهام', onTap: () => openStore(context, store)),
                        _MenuBtn('📜', 'أصول اللعبة', onTap: () => openRules(context)),
                        _MenuBtn('📒', 'دفتري', onTap: () => openNotebook(context, store)),
                      ]),
                    ]),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  top: 6,
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => openSettings(context, store),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: kIvory, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0xFFB9A984), offset: Offset(0, 3))]),
                        child: const Icon(Icons.settings_rounded, color: kInk),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: kIvory, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0xFFB9A984), offset: Offset(0, 3))]),
                      child: Text('🪙 ${nf(store.coins)}', style: const TextStyle(color: kInk, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF3B2A12), Color(0xFF5A3D12)]),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFB88A3C)),
                      ),
                      child: Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kGold2, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Avatar(emoji: '🙂', frame: store.frame, size: 42),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _MenuBtn extends StatelessWidget {
  final String icon, text;
  final VoidCallback onTap;
  final bool main;
  const _MenuBtn(this.icon, this.text, {required this.onTap, this.main = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: main ? 118 : 100,
        height: main ? 100 : 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: main ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE7BF6A), Color(0xFFB98630)]) : null,
          color: main ? null : kIvory,
          boxShadow: [
            BoxShadow(color: main ? const Color(0xFF7A5217) : const Color(0xFFB9A984), offset: const Offset(0, 5)),
            const BoxShadow(color: Color(0x73000000), blurRadius: 14, offset: Offset(0, 8)),
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(icon, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 4),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: main ? const Color(0xFF2A1706) : kInk, fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      ),
    );
  }
}
