import 'session.dart';

const kBots = [
  ('الحاج منصور', '👳'),
  ('عم سيد', '🧓'),
  ('الأسطى كمال', '👷'),
];

/// يبني المقاعد: اللاعبين البشر في مقاعدهم، والباقي بوتات
List<SeatInfo> buildSeats(int n, Map<int, String> humans) {
  final order = n == 2 ? [1, 2, 0] : [1, 2, 0];
  var k = 0;
  final out = <SeatInfo>[];
  for (var seat = 0; seat < n; seat++) {
    if (humans.containsKey(seat)) {
      out.add(SeatInfo(humans[seat]!, '🙂', true));
    } else {
      final b = kBots[order[k % order.length]];
      k++;
      out.add(SeatInfo(b.$1, b.$2, false));
    }
  }
  return out;
}
