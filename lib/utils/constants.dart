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

  static const List<String> shifts = ["Morning", "Evening", "Night", "A", "B", "C", "General"];

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

  // Dark mode surfaces
  static const Color darkBackground = Color(0xFF10141C);
  static const Color darkCard = Color(0xFF1B2130);
  static const Color darkPrimary = Color(0xFF6D93E8);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 1,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 1.5,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.1),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(height: 1.35),
      ),
      dividerTheme: const DividerThemeData(space: 28, thickness: 0.7),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkPrimary,
        primary: AppColors.darkPrimary,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkCard,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.darkPrimary, width: 1.4),
          foregroundColor: AppColors.darkPrimary,
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF313A4D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF313A4D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkPrimary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.1, color: Colors.white),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        bodyMedium: TextStyle(height: 1.35, color: Colors.white70),
      ),
      dividerTheme: const DividerThemeData(space: 28, thickness: 0.7),
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
