/// حط هنا بيانات مشروع Supabase بتاعك (Settings > API).
/// الأونلاين بيستخدم Realtime Broadcast بس — مش محتاج جداول ولا SQL.
/// لازم تتأكد إن Realtime شغّال (Project Settings > Realtime) ومسموح بالـ public channels.
class Config {
  static const supabaseUrl = 'https://phdfxxgxaawkgpjtrfaz.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_X-fT1Hx9KtWX4NELIVdSlA_hqzwpekz';
  static bool get ok => !supabaseUrl.startsWith('YOUR_') && !supabaseAnonKey.startsWith('YOUR_');
}
