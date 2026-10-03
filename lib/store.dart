import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'engine.dart';

class FrameDef {
  final String id, name;
  final int price;
  const FrameDef(this.id, this.name, this.price);
}

class MissionDef {
  final String id, text, stat;
  final int goal, reward;
  const MissionDef(this.id, this.text, this.stat, this.goal, this.reward);
}

const kFrames = [
  FrameDef('rope', 'الأصلي', 0),
  FrameDef('fanous', 'فانوس', 120),
  FrameDef('khan', 'خان الخليلي', 200),
  FrameDef('nile', 'نيل', 250),
  FrameDef('gold', 'ملك الذهب', 500),
];

const kMissions = [
  MissionDef('m1', 'أول كسبة — اكسب أول قعدة', 'wins', 1, 30),
  MissionDef('m2', 'تلات انتصارات — اكسب ٣ قعدات', 'wins', 3, 60),
  MissionDef('m3', 'جدع ومخلص — اكسب ١٠ قعدات', 'wins', 10, 150),
  MissionDef('m4', 'دبل ملك — العب ٢٠ دبل', 'doubles', 20, 40),
  MissionDef('m5', 'إقفال — اقفل ٥ أدوار على الخصم', 'blocks', 5, 70),
  MissionDef('m6', 'دور ورا دور — اكسب ٣٠ دور', 'roundsWon', 30, 90),
  MissionDef('m7', 'أستاذ التلميح — استخدم التلميح ٥ مرات', 'hints', 5, 25),
  MissionDef('m8', 'قاعد على القهوة — العب ٢٥ قعدة', 'games', 25, 120),
];

class AppStore extends ChangeNotifier {
  SharedPreferences? _p;

  String name = 'اللاعب';
  int coins = 150;
  String frame = 'rope';
  List<String> owned = ['rope'];
  Map<String, bool> claimed = {};
  Map<String, int> stats = {
    'games': 0, 'wins': 0, 'rounds': 0, 'roundsWon': 0, 'doubles': 0, 'blocks': 0, 'hints': 0, 'best': 0,
  };
  bool sound = true;
  String mode = '4t'; // 2 | 4t | 4s
  int target = 101;
  Level level = Level.normal;
  String deviceId = '';

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p!.getString('malik_tawla_v1');
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        name = (j['name'] as String?) ?? name;
        coins = (j['coins'] as int?) ?? coins;
        frame = (j['frame'] as String?) ?? frame;
        owned = ((j['owned'] as List?) ?? owned).map((e) => e as String).toList();
        claimed = ((j['claimed'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, v as bool));
        final s = (j['stats'] as Map?) ?? {};
        for (final k in stats.keys.toList()) {
          if (s[k] is int) stats[k] = s[k] as int;
        }
        sound = (j['sound'] as bool?) ?? sound;
        mode = (j['mode'] as String?) ?? mode;
        target = (j['target'] as int?) ?? target;
        level = Level.values[((j['level'] as int?) ?? 1).clamp(0, 2).toInt()];
        deviceId = (j['deviceId'] as String?) ?? '';
      } catch (_) {}
    }
    if (deviceId.isEmpty) {
      final r = Random.secure();
      deviceId = List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
      await save();
    }
    notifyListeners();
  }

  Future<void> save() async {
    final j = {
      'name': name, 'coins': coins, 'frame': frame, 'owned': owned, 'claimed': claimed, 'stats': stats,
      'sound': sound, 'mode': mode, 'target': target, 'level': level.index, 'deviceId': deviceId,
    };
    await _p?.setString('malik_tawla_v1', jsonEncode(j));
  }

  void touch() {
    save();
    notifyListeners();
  }

  void bump(String k, [int by = 1]) {
    stats[k] = (stats[k] ?? 0) + by;
    touch();
  }

  void reset() {
    name = 'اللاعب';
    coins = 150;
    frame = 'rope';
    owned = ['rope'];
    claimed = {};
    stats.updateAll((k, v) => 0);
    touch();
  }
}
