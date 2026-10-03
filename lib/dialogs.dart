import 'package:flutter/material.dart';
import 'engine.dart';
import 'store.dart';
import 'widgets.dart';

void openRules(BuildContext c) {
  Widget p(String bold, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$bold ', style: const TextStyle(fontWeight: FontWeight.w900, color: kGold2)),
          TextSpan(text: t),
        ])),
      );
  showCard(c, title: 'أصول اللعبة 📜', buttons: const [CardBtn('فهمت يا أسطى ✓', gold: true)], body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    p('الهدف:', 'أول لاعب (أو فريق) يوصل للنقط المتفق عليها يكسب القعدة.'),
    p('الأحجار:', '٢٨ حجر من (٠-٠) لحد (٦-٦). كل واحد بياخد ٧. في لعب الاتنين الـ١٤ الباقيين «الأرض» تشتري منها لما ماعندكش حجر يمشي. في لعب الأربعة مفيش أرض.'),
    p('الافتتاح:', 'أول دور، اللي معاه أكبر دبل بيفتح بيه. بعد كده اللي كسب الدور اللي فات بيفتح بأي حجر.'),
    p('اللعب:', 'حط حجر رقمه زي رقم أي طرف. لو ماعندكش، في لعب الاتنين اشتري من الأرض لحد ما يجيلك حجر، ولو الأرض خلصت أو في لعب الأربعة تدق (تعدّي).'),
    p('كسب الدور:', 'اللي يخلّص أحجاره أولًا، وياخد مجموع نقط أحجار الباقيين (أو الفريق التاني).'),
    p('الإقفال:', 'لو الكل دقّ والأرض فاضية، اللي مجموع أحجاره أقل (أو فريقه) يكسب وياخد نقط الباقيين. لو اتساووا الدور يتعادل.'),
    p('ميزات ملك الطاولة:', 'تلميحة ٣ مرات في الدور، رموز تعبيرية، خزنة فيها إطارات للصورة، مهام بتكسّبك فلوس، ولعب أونلاين بكود طاولة.'),
  ]));
}

const _lessons = [
  ['الدرس ١: عدّ الأرقام', 'كل رقم من ٠ لـ٦ ليه ٧ أحجار بالظبط. لو الرقم ظهر ٦ مرات على الطاولة يبقى اللي باقي حجر واحد بس، وده أغلب الوقت معاك أو مع خصمك.'],
  ['الدرس ٢: ارمي التقيل بدري', 'الأحجار اللي نقطها كتير (٦-٥، ٦-٤) خطر لو الدور اتقفل عليك. اتخلص منها بدري وسيب الخفيف للآخر.'],
  ['الدرس ٣: خلّي أرقامك متنوعة', 'ماتخلصش كل أحجار رقم واحد بسرعة. التنوع معناه إنك دايمًا لاقي حجر تلعبه ومش هتضطر تدق.'],
  ['الدرس ٤: افهم شريكك', 'في ٢ على ٢، لو شريكك دق على رقم معين يبقى معندوش منه. ساعده بإنك تلعب الرقم ده عشان تفتحله الطريق.'],
  ['الدرس ٥: الإقفال سلاح', 'لو إيدك أخف من إيد الخصم، قفل الطاولة على رقم انت ماسك أغلبه. تكسب بالنقط من غير ما تخلّص.'],
  ['الدرس ٦: الدبل بيتحرق', 'الدبل ليه طريق واحد بس، فالأحسن تلعبه بدري ماتتعلقش بيه في الآخر.'],
];

void openSchool(BuildContext c, [int i = 0]) {
  final l = _lessons[i];
  final last = i == _lessons.length - 1;
  showCard(c, title: 'مدرسة الأسطى سيد 📖', body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l[0], style: const TextStyle(color: kGold2, fontSize: 19, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6),
    Text(l[1]),
    const SizedBox(height: 8),
    Text('درس ${nf(i + 1)} من ${nf(_lessons.length)}', style: const TextStyle(color: Color(0xFFCDB98D), fontSize: 13)),
  ]), buttons: [
    CardBtn('السابق', onTap: () => openSchool(c, (i + _lessons.length - 1) % _lessons.length)),
    CardBtn(last ? 'خلصت المدرسة' : 'التالي', gold: true, onTap: last ? null : () => openSchool(c, i + 1)),
  ]);
}

void openNotebook(BuildContext c, AppStore s) {
  final st = s.stats;
  final rate = st['games']! > 0 ? (st['wins']! * 100 / st['games']!).round() : 0;
  Widget row(String a, String b) => Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF2D6A70)))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(a), Text(b, style: const TextStyle(fontWeight: FontWeight.w900))]),
      );
  showCard(c, title: 'دفتري 📒', buttons: const [CardBtn('تمام', gold: true)], body: Column(children: [
    row('قعدات اتلعبت', nf(st['games']!)),
    row('قعدات كسبتها', nf(st['wins']!)),
    row('نسبة الكسب', '${nf(rate)}٪'),
    row('أدوار اتلعبت', nf(st['rounds']!)),
    row('أدوار كسبتها', nf(st['roundsWon']!)),
    row('دبل لعبته', nf(st['doubles']!)),
    row('إقفالات ناجحة', nf(st['blocks']!)),
    row('تلميحات استخدمتها', nf(st['hints']!)),
    row('أعلى نقط في دور', nf(st['best']!)),
  ]));
}

