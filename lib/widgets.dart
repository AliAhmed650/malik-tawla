import 'package:flutter/material.dart';

const kBg = Color(0xFF0B1A1D);
const kTeal = Color(0xFF0F4A50);
const kTeal2 = Color(0xFF0A3238);
const kGold = Color(0xFFD9A84E);
const kGold2 = Color(0xFFF6D98A);
const kIvory = Color(0xFFF6EFDC);
const kInk = Color(0xFF2A1D0F);

String nf(num n) {
  const d = '٠١٢٣٤٥٦٧٨٩';
  final s = n.toString();
  final b = StringBuffer();
  for (final c in s.codeUnits) {
    b.write(c >= 48 && c <= 57 ? d[c - 48] : String.fromCharCode(c));
  }
  return b.toString();
}

const _pipCells = <int, List<int>>{
  0: [],
  1: [5],
  2: [1, 9],
  3: [1, 5, 9],
  4: [1, 3, 7, 9],
  5: [1, 3, 5, 7, 9],
  6: [1, 3, 4, 6, 7, 9],
};

/// حجر الدومينو
class DominoTile extends StatelessWidget {
  final int a, b;
  final bool horizontal;
  final double length; // الضلع الطويل
  final bool glow, dim, selected, hint;

  const DominoTile({
    super.key,
    required this.a,
    required this.b,
    this.horizontal = false,
    this.length = 60,
    this.glow = false,
    this.dim = false,
    this.selected = false,
    this.hint = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = horizontal ? length : length / 2;
    final h = horizontal ? length / 2 : length;
    Widget t = CustomPaint(size: Size(w, h), painter: _TilePainter(a, b, horizontal, dim));
    final shadows = <BoxShadow>[
      const BoxShadow(color: Color(0x88000000), blurRadius: 6, offset: Offset(0, 3)),
      if (glow) const BoxShadow(color: kGold2, blurRadius: 0, spreadRadius: 3),
      if (hint) const BoxShadow(color: Color(0xFF7DFF9A), blurRadius: 14, spreadRadius: 4),
      if (selected) const BoxShadow(color: kGold2, blurRadius: 16, spreadRadius: 2),
    ];
    t = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(w < h ? w * .2 : h * .2), boxShadow: shadows),
      child: t,
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      transform: Matrix4.translationValues(0, selected ? -14 : 0, 0),
      child: t,
    );
  }
}

class _TilePainter extends CustomPainter {
  final int a, b;
  final bool horizontal, dim;
  _TilePainter(this.a, this.b, this.horizontal, this.dim);

  @override
  void paint(Canvas canvas, Size size) {
    final short = horizontal ? size.height : size.width;
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(short * .2));
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dim ? const [Color(0xFFA29A86), Color(0xFF8B8470)] : const [Color(0xFFFFFAF0), Color(0xFFE6D9BB)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rr, fill);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFBBA97B),
    );
    final line = Paint()
      ..color = const Color(0xFFC9A34F)
      ..strokeWidth = 1.6;
    if (horizontal) {
      canvas.drawLine(Offset(size.width / 2, short * .12), Offset(size.width / 2, size.height - short * .12), line);
    } else {
      canvas.drawLine(Offset(short * .12, size.height / 2), Offset(size.width - short * .12, size.height / 2), line);
    }
    _pips(canvas, a, 0, short);
    _pips(canvas, b, 1, short);
  }

  void _pips(Canvas canvas, int v, int half, double short) {
    final ox = horizontal ? half * short : 0.0;
    final oy = horizontal ? 0.0 : half * short;
    final pad = short * .17;
    final cell = (short - pad * 2) / 2; // المسافة بين مراكز الحبّات
    final r = short * .075 + 0.6;
    final paint = Paint()..color = const Color(0xFF1C1A17);
    for (final c in _pipCells[v]!) {
      final row = (c - 1) ~/ 3, col = (c - 1) % 3;
      canvas.drawCircle(Offset(ox + pad + col * cell, oy + pad + row * cell), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TilePainter o) => o.a != a || o.b != b || o.horizontal != horizontal || o.dim != dim;
}

/// وش الحجر من ورا (للخصوم)
class TileBack extends StatelessWidget {
  final double w, h;
  const TileBack({super.key, this.w = 10, this.h = 20});
  @override
  Widget build(BuildContext context) => Container(
        width: w,
        height: h,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF8A6A2A)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A4036), Color(0xFF2A241E)],
          ),
        ),
      );
}

