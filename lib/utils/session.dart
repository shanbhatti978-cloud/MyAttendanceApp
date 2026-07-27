import 'package:flutter/foundation.dart';

/// Holds the currently logged-in user for the lifetime of the app run.
/// Kept deliberately simple (no persistent "remember me") since this is
/// a shared factory-floor device used by Admin/Supervisor each shift.
class Session extends ChangeNotifier {
  String? username;
  String? role;

  bool get isLoggedIn => username != null;
  bool get isAdmin => role == 'Admin';

  void login(String user, String userRole) {
    username = user;
    role = userRole;
    notifyListeners();
  }

  void logout() {
    username = null;
    role = null;
    notifyListeners();
  }
}
