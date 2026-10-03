import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'home_screen.dart';
import 'store.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  if (Config.ok) {
    try {
      await Supabase.initialize(url: Config.supabaseUrl, anonKey: Config.supabaseAnonKey);
    } catch (_) {}
  }
  final store = AppStore();
  await store.load();
  runApp(MalikTawlaApp(store: store));
}

class MalikTawlaApp extends StatelessWidget {
  final AppStore store;
  const MalikTawlaApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ملك الطاولة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(primary: kGold, secondary: kGold2),
        useMaterial3: true,
      ),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox()),
      home: HomeScreen(store: store),
    );
  }
}
