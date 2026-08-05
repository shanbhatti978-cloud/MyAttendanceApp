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
  static String? lastInitError;

  /// True once Supabase has actually finished initializing. Sync
  /// should always check this — and call [initialize] again if it's
  /// still false — rather than assuming the one attempt at app
  /// startup succeeded.
  static bool get isReady => _initialized;

  /// Safe to call repeatedly. If a previous attempt failed (e.g. no
  /// internet during the very first app launch), calling this again
  /// later retries it — this is the fix for sync getting permanently
  /// stuck on "No connection" even after the phone comes back online,
  /// which happened when initialization was only ever attempted once.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
      _initialized = true;
      lastInitError = null;
    } catch (e) {
      // No network right now, or an unreachable project — that's
      // fine, the app runs fully offline either way. The next sync
      // attempt (manual "Sync Now" or the next connectivity-change
      // event) will call initialize() again automatically.
      lastInitError = e.toString();
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