/// صورة اللاعب بإطار
class Avatar extends StatelessWidget {
  final String emoji;
  final String frame;
  final double size;
  const Avatar({super.key, required this.emoji, this.frame = 'rope', this.size = 44});

  @override
  Widget build(BuildContext context) {
    Color border = kGold;
    double bw = size * .09;
    List<BoxShadow> sh = const [BoxShadow(color: Color(0xFF5A3D12), spreadRadius: 2)];
    Gradient? grad;
    switch (frame) {
      case 'fanous':
        border = const Color(0xFFFFCF6B);
        sh = const [BoxShadow(color: Color(0xFFFFB52E), blurRadius: 12), BoxShadow(color: Color(0xFF5A3D12), spreadRadius: 2)];
        break;
      case 'khan':
        border = const Color(0xFFE9C47A);
        bw = size * .11;
        sh = const [BoxShadow(color: Color(0xFF7A1F2B), spreadRadius: 3)];
        break;
      case 'nile':
        border = const Color(0xFF4CC3D9);
        sh = const [BoxShadow(color: Color(0xFF4CC3D9), blurRadius: 10), BoxShadow(color: Color(0xFF0B3A47), spreadRadius: 2)];
        break;
      case 'gold':
        border = const Color(0xFFFFF2B0);
        grad = const LinearGradient(colors: [Color(0xFFB8802C), Color(0xFFFFF2B0)]);
        sh = const [BoxShadow(color: kGold2, blurRadius: 14), BoxShadow(color: Color(0xFF7A5217), spreadRadius: 2)];
        break;
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: grad == null ? const Color(0xFF1B3B40) : null,
        gradient: grad,
        border: Border.all(color: border, width: bw),
        boxShadow: sh,
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * .52)),
    );
  }
}

/// زرار عاجي/دهبي
class WoodButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool gold, small;
  final IconData? icon;
  const WoodButton(this.text, {super.key, this.onTap, this.gold = false, this.small = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: small ? 14 : 22, vertical: small ? 7 : 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: gold
                ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE7BF6A), Color(0xFFB98630)])
                : null,
            color: gold ? null : kIvory,
            boxShadow: [BoxShadow(color: gold ? const Color(0xFF7A5217) : const Color(0xFFB9A984), offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: small ? 16 : 20, color: kInk), const SizedBox(width: 6)],
            Text(text, style: TextStyle(color: gold ? const Color(0xFF2A1706) : kInk, fontWeight: FontWeight.w800, fontSize: small ? 14 : 17)),
          ]),
        ),
      ),
    );
  }
}

class CardBtn {
  final String text;
  final VoidCallback? onTap;
  final bool gold;
  final bool keepOpen;
  const CardBtn(this.text, {this.onTap, this.gold = false, this.keepOpen = false});
}

/// نافذة بشكل ورقة البردي على الخلفية التركواز
Future<void> showCard(
  BuildContext context, {
  required String title,
  required Widget body,
  List<CardBtn> buttons = const [],
  bool dismissible = true,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: Colors.black.withOpacity(.72),
    builder: (ctx) {
      final maxH = MediaQuery.of(ctx).size.height * .92;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 720, maxHeight: maxH),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF8A6A2A), width: 2), borderRadius: BorderRadius.circular(20)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFBF5E3), Color(0xFFE8DCC0)]),
                  ),
                  child: Text(title, textAlign: TextAlign.center, style: const TextStyle(color: kInk, fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                Flexible(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [kTeal, kTeal2]),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: SingleChildScrollView(
                      child: DefaultTextStyle(
                        style: const TextStyle(color: kIvory, fontSize: 16, height: 1.8),
                        child: body,
                      ),
                    ),
                  ),
                ),
                if (buttons.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: kTeal2,
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        for (final b in buttons)
                          WoodButton(b.text, gold: b.gold, small: true, onTap: () {
                            if (!b.keepOpen) Navigator.of(ctx).pop();
                            b.onTap?.call();
                          }),
                      ],
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
    },
  );
}
