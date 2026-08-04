import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloud sync configuration. The "anon" key here is Supabase's public
/// client key — it's meant to ship inside client apps (same idea as a
/// Firebase web API key), and access is governed by the Row Level
/// Security policies set up in supabase_schema.sql, not by keeping
/// this key secret.
class SupabaseConfig {
  static const String url = 'https://drmthrldfvfeludvkpwk.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRybXRocmxkZnZmZWx1ZHZrcHdrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MzEwMDAsImV4cCI6MjEwMTMwNzAwMH0.8reJ422ue2EkFul0c3ILVHrbxqVlT_SNbu1kpd4CM68';

  static bool _initialized = false;

  /// Safe to call once at app startup. If it fails (e.g. no internet
  /// on first launch), the app must still continue working fully
  /// offline — sync simply activates later once connectivity returns.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
      _initialized = true;
    } catch (_) {
      // No network at startup, or an unreachable project — that's
      // fine, the app runs fully offline either way. Sync attempts
      // later will simply keep failing gracefully until it's reachable.
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
