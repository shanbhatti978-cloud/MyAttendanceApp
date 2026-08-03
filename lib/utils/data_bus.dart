import 'package:flutter/foundation.dart';

/// A tiny app-wide event bus used for "real-time" style refresh.
///
/// This is a local SQLite app (no server, no live sync), so a full
/// reactive-stream database layer would be overkill. Instead, DBHelper
/// calls [DataBus.instance.notifyChanged] after any write (attendance
/// saved, leave marked, employee added/edited/deleted, backup restored),
/// and any screen showing computed data (Dashboard, Reports, Shift
/// Planning) listens for that single signal and reloads itself. The
/// result, from the user's point of view, is exactly what was asked
/// for: edit a leave entry and every open report updates immediately,
/// with no manual refresh.
class DataBus extends ChangeNotifier {
  DataBus._internal();
  static final DataBus instance = DataBus._internal();

  void notifyChanged() => notifyListeners();
}
