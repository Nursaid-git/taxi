/// Ключи и конфигурация приложения.
///
/// 1) Supabase: Dashboard → Project Settings → API
///    - Project URL  → [supabaseUrl]
///    - anon public  → [supabaseAnonKey]   (этот ключ публичный, его не страшно
///      держать в приложении — доступ всё равно ограничен RLS).
///
/// 2) Google Maps (Android): ключ НЕ здесь, а в
///    android/app/src/main/AndroidManifest.xml (meta-data com.google.android.geo.API_KEY).
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = 'https://qrlqslkbridskjarczls.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFybHFzbGticmlkc2tqYXJjemxzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MTE4OTUsImV4cCI6MjA5NzA4Nzg5NX0.bXjljgiJ6hTJOrpMD2rGlXDes4_n5UP1uOWXVC22Znc';

  /// true, если ключи Supabase реально вставлены (для подсказок в UI).
  static bool get isSupabaseConfigured =>
      !supabaseUrl.contains('YOUR-PROJECT') && supabaseAnonKey != 'YOUR_ANON_KEY';
}
