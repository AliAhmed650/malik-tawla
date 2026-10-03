import 'package:flutter_test/flutter_test.dart';
import 'package:malik_tawla/engine.dart';

void main() {
  test('محاكاة آلاف الأدوار بدون أخطاء', () {
    for (final cfg in const [(2, false), (4, true), (4, false)]) {
      for (var k = 0; k < 1500; k++) {
        final r = Round(cfg.$1, cfg.$2);
        final o = r.opener!;
        r.play(o.p, r.hands[o.p].indexWhere((t) => t.same(o.tile)), false);
        var guard = 0;
        while (!r.over) {
          expect(++guard < 500, true, reason: 'infinite loop');
          final p = r.turn;
          var m = r.bestMove(p, Level.values[p % 3]);
          if (m == null && cfg.$1 == 2) {
            while (m == null && r.boneyard.isNotEmpty) {
              r.draw(p);
              m = r.bestMove(p, Level.normal);
            }
          }
          if (m != null) {
            r.play(p, m.i, m.left);
          } else {
            r.pass(p);
          }
        }
        final total = r.chain.length + r.boneyard.length + r.hands.fold<int>(0, (s, h) => s + h.length);
        expect(total, 28);
        for (var i = 1; i < r.chain.length; i++) {
          expect(r.chain[i - 1].r, r.chain[i].l);
        }
      }
    }
  });

  test('الافتتاح بأكبر دبل', () {
    for (var k = 0; k < 200; k++) {
      final r = Round(4, true);
      final o = r.opener!;
      var maxDouble = -1;
      for (final h in r.hands) {
        for (final t in h) {
          if (t.isDouble && t.a > maxDouble) maxDouble = t.a;
        }
      }
      if (maxDouble >= 0) {
        expect(o.isDouble, true);
        expect(o.tile.a, maxDouble);
      }
    }
  });
}