void openStore(BuildContext c, AppStore s) {
  showCard(c, title: 'خزنة القهوة ☕', buttons: const [CardBtn('ارجع')], body: StatefulBuilder(builder: (ctx, set) {
    final missions = kMissions.map((m) {
      final v = (s.stats[m.stat] ?? 0).clamp(0, m.goal);
      final ok = v >= m.goal;
      final cl = s.claimed[m.id] == true;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.text, style: const TextStyle(fontSize: 14, height: 1.4)),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: v / m.goal, minHeight: 7, backgroundColor: const Color(0xFF06191C), color: kGold),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          if (cl)
            const Text('✅')
          else if (ok)
            WoodButton('خد ${nf(m.reward)}', gold: true, small: true, onTap: () {
              s.claimed[m.id] = true;
              s.coins += m.reward;
              s.touch();
              set(() {});
            })
          else
            Text('${nf(v)}/${nf(m.goal)}', style: const TextStyle(fontSize: 12)),
        ]),
      );
    }).toList();
    final frames = kFrames.map((f) {
      final own = s.owned.contains(f.id), on = s.frame == f.id;
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A2A2F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? kGold : const Color(0xFF2D6A70), width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Avatar(emoji: '🙂', frame: f.id, size: 42),
          const SizedBox(height: 4),
          Text(f.name, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          WoodButton(on ? 'لابسه ✓' : own ? 'البسه' : 'هاته بـ ${nf(f.price)}', gold: !own, small: true, onTap: () {
            if (!own) {
              if (s.coins < f.price) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('فلوسك مش كفاية')));
                return;
              }
              s.coins -= f.price;
              s.owned.add(f.id);
            }
            s.frame = f.id;
            s.touch();
            set(() {});
          }),
        ]),
      );
    }).toList();
    return Column(children: [
      Text('🪙 ${nf(s.coins)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kGold2)),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('أوسمتك ومهامك', style: TextStyle(color: kGold2, fontWeight: FontWeight.w900)),
            ...missions,
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('إطارات الصورة', style: TextStyle(color: kGold2, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: frames),
          ]),
        ),
      ]),
    ]);
  }));
}

void openSettings(BuildContext c, AppStore s) {
  final ctl = TextEditingController(text: s.name);
  showCard(c, title: 'الإعدادات ⚙️', buttons: [
    CardBtn('حفظ', gold: true, onTap: () {
      final n = ctl.text.trim();
      s.name = n.isEmpty ? 'اللاعب' : (n.length > 14 ? n.substring(0, 14) : n);
      s.touch();
    }),
    const CardBtn('إلغاء'),
  ], body: StatefulBuilder(builder: (ctx, set) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('اسمك في اللعبة', style: TextStyle(color: kGold2, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      TextField(
        controller: ctl,
        maxLength: 14,
        textAlign: TextAlign.center,
        style: const TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 18),
        decoration: InputDecoration(filled: true, fillColor: kIvory, counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('الصوت والاهتزاز'),
        WoodButton(s.sound ? 'شغّال 🔊' : 'مقفول 🔇', small: true, onTap: () {
          s.sound = !s.sound;
          s.touch();
          set(() {});
        }),
      ]),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('مسح كل التقدم'),
        WoodButton('مسح', small: true, onTap: () {
          Navigator.of(ctx).pop();
          showCard(c, title: 'متأكد؟', body: const Text('كل التقدم والفلوس هيتمسحوا.'), buttons: [
            CardBtn('امسح', gold: true, onTap: s.reset),
            const CardBtn('لأ'),
          ]);
        }),
      ]),
    ]);
  }));
}

/// إعداد قعدة جديدة (أوفلاين أو إنشاء طاولة أونلاين)
void openSetup(BuildContext c, AppStore s, {required String title, required String goLabel, required void Function(String mode, int target, Level level) onGo}) {
  var mode = s.mode, target = s.target, level = s.level;
  showCard(c, title: title, buttons: [
    CardBtn(goLabel, gold: true, onTap: () {
      s.mode = mode;
      s.target = target;
      s.level = level;
      s.touch();
      onGo(mode, target, level);
    }),
    const CardBtn('ارجع'),
  ], body: StatefulBuilder(builder: (ctx, set) {
    Widget group<T>(String label, List<(String, T)> opts, T cur, void Function(T) pick) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: kGold2, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in opts)
            GestureDetector(
              onTap: () => set(() => pick(o.$2)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: cur == o.$2 ? kIvory : const Color(0xFF0B2A2F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cur == o.$2 ? kGold : const Color(0xFF2D6A70), width: 2),
                ),
                child: Text(o.$1, style: TextStyle(color: cur == o.$2 ? kInk : kIvory, fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
        ]),
        const SizedBox(height: 12),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      group<String>('شكل القعدة', const [('طاولة لاتنين', '2'), ('٢ على ٢ (معاك شريك)', '4t'), ('٤ فرادى', '4s')], mode, (v) => mode = v),
      group<int>('لحد كام نقطة؟', const [('٥١', 51), ('١٠١', 101), ('١٥١', 151)], target, (v) => target = v),
      group<Level>('مستوى البوتات', const [('مبتدئ', Level.easy), ('أسطى', Level.normal), ('معلم', Level.hard)], level, (v) => level = v),
    ]);
  }));
}
