import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTest {
  static Future<void> checkConnection() async {
    try {
      final response = await Supabase.instance.client
          .from('employees')
          .select()
          .limit(1);

      print(response);
      print("SUPABASE CONNECTION SUCCESS");
    } catch (e) {
      print("SUPABASE CONNECTION FAILED");
      print(e);
    }
  }
}
