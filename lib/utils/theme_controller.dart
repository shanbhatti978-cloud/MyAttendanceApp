import 'package:flutter/material.dart';

import '../db/db_helper.dart';

/// Controls Light/Dark mode for the whole app. Kept intentionally
/// simple — one ChangeNotifier holding the current ThemeMode, backed
/// by the same local settings table everything else uses (no new
/// storage mechanism, no extra dependency).
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    final saved = await DBHelper.instance.getSetting('theme_mode', fallback: 'light');
    _mode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggle(bool dark) async {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    await DBHelper.instance.setSetting('theme_mode', dark ? 'dark' : 'light');
    notifyListeners();
  }
}
