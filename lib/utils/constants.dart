import 'package:flutter/material.dart';

/// Central place for app-wide constant values so nothing is duplicated
/// or hard-coded across screens.
class AppConstants {
  static const String appName = "Reliance Attendance Management System";
  static const String appShortName = "RAMS";

  // Attendance status values used consistently across DB + UI
  static const String present = "Present";
  static const String absent = "Absent";
  static const String leave = "Leave";
  static const String weeklyRest = "Weekly Rest";

  static const List<String> attendanceStatuses = [
    present,
    absent,
    leave,
    weeklyRest,
  ];

  static const List<String> shifts = ["Morning", "Evening", "Night"];

  static const List<String> weekdays = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  static const List<String> employeeStatuses = ["Active", "Inactive"];

  // User roles
  static const String roleAdmin = "Admin";
  static const String roleSupervisor = "Supervisor";
}

/// Professional ERP-style color palette (blue/navy = trust + industrial feel)
class AppColors {
  static const Color primary = Color(0xFF0D47A1); // deep navy blue
  static const Color primaryLight = Color(0xFF5472D3);
  static const Color accent = Color(0xFF00897B); // teal accent
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFC62828);
  static const Color warning = Color(0xFFEF6C00);
  static const Color rest = Color(0xFF6A1B9A);
  static const Color background = Color(0xFFF3F5F9);
  static const Color card = Colors.white;
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Helper to color-code attendance statuses consistently everywhere
Color statusColor(String status) {
  switch (status) {
    case AppConstants.present:
      return AppColors.success;
    case AppConstants.absent:
      return AppColors.danger;
    case AppConstants.leave:
      return AppColors.warning;
    case AppConstants.weeklyRest:
      return AppColors.rest;
    default:
      return Colors.grey;
  }
}
