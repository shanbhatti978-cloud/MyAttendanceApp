import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/constants.dart';
import '../utils/page_transitions.dart';
import '../utils/session.dart';
import '../screens/dashboard_screen.dart';
import '../screens/employee_list_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/leave_entry_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/backup_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/security_settings_screen.dart';
import '../screens/login_screen.dart';

/// Shared side-drawer navigation so every screen has quick access to
/// the rest of the app without retyping this menu each time.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _go(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.pushReplacement(context, fadeSlideRoute(screen));
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, fadeSlideRoute(screen));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.factory, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 10),
                const Text(AppConstants.appShortName,
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('${session.username ?? ''} (${session.role ?? ''})',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: AppColors.primary),
            title: const Text('Dashboard'),
            onTap: () => _go(context, const DashboardScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.people, color: AppColors.primary),
            title: const Text('Employee Master'),
            onTap: () => _go(context, const EmployeeListScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.checklist, color: AppColors.primary),
            title: const Text('Daily Attendance'),
            onTap: () => _go(context, const AttendanceScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.event_busy, color: AppColors.primary),
            title: const Text('Advance Leave Entry'),
            onTap: () => _push(context, const LeaveEntryScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart, color: AppColors.primary),
            title: const Text('Reports'),
            onTap: () => _go(context, const ReportsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.backup, color: AppColors.primary),
            title: const Text('Backup / Restore'),
            onTap: () => _go(context, const BackupScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: AppColors.primary),
            title: const Text('Settings'),
            onTap: () => _go(context, const SettingsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint, color: AppColors.primary),
            title: const Text('Security Settings'),
            onTap: () => _push(context, const SecuritySettingsScreen()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Logout', style: TextStyle(color: AppColors.danger)),
            onTap: () {
              session.logout();
              Navigator.pushAndRemoveUntil(
                context,
                fadeSlideRoute(const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
