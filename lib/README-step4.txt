الخطوة 4 — الأونلاين (Supabase)

1) في الترمنال جوه المشروع:   flutter pub add supabase_flutter
2) انسخ ملفات فولدر lib هنا فوق lib بتاعك (5 ملفات: config, online, online_screen, home_screen, main).
3) افتح lib/config.dart وحط:
     supabaseUrl      = رابط المشروع (Project Settings > API > Project URL)
     supabaseAnonKey  = المفتاح اللي اسمه anon / public (مش service_role!)
   تقدر تستخدم نفس مشروع Supabase بتاع رفقة. مش محتاج جداول ولا SQL.
4) flutter run
